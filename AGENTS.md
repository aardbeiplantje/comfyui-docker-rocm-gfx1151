# AGENTS.md — ComfyUI ROCm Docker Deployment

## What is this repo?

A Docker-based deployment of [ComfyUI](https://github.com/comfyanonymous/ComfyUI) targeting **AMD ROCm GPUs** (gfx1151 / RDNA3). No tests, no CI — everything revolves around building and running one Docker image.

## Build & run commands

| Goal | Command |
|------|---------|
| Build local image | `docker buildx bake -f docker-bake.hcl local` |
| Push release image | `env="release" docker buildx bake -f docker-bake.hcl release` |
| Run single-shot container | `./run.sh` or `./run.sh comfyui` |
| Deploy (build + compose up) | `./deploy.sh` |

`deploy.sh` requires env vars: `APP_DOMAIN`, `IPV6_SUBNET`, `IPV6_GATEWAY`. It calls `docker buildx bake ... local` then `docker compose up -d`.

## Image architecture (Dockerfile)

Two stages:
1. **pytorch-rocm-7.13-gfx1151-base** (alias `base`) — Debian base with PyTorch ROCm, JAX, triton, flash_attn, Vulkan tools. Entry point is `bash`.
2. **comfyui-runtime** — Installs ComfyUI + all Python deps from pip, clones ComfyUI repo to `/ComfyUI`, symlinks to `$HDIR/ComfyUI` (`/$LOGNAME/ComfyUI`). Sets entrypoint to `/comfyui.sh`.

The local build target (`_local`) stops at the `comfyui-runtime` stage. The release target builds at a generic `runtime` stage name but inherits `_common` which has no explicit target (would use final stage).

## Key environment variables

Required for runtime:
- `HF_TOKEN` — HuggingFace token (download gated models via comfy-cli)
- `LOGNAME` — user name inside container (default `comfyui`, UID/GID 1000)

Important defaults in `comfyui.sh`:
- `HSA_OVERRIDE_GFX_VERSION=11.5.1` — GPU architecture override
- GPU memory tuning vars: `GGML_*` and `HSA_*` envs (see `comfyui.sh:15-17`)
- Python cache path: `$TMPDIR/comfyui-pycache-$LOGNAME/`
- ROCm libs from `/opt/rocm/lib`

## Paths & volumes (docker-compose)

| Mount point | Host variable | Default on host | Purpose |
|---|---|---|---|
| `/hf` | `HF_HOME` | `hf-$LOGNAME` | HuggingFace cache |
| `/comfyui-data` | `MODELS_DIR` | `comfyui-data-$LOGNAME` | Models, LORAs, checkpoints |
| `/comfyui/workspace` | `WORKSPACE` | `comfyui-workspace-$LOGNAME` | User workspace (input/output) |
| `/opt/rocm` | `ROCM_PATH` | `/opt/rocm` | ROCm runtime (read-only) |

Custom nodes directory: `/comfyui-data/custom_nodes` (created by comfyui.sh on startup).

Model paths are configured by the baked-in `~/.comfyui.yml` which maps ComfyUI model categories to subdirectories under `/comfyui-data`.

## Docker buildx bake targets

From `docker-bake.hcl`:
- **local** → builds `_local` target tagged as `local/ai/comfyui-gfx1151:latest`, outputs via `type=docker,name=...push=false`
- **release** → builds `containers-${env}` with env=`release`, pushes to `ghcr.io/ai/comfyui-gfx1151:latest`
- Both inherit `_common` with context `.`, dockerfile `Dockerfile`, platform `linux/amd64`, network mode `host`

## Model path config

The file `comfyui.yml` is copied into the image as `$HDIR/.comfyui.yml` and loaded at runtime via `--extra-model-paths-config ~/.comfyui.yml`. This tells ComfyUI where to find checkpoints, LORAs, VAEs, controlnets, etc. — all relative to `/comfyui-data`.

## File layout

```
.
├── Dockerfile          # Multi-stage: base + comfyui-runtime
├── docker-bake.hcl     # docker buildx bake definitions (build orchestration)
├── docker-compose.yml  # Production compose (IPv6-only, seccomp unconfined)
├── comfyui.sh          # Entrypoint: sets env vars, drops to root then execs ComfyUI
├── run.sh              # Quick single-container run (uses --network=host)
├── deploy.sh           # Full deploy: buildx bake local → docker compose up -d
└── comfyui.yml         # Model path config (baked into image as .comfyui.yml)
```

## Gotchas

- **No tests or lint** — this is a deployment-only repo. Verification means building the image and running it.
- **Seccomp is disabled** (`seccomp=unconfined`) in both `run.sh` and `docker-compose.yml` for ROCm compatibility.
- **Read-only filesystem** — writable tmpfs mounts required at `/tmp`, `/var/tmp`, `/comfyui/.config/ComfyUI`, and `/run`.
- **IPv6-only network** by default in compose (bridge with routed gateway). The `dmz-ipv6` network requires valid IPv6 subnet/gateway vars.
- **`--prefer-binary`** pip installs everywhere — no wheel compilation during build. This matters if you're modifying dependencies on non-x86_64 platforms.
