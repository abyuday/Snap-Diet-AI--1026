import os
import requests
import pandas as pd
from tqdm import tqdm

def download_nutrition5k_subset(limit=1000):
    base_url = "https://storage.googleapis.com/nutrition5k_dataset/nutrition5k_dataset/imagery/realsense_overhead/"
    dish_id_path = "datasets/Nutrition5k_dataset/dish_ids/splits/rgb_train_ids.txt"
    output_dir = "datasets/Nutrition5k_dataset/imagery/realsense_overhead/"
    
    if not os.path.exists(dish_id_path):
        print(f"Error: {dish_id_path} not found. Metadata may still be downloading.")
        return

    # Read dish IDs
    with open(dish_id_path, 'r') as f:
        dish_ids = [line.strip() for line in f.readlines()][:limit]
    
    print(f"Downloading {len(dish_ids)} images for training...")
    
    for dish_id in tqdm(dish_ids):
        img_url = f"{base_url}{dish_id}/rgb.png"
        img_path = os.path.join(output_dir, dish_id, "rgb.png")
        os.makedirs(os.path.dirname(img_path), exist_ok=True)
        
        if os.path.exists(img_path):
            continue
            
        try:
            response = requests.get(img_url, timeout=10)
            if response.status_code == 200:
                with open(img_path, 'wb') as f:
                    f.write(response.content)
            else:
                print(f"Failed to download {dish_id}: Status {response.status_code}")
        except Exception as e:
            print(f"Error downloading {dish_id}: {e}")

if __name__ == "__main__":
    download_nutrition5k_subset(limit=1000)
