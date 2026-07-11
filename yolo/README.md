# SCC YOLO Detection Service

[Leia em português](README.pt-BR.md)

FastAPI microservice responsible for local YOLO11s object detection and simple color classification in Smart Collection Catalog autodetection flows.

## Endpoints

- `GET /health`: returns service status.
- `POST /detect`: receives multipart `file`; returns detected objects with normalized vertex coordinates.
- `POST /classify`: receives multipart `file`; returns the main object label and detected color.
- `POST /classify_color`: receives multipart `file`; returns the dominant color classification.

When `YOLO_API_KEY` is configured, send the `X-API-Key` header.

## Model And Output Contract

- Default model: `yolo11s.pt`.
- Override with `YOLO_MODEL`.
- The service is optimized for CPU and must not assume GPU availability.
- Coordinates return as normalized vertices (`0.0` to `1.0`) in the shape expected by Rails.
- Rails must not use YOLO labels to automatically fill item name/model. Newly detected items use translated generic labels.
- Color classification uses local HSV/K-Means logic in `main.py`; it does not depend on a second ML model.

## Docker Compose

The service is built from `yolo/Dockerfile` and runs on the internal Docker network. It does not need to expose a host port.

Example service entry:

```yaml
yolo-service:
  build:
    context: ./yolo
  environment:
    - YOLO_API_KEY=${YOLO_API_KEY}
  restart: unless-stopped
```

Start only YOLO:

```bash
docker compose up -d --build yolo-service
```

Inside Compose, Rails and Sidekiq should call:

```text
http://yolo-service:8000
```

## Environment Variables

- `YOLO_API_KEY`: optional key required by the `X-API-Key` header.
- `YOLO_MODEL`: model path/name; defaults to `yolo11s.pt`.
- `ULTRALYTICS_OFFLINE`: must stay `True` to avoid network calls from isolated containers.

## Development Notes

- Keep the `torch.load(weights_only=False)` monkeypatch before importing `ultralytics`; PyTorch 2.6+ otherwise breaks model deserialization.
- Keep output coordinates normalized and compatible with the Rails cropper.
- Do not add Python dependencies unless explicitly approved.
- If tests are added, they must not download models or require GPU access.

## Manual Request Example

```bash
curl -H "X-API-Key: $YOLO_API_KEY" \
  -F "file=@sample.jpg" \
  http://localhost:8000/detect
```

In the default project setup, call the service from Rails/Sidekiq through `http://yolo-service:8000`, not through a host port.
