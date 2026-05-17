import requests
import os

url_analyze = "http://127.0.0.1:8000/analyze"
url_predict = "http://127.0.0.1:8000/predict"
img_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "datasets", "Nutrition5k_dataset", "imagery", "realsense_overhead", "dish_1558026623", "rgb.png"))

if os.path.exists(img_path):
    print("Testing /analyze:")
    with open(img_path, "rb") as f:
        files = {"file": f}
        try:
            response = requests.post(url_analyze, files=files)
            print(f"Status: {response.status_code}")
            print(f"Result: {response.json()}")
        except Exception as e:
            print(f"Error: {e}")
            
    print("\nTesting /predict:")
    with open(img_path, "rb") as f:
        files = {"file": f}
        try:
            response = requests.post(url_predict, files=files)
            print(f"Status: {response.status_code}")
            print(f"Result: {response.json()}")
        except Exception as e:
            print(f"Error: {e}")
else:
    print(f"File not found: {img_path}")
