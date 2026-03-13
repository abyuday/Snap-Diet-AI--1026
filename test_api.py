import requests
import os

url = "http://127.0.0.1:8000/analyze"
img_path = r"c:\Users\srineer\Downloads\DietitianAI\datasets\Nutrition5k_dataset\imagery\realsense_overhead\dish_1550705580\rgb.png"

if os.path.exists(img_path):
    with open(img_path, "rb") as f:
        files = {"file": f}
        try:
            response = requests.post(url, files=files)
            print(f"Status: {response.status_code}")
            print(f"Result: {response.json()}")
        except Exception as e:
            print(f"Error: {e}")
else:
    print(f"File not found: {img_path}")
