import io
import os
from functools import lru_cache

import cv2
import numpy as np
from fastapi import Depends, FastAPI, File, Header, HTTPException, UploadFile
from fastapi.responses import Response
from PIL import Image, ImageOps

try:
    import torch
    from realesrgan import RealESRGANer
    from realesrgan.archs.rrdbnet_arch import RRDBNet
    from realesrgan.archs.srvgg_arch import SRVGGNetCompact
except ImportError:  # pragma: no cover - handled in runtime fallback paths
    torch = None
    RealESRGANer = None
    RRDBNet = None
    SRVGGNetCompact = None

TARGET_MIN_SIDE = 512
MAX_AI_PASSES = 5
REAL_ESRGAN_SCALE = 4

GPU_MODEL_PATH = os.getenv(
    "REAL_ESRGAN_GPU_MODEL_PATH",
    "/app/models/RealESRGAN_x4plus.pth"
)
CPU_MODEL_PATH = os.getenv(
    "REAL_ESRGAN_CPU_MODEL_PATH",
    "/app/models/realesr-general-x4v3.pth"
)

app = FastAPI(title="SCC Image Upscale Service")


def env_flag(name, default="false"):
    value = os.getenv(name, default)
    return str(value).strip().lower() in {"1", "true", "yes", "on"}


def env_int(name, default):
    value = os.getenv(name, str(default))
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def should_use_gpu_upscaler():
    return env_flag("USE_GPU_UPSCALER", "true")


async def verify_api_key(x_api_key: str = Header(None)):
    api_key = os.getenv("IMAGE_UPSCALE_API_KEY")
    if api_key and x_api_key != api_key:
        raise HTTPException(status_code=403, detail="Invalid API Key")
    return x_api_key


def _require_model(path):
    if not os.path.exists(path):
        raise RuntimeError(f"Super-resolution model not found: {path}")
    return path


@lru_cache(maxsize=1)
def get_gpu_upscaler():
    if RealESRGANer is None or RRDBNet is None or torch is None:
        raise RuntimeError("Real-ESRGAN GPU stack is not installed")
    if not torch.cuda.is_available():
        raise RuntimeError("CUDA is not available")

    model = RRDBNet(num_in_ch=3, num_out_ch=3, scale=REAL_ESRGAN_SCALE, num_feat=64, num_block=23, num_grow_ch=32)
    return RealESRGANer(
        scale=REAL_ESRGAN_SCALE,
        model_path=_require_model(GPU_MODEL_PATH),
        model=model,
        tile=0,
        tile_pad=10,
        pre_pad=0,
        half=True,
        device="cuda"
    )


@lru_cache(maxsize=1)
def get_cpu_upscaler():
    if RealESRGANer is None or SRVGGNetCompact is None:
        raise RuntimeError("Real-ESRGAN CPU stack is not installed")

    model = SRVGGNetCompact(
        num_in_ch=3,
        num_out_ch=3,
        num_feat=64,
        num_conv=32,
        upscale=REAL_ESRGAN_SCALE,
        act_type="prelu"
    )
    return RealESRGANer(
        scale=REAL_ESRGAN_SCALE,
        model_path=_require_model(CPU_MODEL_PATH),
        model=model,
        tile=0,
        tile_pad=10,
        pre_pad=0,
        half=False,
        device="cpu"
    )


def upscale_with_realesrgan(image_bgr, prefer_gpu=True):
    if prefer_gpu:
        upscaler = get_gpu_upscaler()
    else:
        upscaler = get_cpu_upscaler()

    output_bgr, _ = upscaler.enhance(image_bgr, outscale=REAL_ESRGAN_SCALE)
    return output_bgr


def upscale_with_lanczos(image_bgr, minimum_side):
    height, width = image_bgr.shape[:2]
    scale = minimum_side / float(min(height, width))
    new_width = max(int(round(width * scale)), minimum_side)
    new_height = max(int(round(height * scale)), minimum_side)
    return cv2.resize(image_bgr, (new_width, new_height), interpolation=cv2.INTER_LANCZOS4)


def fit_to_square(image_bgr, square_side):
    if square_side <= 0:
        return image_bgr

    image_rgb = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
    pil_image = Image.fromarray(image_rgb)
    fitted = ImageOps.fit(
        pil_image,
        (square_side, square_side),
        method=Image.Resampling.LANCZOS,
        centering=(0.5, 0.5)
    )
    return cv2.cvtColor(np.array(fitted), cv2.COLOR_RGB2BGR)


def upscale_until_min_side(image_bgr, minimum_side):
    current = image_bgr
    passes = 0
    prefer_gpu = should_use_gpu_upscaler()

    while min(current.shape[0], current.shape[1]) < minimum_side and passes < MAX_AI_PASSES:
        try:
            current = upscale_with_realesrgan(current, prefer_gpu=prefer_gpu)
            passes += 1
        except Exception:
            if prefer_gpu:
                try:
                    current = upscale_with_realesrgan(current, prefer_gpu=False)
                    passes += 1
                    prefer_gpu = False
                    continue
                except Exception:
                    break
            break

    if min(current.shape[0], current.shape[1]) < minimum_side:
        current = upscale_with_lanczos(current, minimum_side)

    return current


def finalize_output(image_bgr):
    target_output_side = env_int("UPSCALE_OUTPUT_SIDE", 1080)
    return fit_to_square(image_bgr, target_output_side)


@app.get("/health")
async def health():
    return {
        "status": "ok",
        "mode": "gpu" if should_use_gpu_upscaler() else "cpu",
        "target_output_side": env_int("UPSCALE_OUTPUT_SIDE", 1080),
        "scale": REAL_ESRGAN_SCALE
    }


@app.post("/upscale", dependencies=[Depends(verify_api_key)])
async def upscale(file: UploadFile = File(...), minimum_side: int = TARGET_MIN_SIDE):
    if minimum_side < 1:
        raise HTTPException(status_code=422, detail="minimum_side must be positive")

    contents = await file.read()
    if not contents:
        raise HTTPException(status_code=422, detail="Empty file")

    try:
        image = Image.open(io.BytesIO(contents))
        image = ImageOps.exif_transpose(image).convert("RGB")
    except Exception as exc:
        raise HTTPException(status_code=422, detail=f"Invalid image: {exc}") from exc

    image_bgr = cv2.cvtColor(np.array(image), cv2.COLOR_RGB2BGR)
    upscaled_bgr = upscale_until_min_side(image_bgr, minimum_side)
    output_bgr = finalize_output(upscaled_bgr)
    output_rgb = cv2.cvtColor(output_bgr, cv2.COLOR_BGR2RGB)
    output_image = Image.fromarray(output_rgb)

    buffer = io.BytesIO()
    output_image.save(buffer, format="JPEG", quality=95, optimize=True)
    return Response(content=buffer.getvalue(), media_type="image/jpeg")
