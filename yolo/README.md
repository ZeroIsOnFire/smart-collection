# SCC YOLO Detection Service

[Leia em portugues](README.pt-BR.md)

FastAPI microservice responsible for local vehicle detection and simple color classification in Smart Collection Catalog autodetection flows.

## HTTP Endpoints

- `GET /health`: returns service status and loaded model information.
- `POST /detect`: receives multipart `file` and returns detections with `label`, `score`, normalized `vertices`, and `color`.
- `POST /classify_color`: receives multipart `file` and returns only the detected color.
- `POST /classify`: receives multipart `file` and returns vehicle label plus color.

When `YOLO_API_KEY` is configured, send the `X-API-Key` header.

## Model And Detection

- Default model: `yolo11s.pt`.
- Override with `YOLO_MODEL`.
- The service uses COCO vehicle classes (`1..8`) for detection and classification.
- Coordinates are returned as normalized vertices (`0.0` to `1.0`) in the shape expected by Rails.
- The service is designed for local CPU usage; do not assume CUDA/GPU support.

## Docker Compose

The service is built from `yolo/Dockerfile` and runs on the internal Docker network. It does not need to expose a host port.

Typical `docker-compose.yml` service:

```yaml
yolo-service:
  build:
    context: ./yolo
  environment:
    - YOLO_API_KEY=${YOLO_API_KEY}
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
```

Start only YOLO:

```sh
docker compose up -d --build yolo-service
```

View logs:

```sh
docker compose logs --tail=80 yolo-service
```

## Environment Variables

- `YOLO_API_KEY`: optional key required by the `X-API-Key` header.
- `YOLO_MODEL`: model path/name; defaults to `yolo11s.pt`.
- `ULTRALYTICS_OFFLINE=True`: required to avoid Ultralytics network/analytics calls in the container.

## Color Detection

Color detection does not use an extra model. `ColorDetector`:

- resizes the image to speed up processing;
- uses the crop center to avoid background noise;
- converts pixels to HSV;
- filters shadows and highlights;
- applies K-Means;
- classifies simple names such as `Vermelho`, `Azul`, `Preto`, `Branco`, `Prata`, `Cinza`, and `Dourado`.

## Caveats

- The `torch.load(weights_only=False)` monkeypatch must run before importing `ultralytics`, because of PyTorch 2.6+.
- Keep `ULTRALYTICS_OFFLINE=True` in the container.
- Rails must not use the YOLO label to automatically fill item name/model. Newly detected items use a translated generic label.

## Manual Test

With the service running and a local image:

```sh
curl -H "X-API-Key: $YOLO_API_KEY" \
  -F "file=@/path/to/image.jpg" \
  http://localhost:8000/detect
```

Inside Compose, Rails and Sidekiq containers should call `http://yolo-service:8000`.
