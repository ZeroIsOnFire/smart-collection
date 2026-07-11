# SCC Image Upscale Service

[Leia em português](README.pt-BR.md)

FastAPI microservice used by Rails to prepare car photos before final storage when AI upscaling is enabled and `IMAGE_UPSCALE_SERVICE_URL` is configured. The endpoint receives an image and returns a JPEG with preserved aspect ratio and a guaranteed minimum side.

Autodetection analysis must continue to use the original uploaded image. The upscaler applies only to the car photo save flow.

## Endpoint

- `GET /health`: returns service status, runtime, model, and processing parameters.
- `POST /upscale?minimum_side=<px>`: receives multipart `file`; returns `image/jpeg`.

When `IMAGE_UPSCALE_API_KEY` is configured, send the `X-API-Key` header.

## Runtimes

The runtime is selected by the Dockerfile used by `upscale-service`.

| Dockerfile | Runtime | Model |
| --- | --- | --- |
| `Dockerfile.cpu` | CPU | `realesr-general-x4v3.pth` |
| `Dockerfile.nvidia` | NVIDIA/CUDA | `4x_NMKD-Siax_200k.pth` |
| `Dockerfile.amd` | AMD/ROCm | `4x_NMKD-Siax_200k.pth` |
| `Dockerfile.vulkan` | Experimental Vulkan/ncnn | `realesrgan-x4plus` |

For local development on Windows/Docker Desktop, use `Dockerfile.cpu`. The Vulkan runtime may start there, but it usually sees CPU-backed `llvmpipe` rather than a real GPU. Docker GPU/Vulkan on Windows/WSL2 is not a validated path for this project.

For AMD, prefer native Linux with ROCm when possible. `Dockerfile.amd` is pinned to the validated ROCm/PyTorch path and can consume close to **90 GB** on Windows/WSL2 because of the base image and layers. Use CPU when size and compatibility matter more than speed.

## Docker Compose

Default CPU setup:

```yaml
upscale-service:
  build:
    context: ./upscale
    dockerfile: Dockerfile.cpu
  env_file:
    - .env
  environment:
    - IMAGE_UPSCALE_API_KEY=${IMAGE_UPSCALE_API_KEY:-}
    - REAL_ESRGAN_MODEL_PATH=${REAL_ESRGAN_MODEL_PATH:-}
    - TIER_4X_THRESHOLD=${TIER_4X_THRESHOLD:-0.50}
    - TIER_2X_THRESHOLD=${TIER_2X_THRESHOLD:-0.75}
  restart: unless-stopped
```

Start or rebuild only the service:

```bash
docker compose up -d --build upscale-service
```

Check status:

```bash
docker compose ps upscale-service
docker compose logs --tail=80 upscale-service
```

Rails and Sidekiq should call:

```text
http://upscale-service:8000
```

## Processing Rules

The service uses the ratio between the current shortest side and the requested `minimum_side`:

```text
ratio = current_min_side / minimum_side
```

| Tier | Condition | Action |
| --- | --- | --- |
| Tier 1 - 4x AI | `ratio < TIER_4X_THRESHOLD` (default `0.50`) | Real-ESRGAN 4x |
| Tier 2 - 2x AI | `TIER_4X_THRESHOLD <= ratio < TIER_2X_THRESHOLD` (default `0.75`) | Real-ESRGAN 2x |
| Tier 3 - Lanczos | `ratio >= TIER_2X_THRESHOLD` | Lanczos4 |

After any AI upscale, the image is reduced so the shortest side matches the requested minimum side exactly. If Real-ESRGAN fails, the endpoint falls back to Lanczos4 and remains functional.

## Models

GPU runtimes use `RRDBNet(num_feat=64, num_block=23, num_grow_ch=32, scale=4)`. Compatible RRDB 4x models already tested on the AMD backend include:

- `4x-UltraSharp.pth`
- `RealESRGAN_x4plus.pth`
- `4x_foolhardy_Remacri.pth`
- `4x_NMKD-Siax_200k.pth`
- `4xNomos8kSC.pth`

The CPU runtime uses `SRVGGNetCompact(num_feat=64, num_conv=32, upscale=4, act_type=prelu)` with `realesr-general-x4v3.pth`. Do not mix RRDB GPU models into the CPU path or the CPU SRVGG model into the GPU/RRDB path without code changes and tests.

## Environment Variables

- `IMAGE_UPSCALE_API_KEY`: optional key required by the `X-API-Key` header.
- `IMAGE_UPSCALE_DEFAULT_MINIMUM_SIDE`: minimum side used when Rails or the endpoint provides no explicit value; default `360`.
- `REAL_ESRGAN_MODEL_PATH`: optional custom model path inside the container.
- `VULKAN_BINARY_PATH`: ncnn binary path for the Vulkan runtime.
- `VULKAN_MODEL_DIR`: ncnn model directory for the Vulkan runtime.
- `VULKAN_MODEL_NAME`: ncnn model name for the Vulkan runtime.
- `TIER_4X_THRESHOLD`: ratio below which Real-ESRGAN 4x is used; default `0.50`.
- `TIER_2X_THRESHOLD`: ratio below which Real-ESRGAN 2x is used; default `0.75`.
- `DENOISE_H`, `DENOISE_TEMPLATE_WINDOW`, `DENOISE_SEARCH_WINDOW`, `LANCZOS_CAS_AMOUNT`: fallback enhancement parameters.

## Development Notes

- Keep the `torch.load(weights_only=False)` monkeypatch before importing Real-ESRGAN.
- Keep the `torchvision.transforms.functional_tensor` shim for `basicsr` compatibility.
- Do not download models or require GPU access in unit tests.
- Do not add Python dependencies without explicit approval.
- If weights or GPU are missing, startup should log the error and the endpoint should continue with Lanczos fallback.

## Tests

Run the unit tests from the repository root:

```bash
python -m unittest upscale/test_main.py
```

Or inside Docker Compose:

```bash
docker compose run --rm -v "$PWD/upscale:/app" upscale-service python -m unittest test_main.py
```
