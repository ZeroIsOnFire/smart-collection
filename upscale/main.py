import io
import logging
import os
import subprocess
import tempfile
from collections import OrderedDict
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

    def normalize_realesrgan_checkpoint(checkpoint):
        if not isinstance(checkpoint, (dict, OrderedDict)):
            return checkpoint
        if "params" in checkpoint:
            return checkpoint
        if "params_ema" in checkpoint:
            checkpoint["params"] = checkpoint["params_ema"]
            return checkpoint

        keys = list(checkpoint.keys())
        if not keys or not all(str(key).startswith("model.") for key in keys):
            return checkpoint

        normalized = OrderedDict()
        for key, value in checkpoint.items():
            normalized_key = key
            if key.startswith("model.1.sub."):
                normalized_key = key.replace("model.1.sub.", "body.", 1)
                normalized_key = normalized_key.replace(".RDB", ".rdb")
                normalized_key = normalized_key.replace(".conv1.0.", ".conv1.")
                normalized_key = normalized_key.replace(".conv2.0.", ".conv2.")
                normalized_key = normalized_key.replace(".conv3.0.", ".conv3.")
                normalized_key = normalized_key.replace(".conv4.0.", ".conv4.")
                normalized_key = normalized_key.replace(".conv5.0.", ".conv5.")
                normalized_key = normalized_key.replace("body.23.", "conv_body.")
            elif key.startswith("model.0."):
                normalized_key = key.replace("model.0.", "conv_first.", 1)
            elif key.startswith("model.3."):
                normalized_key = key.replace("model.3.", "conv_up1.", 1)
            elif key.startswith("model.6."):
                normalized_key = key.replace("model.6.", "conv_up2.", 1)
            elif key.startswith("model.8."):
                normalized_key = key.replace("model.8.", "conv_hr.", 1)
            elif key.startswith("model.10."):
                normalized_key = key.replace("model.10.", "conv_last.", 1)
            normalized[normalized_key] = value
        return {"params": normalized}

    # Monkeypatch torch.load BEFORE importing realesrgan
    # to handle PyTorch 2.6+ weights_only=True default
    original_load = torch.load
    def patched_load(*args, **kwargs):
        if 'weights_only' not in kwargs:
            kwargs['weights_only'] = False
        checkpoint = original_load(*args, **kwargs)
        return normalize_realesrgan_checkpoint(checkpoint)
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

DEFAULT_TARGET_MIN_SIDE = 360
TARGET_MIN_SIDE_ENV = "IMAGE_UPSCALE_DEFAULT_MINIMUM_SIDE"
MAX_AI_PASSES = 5
REAL_ESRGAN_SCALE = 4

CPU_MODEL_PATH = "/app/models/realesr-general-x4v3.pth"
GPU_MODEL_PATH = "/app/models/4x_NMKD-Siax_200k.pth"
VULKAN_BINARY_PATH = "/app/bin/realesrgan-ncnn-vulkan"
VULKAN_MODEL_DIR = "/app/models/realesrgan-ncnn-vulkan"
GPU_RUNTIMES = {"nvidia", "amd"}
RUNTIME_ALIASES = {
    "cpu": "cpu",
    "nvidia": "nvidia",
    "cuda": "nvidia",
    "gpu": "nvidia",
    "amd": "amd",
    "rocm": "amd",
    "vulkan": "vulkan",
    "ncnn": "vulkan",
}

# --- Upscale Tier Thresholds ---
# Ratio = current_min_side / minimum_side (target)
#  < 0.50  → 4x Real-ESRGAN (heavy neural reconstruction)
#  0.50 – 0.7499 → 2x Real-ESRGAN (medium boost)
#  >= 0.75 → Lanczos4 (classical rescale, no AI distortion)
TIER_4X_THRESHOLD = float(os.getenv("TIER_4X_THRESHOLD", "0.50"))   # below this → 4x
TIER_2X_THRESHOLD = float(os.getenv("TIER_2X_THRESHOLD", "0.75"))   # below this → 2x; above → Lanczos

DENOISE_H = int(os.getenv("DENOISE_H", "7"))
DENOISE_TEMPLATE_WINDOW = int(os.getenv("DENOISE_TEMPLATE_WINDOW", "7"))
DENOISE_SEARCH_WINDOW = int(os.getenv("DENOISE_SEARCH_WINDOW", "21"))
LANCZOS_CAS_AMOUNT = float(os.getenv("LANCZOS_CAS_AMOUNT", "0.35"))

app = FastAPI(title="SCC Image Upscale Service")


def upscale_runtime():
    runtime = os.getenv("UPSCALE_RUNTIME", "cpu").strip().lower()
    if runtime not in RUNTIME_ALIASES:
        raise RuntimeError(f"Unknown UPSCALE_RUNTIME: {runtime}")
    return RUNTIME_ALIASES[runtime]


def target_min_side():
    try:
        value = int(os.getenv(TARGET_MIN_SIDE_ENV, "0") or 0)
    except ValueError:
        value = 0

    return value if value > 0 else DEFAULT_TARGET_MIN_SIDE


def gpu_runtime_name(runtime):
    return runtime in GPU_RUNTIMES


def vulkan_runtime_name(runtime):
    return runtime == "vulkan"


def model_path_for_runtime(runtime):
    if vulkan_runtime_name(runtime):
        return os.getenv("REAL_ESRGAN_MODEL_PATH") or os.getenv("VULKAN_MODEL_DIR") or VULKAN_MODEL_DIR
    default_path = GPU_MODEL_PATH if gpu_runtime_name(runtime) else CPU_MODEL_PATH
    return os.getenv("REAL_ESRGAN_MODEL_PATH") or default_path


def vulkan_binary_path():
    return os.getenv("VULKAN_BINARY_PATH") or VULKAN_BINARY_PATH


def vulkan_model_name():
    return os.getenv("VULKAN_MODEL_NAME") or "realesrgan-x4plus"


def cpu_model_config():
    base_model_path = model_path_for_runtime("cpu")
    return base_model_path, None


async def verify_api_key(x_api_key: str = Header(None)):
    api_key = os.getenv("IMAGE_UPSCALE_API_KEY")
    if api_key and x_api_key != api_key:
        raise HTTPException(status_code=403, detail="Invalid API Key")
    return x_api_key


def _require_model(path):
    if not os.path.exists(path):
        raise RuntimeError(f"Super-resolution model not found: {path}")
    return path


def require_model_paths(model_path):
    if isinstance(model_path, list):
        return [_require_model(path) for path in model_path]
    return _require_model(model_path)


@lru_cache(maxsize=4)
def get_upscaler(runtime):
    if runtime == "vulkan":
        return get_vulkan_upscaler()
    if runtime == "cpu":
        return get_cpu_upscaler()
    return get_gpu_upscaler(runtime)


def get_vulkan_upscaler():
    binary_path = vulkan_binary_path()
    model_dir = model_path_for_runtime("vulkan")
    if not os.path.exists(binary_path):
        raise RuntimeError(f"Real-ESRGAN ncnn Vulkan binary not found: {binary_path}")
    if not os.path.isdir(model_dir):
        raise RuntimeError(f"Real-ESRGAN ncnn Vulkan model directory not found: {model_dir}")
    return {"binary_path": binary_path, "model_dir": model_dir, "model_name": vulkan_model_name()}


def get_gpu_upscaler(runtime):
    if RealESRGANer is None or RRDBNet is None or torch is None:
        raise RuntimeError("Real-ESRGAN GPU stack is not installed")
    if not torch.cuda.is_available():
        raise RuntimeError(f"GPU runtime {runtime} is not available")

    model = RRDBNet(num_in_ch=3, num_out_ch=3, scale=REAL_ESRGAN_SCALE, num_feat=64, num_block=23, num_grow_ch=32)
    return RealESRGANer(
        scale=REAL_ESRGAN_SCALE,
        model_path=require_model_paths(model_path_for_runtime(runtime)),
        model=model,
        tile=0,
        tile_pad=10,
        pre_pad=0,
        half=True,
        device="cuda"
    )


def get_cpu_upscaler():
    if RealESRGANer is None or SRVGGNetCompact is None:
        raise RuntimeError("Real-ESRGAN CPU stack is not installed")

    model_path, dni_weight = cpu_model_config()
    model_path = require_model_paths(model_path)

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
        model_path=model_path,
        dni_weight=dni_weight,
        model=model,
        tile=0,
        tile_pad=10,
        pre_pad=0,
        half=False,
        device="cpu"
    )


def upscale_with_realesrgan(image_bgr, outscale=None):
    """Run Real-ESRGAN on the image.

    outscale controls the output scale factor passed to RealESRGANer.enhance().
    Defaults to REAL_ESRGAN_SCALE (4x) when not specified.
    """
    if outscale is None:
        outscale = REAL_ESRGAN_SCALE

    runtime = upscale_runtime()
    if runtime == "vulkan":
        return upscale_with_vulkan(image_bgr, outscale=outscale)

    upscaler = get_upscaler(runtime)
    output_bgr, _ = upscaler.enhance(image_bgr, outscale=outscale)
    return output_bgr


def upscale_with_vulkan(image_bgr, outscale=None):
    if outscale is None:
        outscale = REAL_ESRGAN_SCALE

    config = get_upscaler("vulkan")
    with tempfile.TemporaryDirectory(prefix="scc-vulkan-upscale-") as temp_dir:
        input_path = os.path.join(temp_dir, "input.png")
        output_path = os.path.join(temp_dir, "output.png")
        if not cv2.imwrite(input_path, image_bgr):
            raise RuntimeError("Failed to write temporary Vulkan input image")

        command = [
            config["binary_path"],
            "-i", input_path,
            "-o", output_path,
            "-m", config["model_dir"],
            "-n", config["model_name"],
            "-s", str(int(outscale)),
            "-f", "png",
        ]
        subprocess.run(command, check=True, capture_output=True, text=True)

        output_bgr = cv2.imread(output_path, cv2.IMREAD_COLOR)
        if output_bgr is None:
            raise RuntimeError("Real-ESRGAN ncnn Vulkan did not produce a readable output image")
        return output_bgr


def apply_denoise(image_bgr):
    return cv2.fastNlMeansDenoisingColored(
        image_bgr,
        None,
        h=DENOISE_H,
        hColor=DENOISE_H,
        templateWindowSize=DENOISE_TEMPLATE_WINDOW,
        searchWindowSize=DENOISE_SEARCH_WINDOW,
    )


def apply_cas_sharpen(image_bgr):
    if LANCZOS_CAS_AMOUNT <= 0:
        return image_bgr

    image = image_bgr.astype(np.float32) / 255.0
    padded = cv2.copyMakeBorder(image, 1, 1, 1, 1, cv2.BORDER_REFLECT_101)

    b = padded[:-2, 1:-1]
    d = padded[1:-1, :-2]
    e = padded[1:-1, 1:-1]
    f = padded[1:-1, 2:]
    h = padded[2:, 1:-1]

    local_min = np.minimum.reduce([b, d, e, f, h])
    local_max = np.maximum.reduce([b, d, e, f, h])
    contrast = np.max(local_max - local_min, axis=2, keepdims=True)
    adaptive_amount = LANCZOS_CAS_AMOUNT * np.clip(1.0 - contrast, 0.15, 1.0)

    cross_average = (b + d + f + h) * 0.25
    detail = e - cross_average
    sharpened = e + detail * adaptive_amount
    return np.clip(sharpened * 255.0, 0, 255).astype(np.uint8)


def apply_sharpen(image_bgr):
    return apply_cas_sharpen(image_bgr)


def upscale_with_lanczos(image_bgr, minimum_side):
    new_width, new_height = dimensions_for_min_side(image_bgr, minimum_side)
    return cv2.resize(image_bgr, (new_width, new_height), interpolation=cv2.INTER_LANCZOS4)


def upscale_with_enhanced_lanczos(image_bgr, minimum_side):
    current = image_bgr
    try:
        current = apply_denoise(current)
    except Exception as e:
        logger.warning(f"[Denoise] Failed, skipping: {e}")

    current = upscale_with_lanczos(current, minimum_side)
    try:
        current = apply_sharpen(current)
    except Exception as e:
        logger.warning(f"[Sharpen] Failed, skipping: {e}")

    return current


def dimensions_for_min_side(image_bgr, minimum_side):
    height, width = image_bgr.shape[:2]
    scale = minimum_side / float(min(height, width))
    new_width = max(int(round(width * scale)), minimum_side)
    new_height = max(int(round(height * scale)), minimum_side)
    return new_width, new_height


def downscale_to_target(image_bgr, minimum_side):
    """Downscale an image so its shortest side matches minimum_side exactly.

    After AI upscale (which jumps in 4x or 2x increments), the result often
    overshoots the target. This function resizes down using Lanczos4
    to preserve quality while hitting the correct final size.
    """
    height, width = image_bgr.shape[:2]
    current_min_side = min(height, width)
    if current_min_side <= minimum_side:
        return image_bgr
    new_width, new_height = dimensions_for_min_side(image_bgr, minimum_side)
    logger.info(
        f"[Downscale] Resizing from {width}x{height} to {new_width}x{new_height} "
        f"(target min-side: {minimum_side}px)"
    )
    return cv2.resize(image_bgr, (new_width, new_height), interpolation=cv2.INTER_LANCZOS4)


def upscale_until_min_side(image_bgr, minimum_side):
    """Choose an upscale strategy based on how close the image already is to the target.

    Three tiers (configurable via env vars):
      ratio < TIER_4X_THRESHOLD (default 0.50)
          → Real-ESRGAN 4x  (heavy neural reconstruction for very small images)
      TIER_4X_THRESHOLD <= ratio < TIER_2X_THRESHOLD (default 0.75)
          → Real-ESRGAN 2x  (light boost for medium images)
      ratio >= TIER_2X_THRESHOLD
          → Lanczos4  (classical rescale, avoids any AI "oil painting" look)

    After any AI upscale the result is always downscaled back to minimum_side so
    the overshoot from fixed-increment models (4x, 2x) is corrected cleanly.
    """
    current = image_bgr
    runtime = upscale_runtime()
    current_min_side = min(current.shape[0], current.shape[1])
    ratio = current_min_side / float(minimum_side)

    logger.info(
        f"[Upscale] Image min-side {current_min_side}px, target {minimum_side}px, "
        f"ratio {ratio:.2f} ({runtime.upper()} mode)"
    )

    # ── Tier 3: >= 75% → Lanczos ────────────────────────────────────────────
    if ratio >= TIER_2X_THRESHOLD:
        logger.info(
            f"[Tier Lanczos] ratio {ratio:.2f} >= {TIER_2X_THRESHOLD} — "
            "applying Lanczos4 + CAS sharpen (no AI)."
        )
        return upscale_with_enhanced_lanczos(current, minimum_side)

    # ── Tier 2: 50–74.9% → 2x Real-ESRGAN ───────────────────────────────────
    if ratio >= TIER_4X_THRESHOLD:
        logger.info(
            f"[Tier 2x] ratio {ratio:.2f} in [{TIER_4X_THRESHOLD}, {TIER_2X_THRESHOLD}) — "
            "applying Real-ESRGAN 2x."
        )
        try:
            current = upscale_with_realesrgan(current, outscale=2)
        except Exception as e:
            logger.error(f"[Tier 2x] Real-ESRGAN 2x failed: {e}", exc_info=True)
            return upscale_with_enhanced_lanczos(current, minimum_side)

        # Downscale back to target in case 2x overshot
        current = downscale_to_target(current, minimum_side)
        return current

    # ── Tier 1: < 50% → Real-ESRGAN 4x (loop until target reached) ──────────
    logger.info(
        f"[Tier 4x] ratio {ratio:.2f} < {TIER_4X_THRESHOLD} — "
        "applying Real-ESRGAN 4x."
    )
    passes = 0
    while min(current.shape[0], current.shape[1]) < minimum_side and passes < MAX_AI_PASSES:
        try:
            current = upscale_with_realesrgan(current, outscale=REAL_ESRGAN_SCALE)
            passes += 1
        except Exception as e:
            logger.error(f"[Tier 4x] Real-ESRGAN failed ({runtime}): {e}", exc_info=True)
            break

    if min(current.shape[0], current.shape[1]) < minimum_side:
        logger.warning("[Tier 4x] AI upscale insufficient or failed. Falling back to Lanczos.")
        current = upscale_with_enhanced_lanczos(current, minimum_side)

    # Downscale back to target (4x may overshoot, e.g. 270px → 1080px for target 360px)
    current = downscale_to_target(current, minimum_side)
    return current


def finalize_output(image_bgr):
    return image_bgr


@app.on_event("startup")
async def startup_event():
    logger.info("Initializing SCC Image Upscale Service...")
    runtime = upscale_runtime()
    logger.info(f"Target mode: {runtime.upper()}")
    logger.info(
        f"Upscale tiers: 4x below {TIER_4X_THRESHOLD:.0%}, "
        f"2x in [{TIER_4X_THRESHOLD:.0%}, {TIER_2X_THRESHOLD:.0%}), "
        f"Lanczos+CAS at {TIER_2X_THRESHOLD:.0%}+"
    )

    try:
        logger.info(f"Pre-loading {runtime.upper()} upscaler model...")
        get_upscaler(runtime)
        logger.info(f"{runtime.upper()} upscaler model pre-loaded successfully!")
    except Exception as e:
        logger.error(f"Failed to pre-load upscaler model on startup: {e}", exc_info=True)
        logger.warning("Service will start but will fall back to Lanczos resizing for all upscaling requests.")


@app.get("/health")
async def health():
    runtime = upscale_runtime()
    return {
        "status": "ok",
        "mode": runtime,
        "model_path": model_path_for_runtime(runtime),
        "ai_denoise_enabled": False,
        "target_min_side": target_min_side(),
        "tier_4x_threshold": TIER_4X_THRESHOLD,
        "tier_2x_threshold": TIER_2X_THRESHOLD,
        "lanczos_denoise_enabled": True,
        "denoise_h": DENOISE_H,
        "lanczos_sharpen_method": "cas",
        "lanczos_cas_amount": LANCZOS_CAS_AMOUNT,
    }


@app.post("/upscale", dependencies=[Depends(verify_api_key)])
async def upscale(file: UploadFile = File(...), minimum_side: int | None = None):
    minimum_side = minimum_side or target_min_side()
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
