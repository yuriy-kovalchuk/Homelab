# strata-cuda: Strata's engine on the GTX 1070 (yojimbo)

[UnbiasedStrata](https://github.com/robertkarl/UnbiasedStrata)'s `strata-poly` engine
behind its `unbiased-strata` front end (llama.cpp's server code, OpenAI API on :8080),
serving Qwen3.6-35B-A3B on yojimbo's GTX 1070 (Pascal, 8 GB) with 16 GB of RAM.

Why not upstream Strata (`../strata`): its Qwen3.6 engine keeps a pinned copy of every
expert that is not in VRAM, ~19 GiB even for the smallest size. `strata-poly` reads the
experts from an mmap of the GGUF, so the page cache holds the hot ones and the cold ones
stay on disk.

- **Image:** `harbor.yuriykovalchuk.dev/homelab/unbiased-strata`, built from the Strata
  repo's `Dockerfile.unbiased-cuda12` (CUDA 12.9, sm_61, AVX2 CPU code for the
  i7-7700K) with `unbiased-q2_0-mmq.patch`, which lets prompt batches run `Q2_0`
  experts on the card, and `llama-q2_0-avx2.patch`, llama.cpp b12110's AVX2 `Q2_0`
  kernel for the experts on the CPU.
- **Model:** llama-cpp-cuda's `Qwen3.6-35B-A3B-GSQ-hybrid.gguf` (12.2 GB, `Q2_0`
  experts), mounted read-only from the `llama-cpp-cuda-models` volume. Nothing to
  download; this is why the component lives in `llm` and not its own namespace.
- **MTP draft block:** the GSQ file has none, so `base/draft-block/` (Job
  `strata-cuda-draft-cut`) cuts the ~308 MiB block out of Unsloth's UD-Q2_K_XL with
  range requests, checks its SHA-256 and writes `Qwen3.6-35B-A3B-MTP-draft.gguf` onto
  the same volume; the engine takes it with `--draft-model`. An init container waits
  for the file. To run without it, replace the two `--draft-model` args with
  `--no-draft`. The log's `drafts=a/b` per request is guesses accepted / made.
- **Pascal:** strata-poly had not run on a real sm_61 card before this; it loads and
  answers. Compare against llama-cpp-cuda (32 tok/s decode, ~620 tok/s prompt at
  131k on the same file) before switching anything over.

## Measured

2026-11-06, image built with the MMQ patch only (before the AVX2 `Q2_0` backport),
`--threads` default (7), 13Gi limit, no thinking, medians not taken (one run each):

| | prompt | decode |
|---|---:|---:|
| 28-31 token prompt, 512 generated | — | 21.2-22.1 tok/s |
| 13,403 token prompt, 400 generated | 619 tok/s | 18.9 tok/s |
| llama-cpp-cuda, same file (earlier, 4.7k prompt) | ~624 tok/s | 32.1 tok/s |

5,235 of 10,240 experts (4.3 GiB) in VRAM; the whole file stayed in the page cache
(peak 11.6 GiB of 13), so disk was not the limit. The CPU half of the experts was: the
fork's pinned llama.cpp had only the scalar `Q2_0` dot product, which
`llama-q2_0-avx2.patch` in the Strata repo replaces with b12110's AVX2 kernel.

## Switch the GTX 1070 over

The claim is exclusive, so only one of the two runs:

```sh
kubectl -n llm scale deploy/llama-cpp-cuda --replicas=0
kubectl -n llm scale deploy/strata-cuda --replicas=1
kubectl -n llm logs -f deploy/strata-cuda -c strata
curl -s https://strata-cuda.yuriykovalchuk.dev/v1/models
```

Back:

```sh
kubectl -n llm scale deploy/strata-cuda --replicas=0
kubectl -n llm scale deploy/llama-cpp-cuda --replicas=1
```

Flux ignores `/spec/replicas` in `llm`, so the scale sticks.

## What to watch in the log

- `the model's files are … GiB and the container has … GiB`: expected at a 13Gi limit.
  The hot experts still fit; misses are read from the SATA SSD.
- The `prompt … tok/s, generated … tok/s; experts from VRAM …%` line after each answer:
  the share of experts served from the card's cache.
- A crash at the first prompt batch points at the `Q2_0` MMQ path (the patch); a
  crash at load or at the first token points at sm_61 itself.

## Settings

Engine flags are after `--` in `base/deployment.yaml` (`--max-context 131072`, `--kv
q8_0`, `--tail-skip 0`). The expert profile lives in an emptyDir and starts again with
each pod.
