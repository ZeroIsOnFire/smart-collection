import requests
import os
from dotenv import load_dotenv

load_dotenv()

API_KEY = os.getenv("YOLO_API_KEY")
URL = "http://localhost:8000/detect"

headers = {"X-API-Key": API_KEY}
file_path = "spec/fixtures/files/car_sample.jpg"

with open(file_path, "rb") as f:
    files = {"file": f}
    response = requests.post(URL, headers=headers, files=files)

print(response.status_code)
print(response.json())
