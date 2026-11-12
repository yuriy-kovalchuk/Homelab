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
  the same volume. llama-cpp-cuda's `mtp-merge` Job appends it to the GSQ file as
  `Qwen3.6-35B-A3B-GSQ-hybrid-MTP.gguf`, which both engines serve; strata-poly finds
  the block in the file by itself (`--window 4`). An init container waits for the
  file. `--no-draft` turns drafting off. The log's `drafts=a/b` per request is
  guesses accepted / made.
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

Same tests 2026-11-06 with image `70781ea` (AVX2 `Q2_0`) and the MTP draft block
(default window 8), 5,104 of 10,496 experts in VRAM:

| | prompt | decode | guesses accepted |
|---|---:|---:|---:|
| short prompts, 512 generated (3 runs, first one cold) | — | 17.4 / 22.5 / 25.4 tok/s | 87-95% |
| code prompt, 512 generated | — | 26.1 tok/s | 93% |
| 13,403 token prompt, 359 generated | 606 tok/s | 16.1 tok/s | 86% |

During decode the GTX 1070 runs at 97-99% SM use with ~25% memory bandwidth: the
card's compute is the limit, not the CPU or the disk. strata-poly's kernels target
Turing and newer; on Pascal they are compute-bound, and a verify window multiplies
that work, which takes back most of what the accepted guesses save.

Side by side, 2026-11-06, same prompts, same GSQ weights, decode tok/s (short prose x2 /
code / after a 13k prompt) and 13k prompt reading:

| | decode | 13k prompt |
|---|---|---:|
| llama.cpp, no MTP (`Qwen3.6-35B-A3B-GSQ-hybrid`) | 36.7 / 35.1 / 27.4 | 561 tok/s |
| **llama.cpp + MTP** (`Qwen3.6-35B-A3B-GSQ-hybrid-MTP`, ubatch 1024) | **39.3-46.5 / 48.1 / 37.2** | 363 tok/s |
| strata-cuda, merged file, window 4 | 24.9-25.2 / 27.1 / 20.6 | 556 tok/s |

Where strata-poly loses (2026-11-06, decode tok/s short / after 13k prompt, CPU cores used,
GPU "utilization"):

| | decode | CPU | GPU |
|---|---|---:|---:|
| window 1 (no guesses), default expert cache (5,470 in VRAM) | 22.4-23.2 / 19.8 | 2.3 | 97% |
| same, `--no-graphs` | 22.6-23.0 / 20.2 | 2.2 | 97% |
| same, `STRATA_Q2_WARP=1` | 22.6-23.1 / 20.1 | 2.2 | 95% |
| window 1, `--vram-reserve-mib 2600` (2,996 in VRAM) | 24.6-26.1 / 22.0 | 3.6 | 90% |
| window 1, `--no-gpu-experts` (prompts read at 50 tok/s) | 30.6-31.5 / 27.9 | 5.6 | 26% |

Fewer experts on the card is faster, so the GPU side of the hybrid expert path is the
cost, not the CPU (never throttled), launch overhead (graphs change nothing) or the
`Q2_0` matvec kernel (`STRATA_Q2_WARP` changes nothing). In hybrid mode strata-poly
routes each of the 40 layers through the host and launches the cached experts one by
one; its batched path (`moe_card`, one launch per layer) runs only when every expert
fits in VRAM. llama.cpp keeps the hybrid MoE in one fused launch per layer. An Nsight
Systems trace would show which part of that path dominates.

llama.cpp's kernels plus the same MTP block beat strata-poly on this card, so
llama-cpp-cuda's MTP preset is the one to use; strata-cuda stays parked for
comparison. The merged file is written by `../llama-cpp-cuda/base/mtp-merge`.

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
