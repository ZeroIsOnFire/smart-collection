FROM ultralytics/ultralytics:latest-cpu

WORKDIR /app

# Install additional requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY main.py .

# Expose port
EXPOSE 8000

# Set environment variables
ENV YOLO_MODEL=yolo11s.pt
ENV PYTHONUNBUFFERED=1

# Command to run the application
CMD ["uvicorn", "main.py:app", "--host", "0.0.0.0", "--port", "8000"]
