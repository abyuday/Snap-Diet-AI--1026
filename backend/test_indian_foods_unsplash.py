import requests
import os
from tempfile import NamedTemporaryFile
import sys

# Add backend to path to import services
sys.path.append(os.path.dirname(__file__))
from services.food_analyzer import predict_food

# Test images with robust URLs (Unsplash / Flickr / etc)
test_cases = [
    ('Samosa', 'https://images.unsplash.com/photo-1601050690597-df0568f70950?w=800'),
    ('Butter Chicken', 'https://images.unsplash.com/photo-1603894584373-5ac82b2ae398?w=800'),
    ('Biryani', 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=800'),
    ('Paneer Tikka', 'https://images.unsplash.com/photo-1567188040759-bf8dcd0fbfd5?w=800')
]

for name, url in test_cases:
    print(f'\n--- Testing Image: {name} ---')
    temp_file = NamedTemporaryFile(delete=False, suffix='.jpg')
    temp_file.close()
    
    response = requests.get(url, headers={'User-Agent': 'Mozilla/5.0'})
    with open(temp_file.name, 'wb') as f:
        f.write(response.content)
        
    try:
        result = predict_food(temp_file.name)
        print(f"HuggingFace prediction: {result['food']} (confidence: {result['confidence']})")
        if result['nutrition']:
            print(f"Matched CSV! Calories: {result['nutrition']['calories']}, Protein: {result['nutrition']['protein']}, Carbs: {result['nutrition']['carbs']}, Fat: {result['nutrition']['fat']}")
        else:
            print('FAILED to match against CSV.')
    except Exception as e:
        print(f'Error: {e}')
    finally:
        os.remove(temp_file.name)
