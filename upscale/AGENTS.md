# AGENTS.md - SCC Image Upscale Service

## Overview

Local microservice for intelligent image upscaling with Real-ESRGAN and Lanczos fallback. In the current Rails flow, it prepares car photos for final storage when AI upscaling is enabled and configured. Autodetection analysis itself must continue to use the original uploaded image.

## Technology Stack

- **CPU**: `python:3.11-slim` in `Dockerfile.cpu`
- **NVIDIA/CUDA**: `pytorch/pytorch:*-cuda*-runtime` in `Dockerfile.nvidia`
- **AMD/ROCm**: `rocm/pytorch:latest` in `Dockerfile.amd`
- **Experimental Vulkan/ncnn**: `python:3.11-slim` in `Dockerfile.vulkan`
- **API**: FastAPI + Uvicorn
- **Inference**: Real-ESRGAN through PyTorch/torchvision or ncnn for Vulkan
- **Fallbacks**: `cv2.INTER_LANCZOS4`
- **Models by image**:
  - CPU downloads `realesr-general-x4v3.pth`
  - NVIDIA downloads only `4x_NMKD-Siax_200k.pth`
  - AMD downloads only `4x_NMKD-Siax_200k.pth`
  - Vulkan downloads the official `realesrgan-ncnn-vulkan-20220424-ubuntu.zip` package, including the binary and ncnn models

## HTTP Contract

- `GET /health`: returns status, active runtime, active model, and tier/denoise parameters.
- `POST /upscale?minimum_side=<px>`: receives multipart `file` and returns `image/jpeg`.
- `minimum_side` must be positive. Empty or invalid files return `422`.
- Output preserves aspect ratio; do not force square output.

## Rules And Behavior

### Runtime

The runtime is selected by the Docker image.

| Dockerfile | Internal runtime | Downloaded model |
| --- | --- | --- |
| `Dockerfile.cpu` | `cpu` | `realesr-general-x4v3.pth` |
| `Dockerfile.nvidia` | `nvidia` | `4x_NMKD-Siax_200k.pth` |
| `Dockerfile.amd` | `amd` | `4x_NMKD-Siax_200k.pth` |
| `Dockerfile.vulkan` | `vulkan` | `realesrgan-x4plus` |

Do not reintroduce old models or download weights that do not belong to the selected Dockerfile.
Do not split `Dockerfile.amd` between Windows and Linux without a proven lighter ROCm alternative; the validated path remains the ROCm/PyTorch image. For AMD, prefer native Linux with ROCm when possible or `Dockerfile.cpu` when size/compatibility matter more.
The Vulkan runtime is experimental, opt-in, and must keep Lanczos fallback for any ncnn binary failure.

### Custom Models

GPU runtimes use `RRDBNet(num_feat=64, num_block=23, num_grow_ch=32, scale=4)`.
Any custom model supplied through `REAL_ESRGAN_MODEL_PATH` must be an ESRGAN/RRDB 4x weight compatible with that architecture.
SRVGG, compact, 2x/8x, or other topology models require explicit code changes and tests.

RRDB 4x models already tested on the AMD backend and compatible:

- `4x-UltraSharp.pth`
- `RealESRGAN_x4plus.pth`
- `4x_foolhardy_Remacri.pth`
- `4x_NMKD-Siax_200k.pth`
- `4xNomos8kSC.pth`

The current CPU runtime uses `SRVGGNetCompact(num_feat=64, num_conv=32, upscale=4, act_type=prelu)`.
The CPU-compatible model for the current path is `realesr-general-x4v3.pth`.
The RRDB models above do not run on the current CPU path without changing the code to instantiate `RRDBNet` on CPU.
`realesr-general-x4v3.pth` also does not run on the current GPU/RRDB path without changing the code to use `SRVGGNetCompact` on GPU.

### Three-Tier System

The decision engine uses the ratio between the current shortest side and the requested `minimum_side`:

```text
ratio = current_min_side / minimum_side
```

| Tier | Condition | Action |
| --- | --- | --- |
| Tier 1 - 4x AI | `ratio < TIER_4X_THRESHOLD` (default `0.50`) | Real-ESRGAN 4x |
| Tier 2 - 2x AI | `TIER_4X_THRESHOLD <= ratio < TIER_2X_THRESHOLD` (default `0.75`) | Real-ESRGAN 2x |
| Tier 3 - Lanczos | `ratio >= TIER_2X_THRESHOLD` | Lanczos4 |

- After Tiers 1 and 2, always apply `downscale_to_target()`.
- Any Real-ESRGAN failure must fall back to Lanczos4, keeping the endpoint functional.
- Do not fall back between CPU/GPU models inside a runtime; if the GPU path fails, use Lanczos.

### Authentication

When `IMAGE_UPSCALE_API_KEY` is configured, calls require the `X-API-Key` header.

## Tests And Quality

- Tests live in `upscale/test_main.py` and use `unittest` + `fastapi.testclient`.
- Before completing changes in this service, run `python -m unittest upscale/test_main.py` from the repository root or the equivalent container command.
- Tests must mock heavy upscalers; do not download models or depend on GPU in unit tests.

## Environment Variables

| Variable | Default | Description |
| --- | --- | --- |
| `IMAGE_UPSCALE_API_KEY` | empty | Key for the `X-API-Key` header. Without it, any call is accepted. |
| `IMAGE_UPSCALE_DEFAULT_MINIMUM_SIDE` | `360` | Minimum side used when `/upscale` receives no explicit `minimum_side`. |
| `REAL_ESRGAN_MODEL_PATH` | runtime-specific | Optional custom weight path inside the container. |
| `VULKAN_BINARY_PATH` | `/app/bin/realesrgan-ncnn-vulkan` | ncnn binary path in the Vulkan runtime. |
| `VULKAN_MODEL_DIR` | `/app/models/realesrgan-ncnn-vulkan` | ncnn model directory in the Vulkan runtime. |
| `VULKAN_MODEL_NAME` | `realesrgan-x4plus` | ncnn model used by the Vulkan runtime. |
| `TIER_4X_THRESHOLD` | `0.50` | Ratio below which Real-ESRGAN 4x is triggered. |
| `TIER_2X_THRESHOLD` | `0.75` | Ratio below which Real-ESRGAN 2x is triggered. Above it, use Lanczos. |

## Gotchas

- Keep the `torch.load(weights_only=False)` monkeypatch before importing Real-ESRGAN.
- Keep the `torchvision.transforms.functional_tensor` shim for `basicsr` compatibility.
- AMD/ROCm on Windows Docker Desktop has no simple `/dev/kfd` passthrough; prefer native Linux or supported ROCm on WSL2.
- If weights or GPU are missing, startup should log the error and the endpoint should continue with Lanczos fallback.
