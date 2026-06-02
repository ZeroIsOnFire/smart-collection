import os
import sys
import time
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageOps

sys.path.insert(0, "/app")

import main


def load_bgr(path):
    with Image.open(path) as image:
        image = ImageOps.exif_transpose(image).convert("RGB")
        return cv2.cvtColor(np.array(image), cv2.COLOR_RGB2BGR)


def save_jpeg(path, image_bgr):
    output_rgb = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)
    Image.fromarray(output_rgb).save(path, format="JPEG", quality=95, optimize=True)


def run_case(input_path, output_dir):
    source = load_bgr(input_path)
    minimum_side = min(source.shape[:2]) * 4
    started = time.perf_counter()
    output = main.upscale_with_enhanced_lanczos(source, minimum_side)
    elapsed = time.perf_counter() - started

    output_path = output_dir / f"{Path(input_path).stem}_lanczos_denoise.jpg"
    save_jpeg(output_path, output)
    return {
        "input": str(input_path),
        "output": str(output_path),
        "seconds": f"{elapsed:.4f}",
        "output_width": output.shape[1],
        "output_height": output.shape[0],
    }


def main_cli():
    output_dir = Path(os.environ.get("LANCZOS_OUTPUT_DIR", "/tmp/benchmark_workspace/lanczos_denoise"))
    output_dir.mkdir(parents=True, exist_ok=True)
    inputs = os.environ.get(
        "LANCZOS_INPUTS",
        "/tmp/benchmark_workspace/images.jfif;/tmp/benchmark_workspace/test2.png",
    ).split(";")

    rows = [run_case(Path(input_path), output_dir) for input_path in inputs]
    summary_path = output_dir / "summary.csv"
    with summary_path.open("w", encoding="utf-8") as file:
        file.write("input,output,seconds,output_width,output_height\n")
        for row in rows:
            file.write(
                f"{row['input']},{row['output']},{row['seconds']},"
                f"{row['output_width']},{row['output_height']}\n"
            )

    print(f"Summary: {summary_path}")
    for row in rows:
        print(
            f"{Path(row['input']).name}: {row['seconds']}s "
            f"{row['output_width']}x{row['output_height']} -> {row['output']}"
        )


if __name__ == "__main__":
    main_cli()
