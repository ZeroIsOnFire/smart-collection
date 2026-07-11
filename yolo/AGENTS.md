# AGENTS.md - SCC YOLO Detection Service

## Overview

This is a specialized object-detection microservice using the YOLO11s model. It is designed to run locally, usually CPU-only, inside the Smart Collection Catalog ecosystem so item detection does not depend on external APIs.

## Security

This service is protected by:

- **Network isolation**: the service does not expose ports to the host; Rails and Sidekiq reach it through the internal Docker network.
- **API key authentication**: every request to `/detect`, `/classify`, or `/classify_color` must include the `X-API-Key` header when `YOLO_API_KEY` is configured.

## Technology Stack

- **Base image**: `ultralytics/ultralytics:latest-cpu`
- **API framework**: FastAPI on Python 3.10+
- **Model**: YOLO11s
- **Server**: Uvicorn
- **Color detection**: HSV/K-Means logic implemented locally in `main.py`

## File Structure

- `main.py`: API logic, model loading, authentication, detection parsing, and color classification.
- `Dockerfile`: container configuration.
- `requirements.txt`: additional dependencies.

## Development Conventions

- The `yolo11s.pt` model is downloaded automatically on first boot when it is not already present.
- Always return normalized coordinates (`0.0` to `1.0`) as vertices for compatibility with the Rails `ImageCropperService`.
- Optimize for CPU execution. Do not assume CUDA or NVIDIA GPU availability.
- Keep `ULTRALYTICS_OFFLINE=True` to avoid network checks and analytics calls from isolated containers.
- Rails must not use YOLO labels as item names/models. Detected items use translated generic labels.

## Troubleshooting And Gotchas

- **PyTorch 2.6+ crash**: starting with PyTorch 2.6, `torch.load` defaults to `weights_only=True`, which breaks `ultralytics` package deserialization. Keep the monkeypatch that forces `weights_only=False` before importing `ultralytics`.
- **Ultralytics network dependency**: `ultralytics` may try network calls for update checks or analytics. Keep `ULTRALYTICS_OFFLINE=True`.
- **Color detection**: color detection does not use another ML model. It uses K-Means clustering in HSV space on a central crop, filtering white/black reflections to identify the dominant color. The full logic lives in `main.py` in `ColorDetector`.
