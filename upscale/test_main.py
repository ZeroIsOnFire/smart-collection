import io
import os
import unittest
from unittest.mock import patch, MagicMock

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

    # ── env helpers ─────────────────────────────────────────────────────────

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

    # ── Tier 1: < 50% → 4x Real-ESRGAN ─────────────────────────────────────

    def test_tier_4x_engaged_when_ratio_below_50_percent(self):
        """Image at 40% of target (144px for target 360px) must use Real-ESRGAN 4x."""
        img_min_side = int(360 * 0.40)  # 144px
        image = np.zeros((img_min_side, img_min_side + 50, 3), dtype=np.uint8)
        big_image = np.zeros((600, 700, 3), dtype=np.uint8)

        with patch.object(main, "should_use_gpu_upscaler", return_value=False), \
             patch.object(main, "upscale_with_realesrgan", return_value=big_image) as mock_ai, \
             patch.object(main, "apply_denoise", side_effect=lambda x: x) as mock_denoise:
            result = main.upscale_until_min_side(image, 360)

        mock_ai.assert_called()
        # The 4x tier should not denoise before the AI call
        mock_denoise.assert_not_called()
        self.assertGreaterEqual(min(result.shape[:2]), 360)

    def test_tier_4x_fallback_to_lanczos_when_ai_fails(self):
        """If 4x AI fails, must fall back to Lanczos and still meet the target."""
        img_min_side = int(360 * 0.30)
        image = np.zeros((img_min_side, img_min_side + 50, 3), dtype=np.uint8)

        with patch.object(main, "should_use_gpu_upscaler", return_value=False), \
             patch.object(main, "upscale_with_realesrgan", side_effect=RuntimeError("boom")):
            result = main.upscale_until_min_side(image, 360)

        self.assertGreaterEqual(min(result.shape[:2]), 360)

    def test_tier_4x_fallback_logs_error_when_ai_fails(self):
        img_min_side = int(360 * 0.30)
        image = np.zeros((img_min_side, img_min_side + 50, 3), dtype=np.uint8)

        with patch.object(main, "should_use_gpu_upscaler", return_value=False), \
             patch.object(main, "upscale_with_realesrgan", side_effect=RuntimeError("boom")), \
             patch.object(main.logger, "error") as mock_log_error:
            result = main.upscale_until_min_side(image, 360)

        mock_log_error.assert_called()
        self.assertGreaterEqual(min(result.shape[:2]), 360)

    # ── Tier 2: 50–74.9% → Denoise + 2x Real-ESRGAN ─────────────────────────

    def test_tier_2x_engaged_when_ratio_between_50_and_74_percent(self):
        """Image at 60% of target (216px for target 360px) must use Denoise + 2x."""
        img_min_side = int(360 * 0.60)  # 216px
        image = np.zeros((img_min_side, img_min_side + 50, 3), dtype=np.uint8)
        upscaled_2x = np.zeros((img_min_side * 2 + 50, (img_min_side + 50) * 2, 3), dtype=np.uint8)

        with patch.object(main, "should_use_gpu_upscaler", return_value=False), \
             patch.object(main, "upscale_with_realesrgan", return_value=upscaled_2x) as mock_ai, \
             patch.object(main, "apply_denoise", side_effect=lambda x: x) as mock_denoise:
            result = main.upscale_until_min_side(image, 360)

        # Denoise must be called before AI in this tier
        mock_denoise.assert_called_once()
        # outscale=2 must be passed to the AI
        call_kwargs = mock_ai.call_args
        self.assertEqual(call_kwargs.kwargs.get("outscale") or call_kwargs.args[2] if len(call_kwargs.args) > 2 else None, 2)
        self.assertGreaterEqual(min(result.shape[:2]), 360)

    def test_tier_2x_calls_realesrgan_with_outscale_2(self):
        """Real-ESRGAN must receive outscale=2 in the 2x tier."""
        img_min_side = int(360 * 0.65)
        image = np.zeros((img_min_side, img_min_side + 50, 3), dtype=np.uint8)
        big_enough = np.zeros((600, 700, 3), dtype=np.uint8)

        with patch.object(main, "should_use_gpu_upscaler", return_value=False), \
             patch.object(main, "apply_denoise", side_effect=lambda x: x), \
             patch.object(main, "upscale_with_realesrgan", return_value=big_enough) as mock_ai:
            main.upscale_until_min_side(image, 360)

        mock_ai.assert_called_once()
        _, kwargs = mock_ai.call_args
        self.assertEqual(kwargs.get("outscale"), 2)

    def test_tier_2x_fallback_to_lanczos_when_ai_fails(self):
        """If 2x AI fails in the 2x tier, must fall back to Lanczos."""
        img_min_side = int(360 * 0.60)
        image = np.zeros((img_min_side, img_min_side + 50, 3), dtype=np.uint8)

        with patch.object(main, "should_use_gpu_upscaler", return_value=False), \
             patch.object(main, "apply_denoise", side_effect=lambda x: x), \
             patch.object(main, "upscale_with_realesrgan", side_effect=RuntimeError("boom")):
            result = main.upscale_until_min_side(image, 360)

        self.assertGreaterEqual(min(result.shape[:2]), 360)

    # ── Tier 3: >= 75% → Denoise + Lanczos ──────────────────────────────────

    def test_tier_lanczos_engaged_when_ratio_at_or_above_75_percent(self):
        """Image at 80% of target (288px) must skip AI entirely and use Denoise+Lanczos."""
        img_min_side = int(360 * 0.80)  # 288px
        image = np.zeros((img_min_side, img_min_side + 50, 3), dtype=np.uint8)

        with patch.object(main, "should_use_gpu_upscaler", return_value=False), \
             patch.object(main, "upscale_with_realesrgan") as mock_ai, \
             patch.object(main, "apply_denoise", side_effect=lambda x: x) as mock_denoise:
            result = main.upscale_until_min_side(image, 360)

        mock_ai.assert_not_called()
        mock_denoise.assert_called_once()
        self.assertGreaterEqual(min(result.shape[:2]), 360)

    def test_tier_lanczos_still_works_when_denoise_fails(self):
        """If denoise raises, tier 3 must still produce a valid image via Lanczos."""
        img_min_side = int(360 * 0.80)
        image = np.zeros((img_min_side, img_min_side + 50, 3), dtype=np.uint8)

        with patch.object(main, "should_use_gpu_upscaler", return_value=False), \
             patch.object(main, "apply_denoise", side_effect=Exception("denoise failed")):
            result = main.upscale_until_min_side(image, 360)

        self.assertGreaterEqual(min(result.shape[:2]), 360)

    # ── Downscale after AI ───────────────────────────────────────────────────

    def test_downscale_to_target_reduces_overshot_image(self):
        """After a 4x AI upscale, a 270px image becomes 1080px. Must downscale to 360px."""
        image = np.zeros((1080, 1440, 3), dtype=np.uint8)
        result = main.downscale_to_target(image, 360)
        self.assertEqual(min(result.shape[:2]), 360)
        self.assertEqual(result.shape[1], 480)
        self.assertEqual(result.shape[0], 360)

    def test_downscale_to_target_preserves_image_at_target(self):
        """Image already at target size should not be modified."""
        image = np.zeros((360, 480, 3), dtype=np.uint8)
        result = main.downscale_to_target(image, 360)
        self.assertEqual(result.shape[:2], (360, 480))

    def test_downscale_to_target_preserves_image_below_target(self):
        """Image below target should not be modified."""
        image = np.zeros((200, 300, 3), dtype=np.uint8)
        result = main.downscale_to_target(image, 360)
        self.assertEqual(result.shape[:2], (200, 300))

    def test_4x_pipeline_downscales_to_target_not_4x_overshoot(self):
        """A 270px image targeting 360 should end at 360px, not 1080px."""
        image = np.zeros((270, 360, 3), dtype=np.uint8)
        upscaled = np.zeros((1080, 1440, 3), dtype=np.uint8)

        with patch.object(main, "should_use_gpu_upscaler", return_value=False), \
             patch.object(main, "upscale_with_realesrgan", return_value=upscaled):
            result = main.upscale_until_min_side(image, 360)

        self.assertEqual(min(result.shape[:2]), 360)

    def test_2x_pipeline_downscales_to_target_not_2x_overshoot(self):
        """A 200px image targeting 360 (ratio 0.55) should end at 360px, not 400px."""
        image = np.zeros((200, 260, 3), dtype=np.uint8)
        # Simulate 2x upscale result: 200 → 400, 260 → 520
        upscaled_2x = np.zeros((400, 520, 3), dtype=np.uint8)

        with patch.object(main, "should_use_gpu_upscaler", return_value=False), \
             patch.object(main, "apply_denoise", side_effect=lambda x: x), \
             patch.object(main, "upscale_with_realesrgan", return_value=upscaled_2x):
            result = main.upscale_until_min_side(image, 360)

        self.assertEqual(min(result.shape[:2]), 360)

    # ── HTTP endpoint ────────────────────────────────────────────────────────

    def test_endpoint_returns_jpeg_with_correct_dimensions(self):
        source = build_test_jpeg()
        upscale_result = np.zeros((540, 720, 3), dtype=np.uint8)

        with patch.dict(os.environ, {"IMAGE_UPSCALE_API_KEY": ""}), \
             patch.object(main, "upscale_until_min_side", return_value=upscale_result), \
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
