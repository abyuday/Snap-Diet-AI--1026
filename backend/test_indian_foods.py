import requests
import os
from tempfile import NamedTemporaryFile
import sys

# Add backend to path to import services
sys.path.append(os.path.dirname(__file__))
from services.food_analyzer import predict_food

# Test images from Wikipedia 
test_cases = [
    ('Samosa', 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c8/Samosa_in_plate.jpg/800px-Samosa_in_plate.jpg'),
    ('Chicken Biryani', 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5a/%22Hyderabadi_Dum_Biryani%22.jpg/800px-%22Hyderabadi_Dum_Biryani%22.jpg'),
    ('Masala Dosa', 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/9f/Dosa_at_Sri_Ganesh_Bhavan.jpg/800px-Dosa_at_Sri_Ganesh_Bhavan.jpg')
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
            print(f"Matched CSV! Calories: {result['nutrition']['calories']}, Protein: {result['nutrition']['protein']}")
        else:
            print('FAILED to match against CSV.')
    except Exception as e:
        print(f'Error: {e}')
    finally:
        os.remove(temp_file.name)
