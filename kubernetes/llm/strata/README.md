# Strata: switching models

Strata serves one model at a time. Which one is chosen by two env values on the
Deployment, `FAMILY` and `MODEL`. Flux sets them once and then ignores them
(`clusters/workload-prd/flux-system/llm.yaml`), so they are switched live with
`kubectl`, never in Git.

## Models on the volume

| `FAMILY` | `MODEL` | Model | Files on `strata-data` |
|---|---|---|---|
| `qwen` | `IQ3_S` | Qwen3.8-Flash-Next GSQ-RCO IQ3_S (176B MoE, 256K context) | `models/IQ3_S/`, `packs/iq3_s/`, `mtp/` |
| `qwen36` | `Q8_0` | Qwen3.6-35B-A3B Q8_0 with MTP (35B MoE, 3B active) | `models/qwen36-Q8_0/` |
| `qwen36` | `UD-Q6_K_XL` | Qwen3.6-35B-A3B UD-Q6_K_XL with MTP (every expert in VRAM) | `models/qwen36-UD-Q6_K_XL/` |

Both are listed in `base/model-download/models.txt`; a model must be fully
downloaded (its `strata-model-download` Job `Complete`) before switching to it.

## Switch

```sh
# Qwen3.6-35B-A3B
kubectl -n llm-strata set env deploy/strata FAMILY=qwen36 MODEL=Q8_0

# back to Qwen3.8-Flash-Next
kubectl -n llm-strata set env deploy/strata FAMILY=qwen MODEL=IQ3_S
```

Changing the env restarts the pod (strategy `Recreate`). If Strata is parked:

```sh
kubectl -n llm-strata scale deploy/strata --replicas=1
```

The R9700 is exclusive: scale `llama-cpp` and `llama-cpp-rocm` (namespace `llm`)
to 0 first, or the strata pod stays Pending. sd-server (780M) can't run beside
it either: Strata's 52Gi memory request leaves no room for sd-server's 20Gi.

## Check

```sh
kubectl -n llm-strata get deploy strata \
  -o jsonpath='{range .spec.template.spec.containers[0].env[*]}{.name}={.value}{"\n"}{end}'
kubectl -n llm-strata logs -f deploy/strata
curl -s https://strata.yuriykovalchuk.dev/v1/models
```

The first start of a model runs Strata's setup offline (the pod has no internet):
it checks the files, packs Flash-Next sizes (minutes) and writes
`/data/config/strata-<tag>.json`; later starts reuse that config. Loading then
takes from under a minute (Qwen3.6) to a few minutes (Flash-Next, ~47 GB of
experts into RAM). `/health` answers once the model is loaded.

## Add a model

1. Add its files to `base/model-download/models.txt` at the paths Strata's setup
   expects (see the comments there), with the SHA-256 Strata pins. Pictures need the
   model's `mmproj-*.gguf` as well (Flash-Next's in `models/`, Qwen3.6's in its own
   folder).
2. Push; the `strata-model-download` Job runs again and fetches only new files.
3. When it is `Complete`, switch with `kubectl set env` as above.

Setup only accepts the sizes `setup.py` pins (`--model` choices). Unsloth's
UD-Q8_K_XL of Qwen3.6, for one, is refused: it keeps some layers in BF16, which
Strata 0.2.2's kernels do not run.

## Pictures (vision)

Both encoders are on the volume (`models/mmproj-Qwen3.8-Flash-Next-BF16.gguf` for
Flash-Next, `models/qwen36-Q8_0/mmproj-F16.gguf` for Qwen3.6) and the image carries
both readers (`strata-vision` on the CPU, `strata-vision-hip` on the card) — the image
repo compiles them, because otherwise setup tries to compile them in a pod with no
compiler and no egress.

What turns pictures on is the `"vision"` section of the model's config. For Flash-Next
that means `base/configmap-model-configs.yaml` (its config is seeded, never generated)
and a matching `VISION` in `base/deployment.yaml`, which only matters when setup writes
a config itself. For Qwen3.6, setup wrote the config, so its section is on the volume.

| Reader | A picture | Cost |
|---|---|---|
| `cpu` (ours) | ~3 s at 300 image tokens, 8 threads | nothing off the card, ~1.2-2.2 GB more RSS next to the ~47 GB of experts |
| `gpu` | 0.1-0.5 s, up to 1024 image tokens | ~1.4 GB of the R9700 kept free (the engine gets `--vram-reserve-mib 700`): expert cache smaller, decode a few % slower |

The encoder-on-demand that would have both (`"elastic": true` with `"vram_elastic":
true`) is NVIDIA only: the engine turns `--vram-elastic` off on HIP.

Switching the reader of a model already set up:

- **Flash-Next:** change its `"vision"` block in the ConfigMap (`exe` →
  `strata-vision-hip`, `gpu: true`, `max_tokens: 1024`, drop `threads`) *and* `VISION:
  gpu` in `base/deployment.yaml`, one commit; Flux rolls the pod. `kubectl set env`
  alone is reverted (VISION is not in the ignore rule) and never touches the seeded file.
- **Qwen3.6:** `kubectl -n llm-strata set env deploy/strata VISION=gpu REINSTALL=1`, then
  `REINSTALL-` once it serves (its config is not seeded, so it sticks).

First time, in order: `models.txt` (the download Job fetches the mmproj) → build the
image with the readers → one commit with the new image tag, `VISION` and the config's
`vision` block. Keep `strata` parked until that last commit: a `vision` section whose
`exe` or `mmproj` is missing stops the server at start, there is no fall back to text.
`this server was started without the vision encoder` in the log is the other half: no
`vision` section (or no `--vision` in the args).

## Pitfalls

- **Keep the env order in `base/deployment.yaml`.** The Flux ignore rule points
  at `env[1]` (`MODEL`) and `env[3]` (`FAMILY`). `kubectl set env` edits existing
  names in place, so live and Git stay aligned; reordering the list in Git
  would make Flux ignore the wrong values. `VISION` is last (`env[4]`) and is
  deliberately *not* ignored: its reader belongs in Git, where the config's
  `vision` section is the other half of the change.
- **Other settings (context, KV type) are not switchable this way.** `CONTEXT`
  only matters when setup writes a config; to change it for a model that is
  already set up, set `CONTEXT=<n> REINSTALL=1` with `kubectl set env`, wait for
  the pod to serve, then `kubectl -n llm-strata set env deploy/strata REINSTALL-`.
  The Flash-Next config is seeded from `base/configmap-model-configs.yaml` on
  every start, so change its context there, in Git.
- **If the Deployment is ever recreated,** it starts from the Git defaults
  (Flash-Next IQ3_S); set the env again.
