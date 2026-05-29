import argparse
import io
import os
import sys

import cv2
import numpy as np
from PIL import Image, ImageOps

sys.path.insert(0, os.path.abspath("."))

from upscale import main


def load_bgr(path):
    with Image.open(path) as image:
        image = ImageOps.exif_transpose(image).convert("RGB")
        return cv2.cvtColor(np.array(image), cv2.COLOR_RGB2BGR)


def save_jpeg(path, image_bgr):
    output_rgb = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
    output_image = Image.fromarray(output_rgb)
    output_image.save(path, format="JPEG", quality=95, optimize=True)


def generate_lanczos(source_bgr, minimum_side):
    return main.upscale_with_lanczos(source_bgr, minimum_side)


def generate_cpu_realesrgan(source_bgr, minimum_side, denoise_strength=None):
    os.environ["UPSCALE_RUNTIME"] = "cpu"
    if denoise_strength is not None:
        os.environ["REAL_ESRGAN_DENOISE_STRENGTH"] = str(denoise_strength)
    main.get_upscaler.cache_clear()
    return main.upscale_until_min_side(source_bgr, minimum_side)


def main_cli():
    parser = argparse.ArgumentParser()
    parser.add_argument("input")
    parser.add_argument("--minimum-side", type=int, default=1080)
    parser.add_argument("--lanczos-output", required=True)
    parser.add_argument("--cpu-output", required=True)
    parser.add_argument("--cpu-denoise-strength", type=float)
    args = parser.parse_args()

    source = load_bgr(args.input)
    lanczos = generate_lanczos(source.copy(), args.minimum_side)
    cpu = generate_cpu_realesrgan(source.copy(), args.minimum_side, args.cpu_denoise_strength)

    save_jpeg(args.lanczos_output, lanczos)
    save_jpeg(args.cpu_output, cpu)

    print(f"Lanczos: {args.lanczos_output} {lanczos.shape[1]}x{lanczos.shape[0]}")
    denoise_label = (
        f" denoise_strength={args.cpu_denoise_strength}"
        if args.cpu_denoise_strength is not None
        else ""
    )
    print(f"CPU Real-ESRGAN{denoise_label}: {args.cpu_output} {cpu.shape[1]}x{cpu.shape[0]}")


if __name__ == "__main__":
    main_cli()
