FROM ultralytics/ultralytics:latest-cpu

WORKDIR /app

# Install additional requirements
COPY requirements.lock requirements.txt
RUN pip install --no-cache-dir --upgrade -r requirements.txt

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
