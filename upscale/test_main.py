import io
import os
import unittest
from unittest.mock import patch

import numpy as np
from fastapi.testclient import TestClient
from PIL import Image

try:
    import upscale.main as main
except ModuleNotFoundError:  # pragma: no cover - container runtime fallback
    import main


def build_test_jpeg(width=128, height=96, color=(40, 90, 150)):
    image = Image.new("RGB", (width, height), color=color)
    buffer = io.BytesIO()
    image.save(buffer, format="JPEG", quality=95)
    return buffer.getvalue()


class UpscaleServiceTests(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(main.app)

    def test_env_flag_defaults_to_enabled_for_gpu_mode(self):
        with patch.dict(os.environ, {}, clear=True):
            self.assertTrue(main.should_use_gpu_upscaler())

    def test_env_flag_can_disable_gpu_mode(self):
        with patch.dict(os.environ, {"USE_GPU_UPSCALER": "false"}, clear=True):
            self.assertFalse(main.should_use_gpu_upscaler())

    def test_finalize_output_preserves_aspect_ratio(self):
        source = np.zeros((320, 520, 3), dtype=np.uint8)

        result = main.finalize_output(source)

        self.assertEqual(result.shape[0], 320)
        self.assertEqual(result.shape[1], 520)

    def test_lanczos_fallback_is_used_when_ai_upsampler_fails(self):
        image = np.zeros((128, 96, 3), dtype=np.uint8)

        with patch.object(main, "should_use_gpu_upscaler", return_value=False), \
             patch.object(main, "upscale_with_realesrgan", side_effect=RuntimeError("boom")):
            result = main.upscale_until_min_side(image, 512)

        self.assertGreaterEqual(min(result.shape[:2]), 512)

    def test_lanczos_fallback_logs_error_when_ai_upsampler_fails(self):
        image = np.zeros((128, 96, 3), dtype=np.uint8)

        with patch.object(main, "should_use_gpu_upscaler", return_value=False), \
             patch.object(main, "upscale_with_realesrgan", side_effect=RuntimeError("boom")), \
             patch.object(main.logger, "error") as mock_log_error:
            result = main.upscale_until_min_side(image, 512)

        mock_log_error.assert_called()
        self.assertGreaterEqual(min(result.shape[:2]), 512)

    def test_endpoint_preserves_aspect_ratio(self):
        source = build_test_jpeg()
        upscale_result = np.zeros((540, 720, 3), dtype=np.uint8)

        with patch.object(main, "upscale_until_min_side", return_value=upscale_result), \
             patch.object(main, "finalize_output", side_effect=lambda image: image):
            response = self.client.post(
                "/upscale?minimum_side=512",
                files={"file": ("input.jpg", source, "image/jpeg")}
            )

        self.assertEqual(response.status_code, 200)
        output = Image.open(io.BytesIO(response.content))
        self.assertEqual(output.size, (720, 540))


if __name__ == "__main__":
    unittest.main()
