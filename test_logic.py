import os
import sys
import pandas as pd
from PIL import Image

# Mocking the folder structure to match backend/services/
def test_path():
    _CSV_PATH = os.path.join(
        os.path.dirname(__file__), "..", "datasets", "indian_food_nutrition.csv"
    )
    print(f"Path computed as: {_CSV_PATH}")
    print(f"File exists? {os.path.exists(_CSV_PATH)}")

if __name__ == "__main__":
    # Simulate being in backend/services/
    # In reality this script is in /tmp, so we need to adjust
    base_dir = os.path.dirname(__file__)
    csv_relative = os.path.join(base_dir, "datasets", "indian_food_nutrition.csv")
    print(f"Actual CSV exists? {os.path.exists(csv_relative)}")
    
    # Check word overlap logic
    label_lower = "biryani"
    csv_name = "Chicken Biryani".lower()
    label_words = set(label_lower.replace("-", " ").replace("_", " ").split())
    csv_words = set(csv_name.replace("-", " ").replace("_", " ").split())
    print(f"Label words: {label_words}")
    print(f"CSV words: {csv_words}")
    print(f"Overlap: {label_words & csv_words}")
