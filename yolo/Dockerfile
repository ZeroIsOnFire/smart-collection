FROM ultralytics/ultralytics:8.4.113-cpu@sha256:584fc79cae5890a81ee8abd91417ec797de0dc43c0261b33b59a721bf070d76b

WORKDIR /app

# OpenCV imported by Ultralytics requires these shared libraries on the CPU image.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgl1 libglib2.0-0 libxcb1 \
    && rm -rf /var/lib/apt/lists/*

# Install additional requirements
COPY requirements.lock requirements.txt
COPY constraints.txt .
RUN python -c "import sys; assert sys.version_info >= (3, 11), 'Pillow 13 requires Python 3.11+'" \
    && python -m pip install --no-cache-dir --upgrade -c constraints.txt pip uv pillow \
    && python -m pip install --no-cache-dir -c constraints.txt torch torchvision --index-url https://download.pytorch.org/whl/cpu \
    && python -m pip install --no-cache-dir --upgrade -r requirements.txt \
    && python -m pip check

# Copy application code
COPY main.py .

# Pre-download the model to avoid runtime connection issues
# Using curl as fallback if python requests fails
RUN curl -L --fail -o yolo11s.pt https://github.com/ultralytics/assets/releases/download/v8.4.0/yolo11s.pt

# Expose port
EXPOSE 8000

# Set environment variables
ENV YOLO_MODEL=yolo11s.pt
ENV PYTHONUNBUFFERED=1
ENV ULTRALYTICS_OFFLINE=True

# Command to run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
