import os
import sys

# Add backend to path to import services
sys.path.append(r'c:\Users\srineer\Downloads\DietitianAI\backend')
from services.food_analyzer import predict_food

img_dir = r'c:\Users\srineer\Downloads\DietitianAI\datasets\Nutrition5k_dataset\imagery\realsense_overhead'
dishes = os.listdir(img_dir)[:5]

for dish in dishes:
    img_path = os.path.join(img_dir, dish, 'rgb.png')
    if os.path.exists(img_path):
        print(f'\n--- Testing Image: {dish} ---')
        try:
            result = predict_food(img_path)
            print(f"HuggingFace prediction: {result['food']} (confidence: {result['confidence']})")
            if result['nutrition']:
                print(f"Matched CSV! Calories: {result['nutrition']['calories']}, Protein: {result['nutrition']['protein']}")
            else:
                print('FAILED to match against CSV.')
        except Exception as e:
            print(f'Error: {e}')
