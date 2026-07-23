import os
import io
import time
import torch

# Monkeypatch torch.load BEFORE importing ultralytics
# to handle PyTorch 2.6+ weights_only=True default
original_load = torch.load
def patched_load(*args, **kwargs):
    if 'weights_only' not in kwargs:
        kwargs['weights_only'] = False
    return original_load(*args, **kwargs)
torch.load = patched_load

from fastapi import FastAPI, File, UploadFile, HTTPException, Header, Depends, Request
from fastapi.responses import PlainTextResponse
from ultralytics import YOLO
from PIL import Image
import numpy as np
from sklearn.cluster import KMeans
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Gauge, Histogram, generate_latest
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.propagate import extract
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

class ColorDetector:
    def detect(self, image):
        # Resize for faster processing
        img = image.copy()
        img.thumbnail((100, 100))
        
        # Focus on center area to avoid background
        w, h = img.size
        left, top, right, bottom = w * 0.3, h * 0.3, w * 0.7, h * 0.7
        img = img.crop((left, top, right, bottom))
        
        # Convert to HSV using PIL
        # PIL HSV: H(0-255), S(0-255), V(0-255)
        hsv_img = img.convert('HSV')
        data = np.array(hsv_img).reshape(-1, 3)
        
        # Filter pixels (ignore very dark shadows and specular highlights)
        filtered = data[(data[:, 2] > 25) & ~((data[:, 2] > 220) & (data[:, 1] < 30))]
        
        if len(filtered) == 0:
            # If all filtered out, check original data for Black/White
            avg_v = np.mean(data[:, 2])
            return "black" if avg_v < 128 else "white"
        
        # KMeans with 3 clusters to separate color from remaining reflections/shadows
        n_clusters = min(3, len(filtered))
        kmeans = KMeans(n_clusters=n_clusters, n_init=5)
        kmeans.fit(filtered)
        
        centers = kmeans.cluster_centers_
        labels = kmeans.labels_
        counts = np.bincount(labels)
        
        # Strategy: Pick the most "vibrant" (saturated) cluster if it's large enough,
        # otherwise pick the largest cluster.
        best_idx = np.argmax(counts)
        max_sat = centers[best_idx][1]
        
        for i in range(len(centers)):
            # If a cluster is reasonably large (> 20% of filtered pixels) and more saturated
            if counts[i] > len(filtered) * 0.2 and centers[i][1] > max_sat:
                max_sat = centers[i][1]
                best_idx = i
                
        h, s, v = centers[best_idx]
        return self.classify_hsv(h, s, v)

    def classify_hsv(self, h, s, v):
        # Normalize to 360, 100, 100
        h_norm = (h / 255.0) * 360
        s_norm = (s / 255.0) * 100
        v_norm = (v / 255.0) * 100
        
        # Achromatic check (Black, White, Gray, Silver)
        if s_norm < 15:
            if v_norm > 90:
                return "white"
            if v_norm < 20:
                return "black"
            if v_norm > 75:
                return "silver"
            if v_norm > 35:
                return "gray"
            return "black"
        
        # Chromatic colors
        if h_norm < 12 or h_norm > 345:
            return "red"
        if h_norm < 30:
            if v_norm < 50:
                return "brown"
            return "orange"
        if h_norm < 65:
            if s_norm < 30 and v_norm > 70:
                return "beige"
            if s_norm < 60 and v_norm < 85:
                return "gold"
            return "yellow"
        if h_norm < 165:
            return "green"
        if h_norm < 265:
            return "blue"
        if h_norm < 300:
            return "purple"
        if h_norm < 345:
            return "pink"
        
        return "gray"

color_detector = ColorDetector()

# Disable Ultralytics online checks
os.environ["ULTRALYTICS_OFFLINE"] = "True"

app = FastAPI(title="SCC YOLO Detection Service")

OBSERVABILITY_ENABLED = os.getenv("OBSERVABILITY_ENABLED", "false").lower() == "true"
REQUESTS = Counter("smart_collection_yolo_http_requests_total", "HTTP requests", ["method", "status"])
DURATION = Histogram("smart_collection_yolo_http_request_duration_seconds", "HTTP request duration", ["method"])
PROCESS_START = Gauge("smart_collection_yolo_process_start_time_seconds", "Process start time")
PROCESS_START.set(time.time())

if OBSERVABILITY_ENABLED:
    provider = TracerProvider(resource=Resource.create({"service.name": os.getenv("OTEL_SERVICE_NAME", "smart-collection-yolo")}))
    provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter(endpoint=os.getenv("OTEL_EXPORTER_OTLP_GRPC_ENDPOINT", "alloy:4317"), insecure=True)))
    trace.set_tracer_provider(provider)

tracer = trace.get_tracer("smart_collection.yolo")


@app.middleware("http")
async def observe_request(request: Request, call_next):
    if request.url.path == "/metrics":
        return await call_next(request)

    started_at = time.monotonic()
    with tracer.start_as_current_span(f"HTTP {request.method}", context=extract(request.headers)) as span:
        span.set_attribute("http.request.method", request.method)
        try:
            response = await call_next(request)
            span.set_attribute("http.response.status_code", response.status_code)
            REQUESTS.labels(request.method, str(response.status_code)).inc()
            return response
        except Exception as error:
            span.record_exception(error)
            REQUESTS.labels(request.method, "500").inc()
            raise
        finally:
            DURATION.labels(request.method).observe(time.monotonic() - started_at)

# Load model (it will download on first run if not present)
MODEL_NAME = os.getenv("YOLO_MODEL", "yolo11s.pt")
model = YOLO(MODEL_NAME)

# Security: API Key
API_KEY = os.getenv("YOLO_API_KEY")

async def verify_api_key(x_api_key: str = Header(None)):
    if API_KEY and x_api_key != API_KEY:
        raise HTTPException(status_code=403, detail="Invalid API Key")
    return x_api_key

@app.get("/health")
async def health():
    return {"status": "ok", "model": MODEL_NAME}


@app.get("/metrics", include_in_schema=False)
async def metrics():
    return PlainTextResponse(generate_latest(), media_type=CONTENT_TYPE_LATEST)

@app.post("/detect", dependencies=[Depends(verify_api_key)])
async def detect(file: UploadFile = File(...)):
    # Read image
    contents = await file.read()
    image = Image.open(io.BytesIO(contents)).convert("RGB")
    
    # Run inference - filtering classes 1 to 8 (bicycle, car, motorcycle, airplane, bus, train, truck, boat)
    results = model.predict(image, conf=0.25, classes=list(range(1, 9)))
    
    detections = []
    for r in results:
        boxes = r.boxes
        for box in boxes:
            # Class info
            cls = int(box.cls[0])
            label = r.names[cls]
            
            # We only care about cars/vehicles for this specific project context
            # But we can return everything and filter in Rails
            
            # Bounding box coordinates (normalized)
            # YOLO results are in [x1, y1, x2, y2]
            # normalized = True gives them in 0-1 range
            xyxyn = box.xyxyn[0].tolist() # [x1, y1, x2, y2] normalized
            
            # Convert to vertices format expected by Rails ImageCropperService
            # {x: x1, y: y1}, {x: x2, y: y1}, {x: x2, y: y2}, {x: x1, y: y2}
            vertices = [
                {"x": xyxyn[0], "y": xyxyn[1]},
                {"x": xyxyn[2], "y": xyxyn[1]},
                {"x": xyxyn[2], "y": xyxyn[3]},
                {"x": xyxyn[0], "y": xyxyn[3]}
            ]
            
            # Color detection
            # Crop image for color classification
            # PIL uses [left, top, right, bottom]
            # xyxyn is [x1, y1, x2, y2] normalized
            w, h = image.size
            crop_box = (xyxyn[0]*w, xyxyn[1]*h, xyxyn[2]*w, xyxyn[3]*h)
            car_crop = image.crop(crop_box)
            color_name = color_detector.detect(car_crop)
            
            detections.append({
                "label": label,
                "score": float(box.conf[0]),
                "vertices": vertices,
                "color": color_name
            })
            
    return {"detections": detections}

@app.post("/classify_color", dependencies=[Depends(verify_api_key)])
async def classify_color(file: UploadFile = File(...)):
    contents = await file.read()
    image = Image.open(io.BytesIO(contents)).convert("RGB")
    color_name = color_detector.detect(image)
    return {"color": color_name}

@app.post("/classify", dependencies=[Depends(verify_api_key)])
async def classify(file: UploadFile = File(...)):
    contents = await file.read()
    image = Image.open(io.BytesIO(contents)).convert("RGB")
    
    # Run inference to get label - restricted to vehicle classes
    results = model.predict(image, conf=0.3, classes=list(range(1, 9))) 
    label = None
    if results and len(results[0].boxes) > 0:
        cls = int(results[0].boxes.cls[0])
        label = results[0].names[cls]
    
    # Detect color
    color_name = color_detector.detect(image)
    
    return {
        "label": label,
        "color": color_name
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
