import io
import logging
import os
from functools import lru_cache

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("upscale-service")

import cv2
import numpy as np
from fastapi import Depends, FastAPI, File, Header, HTTPException, UploadFile
from fastapi.responses import Response
from PIL import Image, ImageOps

try:
    import torch
    # Monkeypatch torch.load BEFORE importing realesrgan
    # to handle PyTorch 2.6+ weights_only=True default
    original_load = torch.load
    def patched_load(*args, **kwargs):
        if 'weights_only' not in kwargs:
            kwargs['weights_only'] = False
        return original_load(*args, **kwargs)
    torch.load = patched_load

    # Monkeypatch torchvision functional_tensor for basicsr compatibility in modern torchvision
    import sys
    import types
    import torchvision.transforms.functional as F
    functional_tensor = types.ModuleType("torchvision.transforms.functional_tensor")
    functional_tensor.rgb_to_grayscale = F.rgb_to_grayscale
    sys.modules["torchvision.transforms.functional_tensor"] = functional_tensor

    from realesrgan import RealESRGANer
    from basicsr.archs.rrdbnet_arch import RRDBNet
    from realesrgan.archs.srvgg_arch import SRVGGNetCompact
except ImportError as ie:
    logger.error(f"Failed to import Real-ESRGAN dependencies: {ie}", exc_info=True)
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

# AI Upscale Threshold: if the shortest image side is already >= (target * threshold),
# skip the neural network and use Lanczos4 instead. This avoids the "painted" look
# that neural upscalers introduce on images that already have reasonable detail.
# CPU model (SRVGGNetCompact) distorts more easily → lower threshold.
# GPU model (RRDBNet/x4plus) is higher quality → can afford a higher threshold.
AI_UPSCALE_THRESHOLD_CPU = float(os.getenv("AI_UPSCALE_THRESHOLD_CPU", "0.66"))
AI_UPSCALE_THRESHOLD_GPU = float(os.getenv("AI_UPSCALE_THRESHOLD_GPU", "0.85"))

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


def get_ai_threshold(prefer_gpu: bool) -> float:
    """Return the AI upscale threshold for the active mode.

    Images whose shortest side is already >= (minimum_side * threshold)
    will skip the neural network and be resized with Lanczos4 instead.
    """
    return AI_UPSCALE_THRESHOLD_GPU if prefer_gpu else AI_UPSCALE_THRESHOLD_CPU


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


def upscale_until_min_side(image_bgr, minimum_side):
    current = image_bgr
    passes = 0
    prefer_gpu = should_use_gpu_upscaler()
    current_min_side = min(current.shape[0], current.shape[1])
    threshold = get_ai_threshold(prefer_gpu)
    ai_threshold_px = minimum_side * threshold

    # --- Threshold Guard ---
    # If the image's shortest side is already a significant fraction of the target,
    # the neural upscaler would only introduce artificial textures. Skip straight to Lanczos.
    if current_min_side >= ai_threshold_px:
        mode_label = "GPU" if prefer_gpu else "CPU"
        logger.info(
            f"[Threshold] Image min-side {current_min_side}px >= "
            f"{ai_threshold_px:.0f}px ({threshold:.0%} of target {minimum_side}px, {mode_label} mode). "
            f"Skipping AI upscaler — using Lanczos4 to avoid distortion."
        )
        return upscale_with_lanczos(current, minimum_side)

    logger.info(
        f"[AI Upscale] Image min-side {current_min_side}px < "
        f"{ai_threshold_px:.0f}px threshold. Engaging Real-ESRGAN."
    )

    while min(current.shape[0], current.shape[1]) < minimum_side and passes < MAX_AI_PASSES:
        try:
            current = upscale_with_realesrgan(current, prefer_gpu=prefer_gpu)
            passes += 1
        except Exception as e:
            logger.error(f"Error during Real-ESRGAN upscale (prefer_gpu={prefer_gpu}): {e}", exc_info=True)
            if prefer_gpu:
                try:
                    logger.info("Attempting fallback to CPU Real-ESRGAN...")
                    current = upscale_with_realesrgan(current, prefer_gpu=False)
                    passes += 1
                    prefer_gpu = False
                    continue
                except Exception as cpu_e:
                    logger.error(f"Error during fallback CPU Real-ESRGAN upscale: {cpu_e}", exc_info=True)
                    break
            break

    if min(current.shape[0], current.shape[1]) < minimum_side:
        logger.warning(f"AI Upscale was not sufficient or failed. Falling back to Lanczos resize to {minimum_side}px")
        current = upscale_with_lanczos(current, minimum_side)

    return current


def finalize_output(image_bgr):
    return image_bgr


@app.on_event("startup")
async def startup_event():
    logger.info("Initializing SCC Image Upscale Service...")
    gpu_mode = should_use_gpu_upscaler()
    logger.info(f"Target mode: {'GPU' if gpu_mode else 'CPU'}")
    
    try:
        if gpu_mode:
            logger.info("Pre-loading GPU upscaler model...")
            get_gpu_upscaler()
            logger.info("GPU upscaler model pre-loaded successfully!")
        else:
            logger.info("Pre-loading CPU upscaler model...")
            get_cpu_upscaler()
            logger.info("CPU upscaler model pre-loaded successfully!")
    except Exception as e:
        logger.error(f"Failed to pre-load upscaler model on startup: {e}", exc_info=True)
        logger.warning("Service will start but will fall back to Lanczos resizing for all upscaling requests.")


@app.get("/health")
async def health():
    gpu_mode = should_use_gpu_upscaler()
    return {
        "status": "ok",
        "mode": "gpu" if gpu_mode else "cpu",
        "target_min_side": TARGET_MIN_SIDE,
        "scale": REAL_ESRGAN_SCALE,
        "ai_threshold": get_ai_threshold(gpu_mode),
        "ai_threshold_px": int(TARGET_MIN_SIDE * get_ai_threshold(gpu_mode)),
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
