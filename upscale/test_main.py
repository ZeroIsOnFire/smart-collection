import io
import os
import tempfile
import unittest
from collections import OrderedDict
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
        self.tier_4x_patcher = patch.object(main, "TIER_4X_THRESHOLD", 0.50)
        self.tier_2x_patcher = patch.object(main, "TIER_2X_THRESHOLD", 0.75)
        self.tier_4x_patcher.start()
        self.tier_2x_patcher.start()
        self.addCleanup(self.tier_4x_patcher.stop)
        self.addCleanup(self.tier_2x_patcher.stop)

    # ── env helpers ─────────────────────────────────────────────────────────

    def test_runtime_defaults_to_cpu(self):
        with patch.dict(os.environ, {}, clear=True):
            self.assertEqual(main.upscale_runtime(), "cpu")

    def test_runtime_accepts_nvidia_aliases(self):
        with patch.dict(os.environ, {"UPSCALE_RUNTIME": "cuda"}, clear=True):
            self.assertEqual(main.upscale_runtime(), "nvidia")

    def test_runtime_accepts_amd_aliases(self):
        with patch.dict(os.environ, {"UPSCALE_RUNTIME": "rocm"}, clear=True):
            self.assertEqual(main.upscale_runtime(), "amd")

    def test_torch_load_normalizes_realesrgan_params_ema_key(self):
        with tempfile.NamedTemporaryFile(suffix=".pth") as checkpoint:
            main.torch.save({"params_ema": {"weight": 1}}, checkpoint.name)

            loaded = main.torch.load(checkpoint.name)

        self.assertEqual(loaded["params"], {"weight": 1})

    def test_legacy_rrdb_keys_are_normalized(self):
        checkpoint = OrderedDict({
            "model.0.weight": 1,
            "model.1.sub.0.RDB1.conv1.0.weight": 2,
            "model.1.sub.23.weight": 3,
            "model.3.weight": 4,
            "model.6.weight": 5,
            "model.8.weight": 6,
            "model.10.weight": 7,
        })

        loaded = main.normalize_realesrgan_checkpoint(checkpoint)

        self.assertEqual(loaded["params"]["conv_first.weight"], 1)
        self.assertEqual(loaded["params"]["body.0.rdb1.conv1.weight"], 2)
        self.assertEqual(loaded["params"]["conv_body.weight"], 3)
        self.assertEqual(loaded["params"]["conv_up1.weight"], 4)
        self.assertEqual(loaded["params"]["conv_up2.weight"], 5)
        self.assertEqual(loaded["params"]["conv_hr.weight"], 6)
        self.assertEqual(loaded["params"]["conv_last.weight"], 7)

    def test_runtime_rejects_unknown_values(self):
        with patch.dict(os.environ, {"UPSCALE_RUNTIME": "quantum"}, clear=True):
            with self.assertRaises(RuntimeError):
                main.upscale_runtime()

    def test_target_min_side_uses_env_value(self):
        with patch.dict(os.environ, {"IMAGE_UPSCALE_DEFAULT_MINIMUM_SIDE": "512"}, clear=True):
            self.assertEqual(main.target_min_side(), 512)

    def test_target_min_side_falls_back_when_env_is_invalid(self):
        with patch.dict(os.environ, {"IMAGE_UPSCALE_DEFAULT_MINIMUM_SIDE": "nope"}, clear=True):
            self.assertEqual(main.target_min_side(), 360)

    def test_cpu_runtime_uses_lightweight_model_by_default(self):
        with patch.dict(os.environ, {"REAL_ESRGAN_MODEL_PATH": ""}, clear=True):
            self.assertEqual(main.model_path_for_runtime("cpu"), "/app/models/realesr-general-x4v3.pth")

    def test_gpu_runtime_uses_nmkd_siax_model_by_default(self):
        with patch.dict(os.environ, {"REAL_ESRGAN_MODEL_PATH": ""}, clear=True):
            self.assertEqual(main.model_path_for_runtime("amd"), "/app/models/4x_NMKD-Siax_200k.pth")

    def test_gpu_upscaler_uses_rrdb_model(self):
        main.get_upscaler.cache_clear()
        self.addCleanup(main.get_upscaler.cache_clear)

        with patch.object(main, "RealESRGANer") as mock_realesrganer, \
             patch.object(main, "RRDBNet", return_value="rrdb-model") as mock_rrdb, \
             patch.object(main.torch.cuda, "is_available", return_value=True), \
             patch.object(main, "require_model_paths", return_value="/app/models/4x_NMKD-Siax_200k.pth"):
            main.get_gpu_upscaler("amd")

        mock_rrdb.assert_called_once()
        _, kwargs = mock_realesrganer.call_args
        self.assertEqual(kwargs["model"], "rrdb-model")
        self.assertTrue(kwargs["half"])
        self.assertEqual(kwargs["device"], "cuda")

    def test_cpu_model_config_uses_base_model_without_ai_denoise(self):
        model_path, dni_weight = main.cpu_model_config()

        self.assertEqual(model_path, "/app/models/realesr-general-x4v3.pth")
        self.assertIsNone(dni_weight)

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

        with patch.object(main, "upscale_runtime", return_value="cpu"), \
             patch.object(main, "upscale_with_realesrgan", return_value=big_image) as mock_ai:
            result = main.upscale_until_min_side(image, 360)

        mock_ai.assert_called()
        self.assertGreaterEqual(min(result.shape[:2]), 360)

    def test_tier_4x_fallback_to_lanczos_when_ai_fails(self):
        """If 4x AI fails, must fall back to Lanczos and still meet the target."""
        img_min_side = int(360 * 0.30)
        image = np.zeros((img_min_side, img_min_side + 50, 3), dtype=np.uint8)

        with patch.object(main, "upscale_runtime", return_value="cpu"), \
             patch.object(main, "upscale_with_realesrgan", side_effect=RuntimeError("boom")):
            result = main.upscale_until_min_side(image, 360)

        self.assertGreaterEqual(min(result.shape[:2]), 360)

    def test_tier_4x_fallback_logs_error_when_ai_fails(self):
        img_min_side = int(360 * 0.30)
        image = np.zeros((img_min_side, img_min_side + 50, 3), dtype=np.uint8)

        with patch.object(main, "upscale_runtime", return_value="cpu"), \
             patch.object(main, "upscale_with_realesrgan", side_effect=RuntimeError("boom")), \
             patch.object(main.logger, "error") as mock_log_error:
            result = main.upscale_until_min_side(image, 360)

        mock_log_error.assert_called()
        self.assertGreaterEqual(min(result.shape[:2]), 360)

    # ── Tier 2: 50–74.9% → 2x Real-ESRGAN ───────────────────────────────────

    def test_tier_2x_engaged_when_ratio_between_50_and_74_percent(self):
        """Image at 60% of target (216px for target 360px) must use 2x AI."""
        img_min_side = int(360 * 0.60)  # 216px
        image = np.zeros((img_min_side, img_min_side + 50, 3), dtype=np.uint8)
        upscaled_2x = np.zeros((img_min_side * 2 + 50, (img_min_side + 50) * 2, 3), dtype=np.uint8)

        with patch.object(main, "upscale_runtime", return_value="cpu"), \
             patch.object(main, "upscale_with_realesrgan", return_value=upscaled_2x) as mock_ai:
            result = main.upscale_until_min_side(image, 360)

        # outscale=2 must be passed to the AI
        _, kwargs = mock_ai.call_args
        self.assertEqual(kwargs.get("outscale"), 2)
        self.assertGreaterEqual(min(result.shape[:2]), 360)

    def test_tier_2x_calls_realesrgan_with_outscale_2(self):
        """Real-ESRGAN must receive outscale=2 in the 2x tier."""
        img_min_side = int(360 * 0.65)
        image = np.zeros((img_min_side, img_min_side + 50, 3), dtype=np.uint8)
        big_enough = np.zeros((600, 700, 3), dtype=np.uint8)

        with patch.object(main, "upscale_runtime", return_value="cpu"), \
             patch.object(main, "upscale_with_realesrgan", return_value=big_enough) as mock_ai:
            main.upscale_until_min_side(image, 360)

        mock_ai.assert_called_once()
        _, kwargs = mock_ai.call_args
        self.assertEqual(kwargs.get("outscale"), 2)

    def test_tier_2x_fallback_to_lanczos_when_ai_fails(self):
        """If 2x AI fails in the 2x tier, must fall back to Lanczos."""
        img_min_side = int(360 * 0.60)
        image = np.zeros((img_min_side, img_min_side + 50, 3), dtype=np.uint8)

        with patch.object(main, "upscale_runtime", return_value="cpu"), \
             patch.object(main, "upscale_with_realesrgan", side_effect=RuntimeError("boom")):
            result = main.upscale_until_min_side(image, 360)

        self.assertGreaterEqual(min(result.shape[:2]), 360)

    # ── Tier 3: >= 75% → Lanczos ────────────────────────────────────────────

    def test_tier_lanczos_engaged_when_ratio_at_or_above_75_percent(self):
        """Image at 80% of target (288px) must skip AI entirely and use Lanczos."""
        img_min_side = int(360 * 0.80)  # 288px
        image = np.zeros((img_min_side, img_min_side + 50, 3), dtype=np.uint8)

        with patch.object(main, "upscale_runtime", return_value="cpu"), \
             patch.object(main, "upscale_with_realesrgan") as mock_ai:
            result = main.upscale_until_min_side(image, 360)

        mock_ai.assert_not_called()
        self.assertGreaterEqual(min(result.shape[:2]), 360)

    # ── Downscale after AI ───────────────────────────────────────────────────

    def test_tier_lanczos_applies_denoise_before_resize(self):
        img_min_side = int(360 * 0.80)
        image = np.zeros((img_min_side, img_min_side + 50, 3), dtype=np.uint8)
        denoised = np.ones_like(image)
        sharpened = np.full((360, 423, 3), 2, dtype=np.uint8)

        with patch.object(main, "upscale_runtime", return_value="cpu"), \
             patch.object(main, "apply_denoise", return_value=denoised) as mock_denoise, \
             patch.object(main, "upscale_with_lanczos", wraps=main.upscale_with_lanczos) as mock_lanczos, \
             patch.object(main, "apply_sharpen", return_value=sharpened) as mock_sharpen:
            result = main.upscale_until_min_side(image, 360)

        mock_denoise.assert_called_once_with(image)
        mock_lanczos.assert_called_once()
        self.assertIs(mock_lanczos.call_args.args[0], denoised)
        mock_sharpen.assert_called_once()
        self.assertIs(result, sharpened)
        self.assertGreaterEqual(min(result.shape[:2]), 360)

    def test_tier_lanczos_keeps_denoise_in_gpu_runtime(self):
        img_min_side = int(360 * 0.80)
        image = np.zeros((img_min_side, img_min_side + 50, 3), dtype=np.uint8)
        denoised = np.ones_like(image)
        sharpened = np.full((360, 423, 3), 2, dtype=np.uint8)

        with patch.object(main, "upscale_runtime", return_value="amd"), \
             patch.object(main, "apply_denoise", return_value=denoised) as mock_denoise, \
             patch.object(main, "upscale_with_lanczos", wraps=main.upscale_with_lanczos) as mock_lanczos, \
             patch.object(main, "apply_sharpen", return_value=sharpened) as mock_sharpen:
            result = main.upscale_until_min_side(image, 360)

        mock_denoise.assert_called_once_with(image)
        mock_lanczos.assert_called_once()
        self.assertIs(mock_lanczos.call_args.args[0], denoised)
        mock_sharpen.assert_called_once()
        self.assertIs(result, sharpened)
        self.assertGreaterEqual(min(result.shape[:2]), 360)

    def test_tier_lanczos_skips_denoise_when_filter_fails(self):
        img_min_side = int(360 * 0.80)
        image = np.zeros((img_min_side, img_min_side + 50, 3), dtype=np.uint8)

        with patch.object(main, "upscale_runtime", return_value="cpu"), \
             patch.object(main, "apply_denoise", side_effect=RuntimeError("boom")), \
             patch.object(main.logger, "warning") as mock_warning:
            result = main.upscale_until_min_side(image, 360)

        mock_warning.assert_called()
        self.assertGreaterEqual(min(result.shape[:2]), 360)

    def test_tier_lanczos_skips_sharpen_when_filter_fails(self):
        img_min_side = int(360 * 0.80)
        image = np.zeros((img_min_side, img_min_side + 50, 3), dtype=np.uint8)

        with patch.object(main, "upscale_runtime", return_value="cpu"), \
             patch.object(main, "apply_sharpen", side_effect=RuntimeError("boom")), \
             patch.object(main.logger, "warning") as mock_warning:
            result = main.upscale_until_min_side(image, 360)

        mock_warning.assert_called()
        self.assertGreaterEqual(min(result.shape[:2]), 360)

    def test_apply_cas_sharpen_returns_original_when_disabled(self):
        image = np.zeros((32, 32, 3), dtype=np.uint8)

        with patch.object(main, "LANCZOS_CAS_AMOUNT", 0):
            result = main.apply_cas_sharpen(image)

        self.assertIs(result, image)

    def test_apply_cas_sharpen_preserves_shape_and_dtype(self):
        image = np.full((32, 48, 3), 120, dtype=np.uint8)
        image[:, 24:] = 180

        result = main.apply_cas_sharpen(image)

        self.assertEqual(result.shape, image.shape)
        self.assertEqual(result.dtype, image.dtype)

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

        with patch.object(main, "upscale_runtime", return_value="cpu"), \
             patch.object(main, "upscale_with_realesrgan", return_value=upscaled):
            result = main.upscale_until_min_side(image, 360)

        self.assertEqual(min(result.shape[:2]), 360)

    def test_2x_pipeline_downscales_to_target_not_2x_overshoot(self):
        """A 200px image targeting 360 (ratio 0.55) should end at 360px, not 400px."""
        image = np.zeros((200, 260, 3), dtype=np.uint8)
        # Simulate 2x upscale result: 200 → 400, 260 → 520
        upscaled_2x = np.zeros((400, 520, 3), dtype=np.uint8)

        with patch.object(main, "upscale_runtime", return_value="cpu"), \
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

    def test_endpoint_uses_configured_default_minimum_side_when_query_is_missing(self):
        source = build_test_jpeg()
        upscale_result = np.zeros((540, 720, 3), dtype=np.uint8)

        with patch.dict(os.environ, {"IMAGE_UPSCALE_API_KEY": "", "IMAGE_UPSCALE_DEFAULT_MINIMUM_SIDE": "640"}), \
             patch.object(main, "upscale_until_min_side", return_value=upscale_result) as mock_upscale, \
             patch.object(main, "finalize_output", side_effect=lambda image: image):
            response = self.client.post(
                "/upscale",
                files={"file": ("input.jpg", source, "image/jpeg")}
            )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(mock_upscale.call_args.args[1], 640)


if __name__ == "__main__":
    unittest.main()
