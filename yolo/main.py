import os
import io
from fastapi import FastAPI, File, UploadFile, HTTPException, Header, Depends
from ultralytics import YOLO
from PIL import Image
import numpy as np

app = FastAPI(title="SCC YOLO Detection Service")

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

@app.post("/detect", dependencies=[Depends(verify_api_key)])
async def detect(file: UploadFile = File(...)):
    # Read image
    contents = await file.read()
    image = Image.open(io.BytesIO(contents)).convert("RGB")
    
    # Run inference
    results = model.predict(image, conf=0.25)
    
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
            
            detections.append({
                "label": label,
                "score": float(box.conf[0]),
                "vertices": vertices
            })
            
    return {"detections": detections}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
