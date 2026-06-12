# SCC Image Upscale Service

[Leia em portugues](README.pt-BR.md)

FastAPI microservice used by Rails to prepare photos before final storage and before autodetection. The main endpoint receives an image and returns a JPEG with preserved aspect ratio and a guaranteed minimum side.

## HTTP Endpoints

- `GET /health`: returns service status, active runtime, model path, and tier parameters.
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

## Current Recommendation

For local development on Windows/Docker Desktop, use `Dockerfile.cpu`. The Vulkan runtime starts in that environment, but it does not receive a real GPU inside the container; it sees `llvmpipe`, which is CPU-backed Vulkan.

Observed container diagnosis:

```text
deviceType = PHYSICAL_DEVICE_TYPE_CPU
deviceName = llvmpipe (LLVM 19.1.7, 256 bits)
driverName = llvmpipe
```

The container also does not receive `/dev/dri` or `/dev/dxg`. The WSL host has `/dev/dxg`, but it does not reach the Docker Desktop container in this setup. Because of that, Vulkan inside Docker Desktop/Windows must not be treated as GPU acceleration for this project.

Recommended options:

- **CPU**: best local default when compatibility and predictability matter.
- **AMD/ROCm on validated WSL2**: best AMD GPU option in this environment, despite the large image.
- **Vulkan on native Linux**: experimental candidate when the container receives `/dev/dri` and `vulkaninfo` lists a physical GPU.

`Dockerfile.amd` is pinned to `rocm/pytorch:rocm6.4.2_ubuntu24.04_py3.12_pytorch_release_2.6.0`, the combination validated on WSL2 with AMD.

> **Windows/WSL2 size warning:** the AMD/ROCm path uses a very large base image. On Windows with WSL2, the build/pull and intermediate layers can consume close to **90 GB**. Plan disk space before testing that runtime and prefer `Dockerfile.cpu` on machines with limited storage.

There is no split between AMD Dockerfiles for Linux and Windows because both still depend on the validated ROCm/PyTorch image. For AMD, the best alternatives are:

- run on native Linux with ROCm when a compatible AMD GPU and enough disk space are available;
- use `Dockerfile.cpu` when simplicity, smaller size, and compatibility matter more than speed;
- keep Windows/WSL2 only when GPU/ROCm has been validated locally and the storage cost is acceptable.

### Experimental Vulkan Runtime

`Dockerfile.vulkan` provides an experimental alternative based on `Real-ESRGAN-ncnn-vulkan`. It uses `UPSCALE_RUNTIME=vulkan`, calls the ncnn binary through temporary files, and preserves the Lanczos fallback when execution fails.

This path can be a cross-vendor option for AMD, NVIDIA, and Intel on Linux hosts with working Vulkan, but it does not replace the current PyTorch runtimes. The Dockerfile downloads the official `realesrgan-ncnn-vulkan-20220424-ubuntu.zip` package from `xinntao/Real-ESRGAN` release `v0.2.5.0`, which includes the binary and ncnn models.

Output can differ from the `4x_NMKD-Siax_200k.pth` model used by the NVIDIA/AMD runtimes.

On Windows, the upstream native binary can be evaluated outside Docker. Docker GPU/Vulkan on Windows/WSL2 is not a validated path in this project; for real Vulkan GPU in a container, prefer native Linux with `/dev/dri`.

## Compatible Models

GPU runtimes (`Dockerfile.amd` and `Dockerfile.nvidia`) use Real-ESRGAN `RRDBNet` 4x:

```text
num_feat=64, num_block=23, num_grow_ch=32, scale=4
```

To swap the model without code changes, mount or copy a `.pth` weight into the container and set `REAL_ESRGAN_MODEL_PATH` in the local `docker-compose.yml`:

```yaml
upscale-service:
  environment:
    - REAL_ESRGAN_MODEL_PATH=/app/models/custom-model.pth
```

The model must be an ESRGAN/RRDB 4x weight compatible with that architecture. SRVGG, compact, 2x/8x, or other-topology models do not load in this backend without code changes.

RRDB 4x models already tested on the AMD backend and compatible with the current GPU path:

| Model | Note |
| --- | --- |
| `4x-UltraSharp.pth` | Compatible with the same `RRDBNet`. Not compatible with the current CPU path without code changes. |
| `RealESRGAN_x4plus.pth` | Earlier project baseline. Not compatible with the current CPU path without code changes. |
| `4x_foolhardy_Remacri.pth` | Compatible with the same `RRDBNet`. Not compatible with the current CPU path without code changes. |
| `4x_NMKD-Siax_200k.pth` | Current GPU default. Not compatible with the current CPU path without code changes. |
| `4xNomos8kSC.pth` | Compatible with the same `RRDBNet`. Not compatible with the current CPU path without code changes. |

The current CPU runtime uses `SRVGGNetCompact` 4x:

```text
num_feat=64, num_conv=32, upscale=4, act_type=prelu
```

CPU-compatible model:

| Model | Note |
| --- | --- |
| `realesr-general-x4v3.pth` | Current CPU default. Not compatible with the GPU/RRDB path without code changes. |

If a custom weight fails during preload or inference, the service remains online and the request falls back to Lanczos4.

## Upscale Tiers

The service chooses its strategy using:

```text
ratio = current_min_side / minimum_side
```

- `ratio < TIER_4X_THRESHOLD` (`0.50` by default): Real-ESRGAN 4x.
- `TIER_4X_THRESHOLD <= ratio < TIER_2X_THRESHOLD` (`0.75` by default): Real-ESRGAN 2x.
- `ratio >= TIER_2X_THRESHOLD`: Lanczos4 with denoise/sharpen, no AI.

After any AI upscale, the image is reduced so the shortest side matches the requested minimum side exactly.

## Environment Variables

- `IMAGE_UPSCALE_API_KEY`: optional key required by the `X-API-Key` header.
- `IMAGE_UPSCALE_DEFAULT_MINIMUM_SIDE`: minimum side used when `/upscale` receives no explicit `minimum_side`.
- `REAL_ESRGAN_MODEL_PATH`: custom model path inside the selected container.
- `VULKAN_BINARY_PATH`: `realesrgan-ncnn-vulkan` binary path in the Vulkan runtime.
- `VULKAN_MODEL_DIR`: ncnn model directory in the Vulkan runtime.
- `VULKAN_MODEL_NAME`: ncnn model name used by the Vulkan runtime.
- `TIER_4X_THRESHOLD` / `TIER_2X_THRESHOLD`: tier thresholds.
- `DENOISE_H`, `DENOISE_TEMPLATE_WINDOW`, `DENOISE_SEARCH_WINDOW`: Lanczos denoise parameters.
- `LANCZOS_CAS_AMOUNT`: CAS sharpen intensity in the Lanczos fallback.

## AMD/ROCm On WSL2

On WSL2 with AMD, Docker must be executed from Linux/WSL, not from PowerShell, because mounted paths live in the WSL filesystem.

### Check WSL

```sh
ls -l /dev/dxg /usr/lib/wsl/lib/libdxcore.so /opt/rocm/lib/libhsa-runtime64.so.1
cat /opt/rocm/.info/version
docker compose version
```

The validated setup had:

- `/dev/dxg` available;
- `libdxcore.so` at `/usr/lib/wsl/lib/libdxcore.so`;
- `libhsa-runtime64.so.1` at `/opt/rocm/lib/libhsa-runtime64.so.1`;
- ROCm `6.4.2`;
- GPU detected inside the container as `AMD Radeon RX 9070 XT`.

### Configure Local `docker-compose.yml`

The local `docker-compose.yml` is not versioned. For AMD/WSL2, configure `upscale-service` with the AMD Dockerfile and mounts below:

```yaml
upscale-service:
  build:
    context: ./upscale
    dockerfile: Dockerfile.amd
  devices:
    - "/dev/dxg:/dev/dxg"
  volumes:
    - "/usr/lib/wsl/lib/libdxcore.so:/usr/lib/libdxcore.so:ro"
    - "/opt/rocm/lib/libhsa-runtime64.so.1:/opt/rocm/lib/libhsa-runtime64.so.1:ro"
  security_opt:
    - seccomp=unconfined
```

For native Linux AMD, use the standard ROCm devices `/dev/kfd` and `/dev/dri` instead of `/dev/dxg`.

If the goal is avoiding the large ROCm/PyTorch image, use `Dockerfile.cpu`. The experimental Vulkan runtime can be evaluated on Linux with working Vulkan, but should remain opt-in until visual quality and performance are validated with real project photos.

### Start From WSL

```sh
cd /mnt/c/Users/junio/OneDrive/Documentos/git/smart-collection
docker compose up -d --build upscale-service
```

### Validate GPU

```sh
docker compose ps upscale-service
docker compose logs --tail=80 upscale-service
docker compose exec upscale-service python - <<'PY'
import torch
import main
print("model_path", main.model_path_for_runtime("amd"))
print("cuda_available", torch.cuda.is_available())
print("device_count", torch.cuda.device_count())
print("device_name", torch.cuda.get_device_name(0) if torch.cuda.is_available() else "none")
PY
```

Expected result:

- container `healthy`;
- logs with `Target mode: AMD`;
- logs with `AMD upscaler model pre-loaded successfully!`;
- `cuda_available True`.

The warning `Can't initialize amdsmi - Error code: 34` may appear on WSL2; it did not prevent PyTorch from using the GPU in the validated environment.

## Caveats

- Keep the `torch.load(weights_only=False)` monkeypatch before importing Real-ESRGAN.
- Keep the `torchvision.transforms.functional_tensor` shim for `basicsr` compatibility.
- The current GPU model is `4x_NMKD-Siax_200k.pth`; it was selected after local comparison on the AMD backend with real project photos.
- If model preload fails, the service remains online and falls back to Lanczos for requests.
- Rails should call this service only when `IMAGE_UPSCALE_SERVICE_URL` is configured and the user allows AI in the applicable flow.

## Tests

Run the microservice tests from the project root. If local Python does not have the dependencies, use the container:

```sh
docker compose run --rm -v "$PWD/upscale:/app" upscale-service python -m unittest test_main.py
```
