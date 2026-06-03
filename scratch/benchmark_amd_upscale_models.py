import csv
import os
import sys
import time
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageOps

sys.path.insert(0, "/app")

import main


MODELS = [
    ("RealESRGAN_x4plus", "/tmp/upscale_models/RealESRGAN_x4plus.pth"),
    ("4x-UltraSharp", "/tmp/upscale_models/4x-UltraSharp.pth"),
    ("4x_foolhardy_Remacri", "/tmp/upscale_models/4x_foolhardy_Remacri.pth"),
    ("4x_NMKD-Siax", "/tmp/upscale_models/4x_NMKD-Siax_200k.pth"),
    ("4xNomos8kSC", "/tmp/upscale_models/4xNomos8kSC.pth"),
]


def cuda_sync():
    if main.torch and main.torch.cuda.is_available():
        main.torch.cuda.synchronize()


def load_bgr(path):
    with Image.open(path) as image:
        image = ImageOps.exif_transpose(image).convert("RGB")
        return cv2.cvtColor(np.array(image), cv2.COLOR_RGB2BGR)


def save_jpeg(path, image_bgr):
    output_rgb = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
    Image.fromarray(output_rgb).save(path, format="JPEG", quality=95, optimize=True)


def build_upscaler(model_path):
    model = main.RRDBNet(
        num_in_ch=3,
        num_out_ch=3,
        scale=main.REAL_ESRGAN_SCALE,
        num_feat=64,
        num_block=23,
        num_grow_ch=32,
    )
    return main.RealESRGANer(
        scale=main.REAL_ESRGAN_SCALE,
        model_path=model_path,
        model=model,
        tile=0,
        tile_pad=10,
        pre_pad=0,
        half=True,
        device="cuda",
    )


def benchmark_model(name, model_path, source_bgr, output_dir):
    if not Path(model_path).exists():
        return {
            "model": name,
            "status": "missing",
            "model_path": model_path,
            "load_seconds": "",
            "cold_inference_seconds": "",
            "warm_inference_seconds": "",
            "total_seconds": "",
            "output_width": "",
            "output_height": "",
            "output": "",
            "error": f"model file not found: {model_path}",
        }

    started = time.perf_counter()
    upscaler = build_upscaler(model_path)
    cuda_sync()
    loaded = time.perf_counter()

    _, _ = upscaler.enhance(source_bgr, outscale=main.REAL_ESRGAN_SCALE)
    cuda_sync()
    cold_inferred = time.perf_counter()

    output_bgr, _ = upscaler.enhance(source_bgr, outscale=main.REAL_ESRGAN_SCALE)
    cuda_sync()
    warm_inferred = time.perf_counter()

    output_path = output_dir / f"{name}.jpg"
    save_jpeg(output_path, output_bgr)
    finished = time.perf_counter()
    height, width = output_bgr.shape[:2]

    return {
        "model": name,
        "status": "ok",
        "model_path": model_path,
        "load_seconds": f"{loaded - started:.4f}",
        "cold_inference_seconds": f"{cold_inferred - loaded:.4f}",
        "warm_inference_seconds": f"{warm_inferred - cold_inferred:.4f}",
        "total_seconds": f"{finished - started:.4f}",
        "output_width": width,
        "output_height": height,
        "output": str(output_path),
        "error": "",
    }


def main_cli():
    input_path = Path(os.environ.get("BENCHMARK_INPUT", "/workspace/images.jfif"))
    output_dir = Path(os.environ.get("BENCHMARK_OUTPUT_DIR", "/workspace/tmp/upscale_model_comparison"))
    output_dir.mkdir(parents=True, exist_ok=True)

    source_bgr = load_bgr(input_path)
    rows = []
    for name, model_path in MODELS:
        print(f"Benchmarking {name}...")
        try:
            rows.append(benchmark_model(name, model_path, source_bgr.copy(), output_dir))
        except Exception as exc:
            rows.append({
                "model": name,
                "status": "error",
                "model_path": model_path,
                "load_seconds": "",
                "cold_inference_seconds": "",
                "warm_inference_seconds": "",
                "total_seconds": "",
                "output_width": "",
                "output_height": "",
                "output": "",
                "error": repr(exc),
            })

        if main.torch and main.torch.cuda.is_available():
            main.torch.cuda.empty_cache()

    summary_path = output_dir / "summary.csv"
    with summary_path.open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)

    print(f"Summary: {summary_path}")
    for row in rows:
        print(
            f"{row['model']}: {row['status']} "
            f"load={row['load_seconds']}s cold={row['cold_inference_seconds']}s "
            f"warm={row['warm_inference_seconds']}s "
            f"total={row['total_seconds']}s output={row['output']} error={row['error']}"
        )


if __name__ == "__main__":
    main_cli()
