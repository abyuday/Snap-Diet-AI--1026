import os
import sys

# Add backend to path
sys.path.append(os.path.dirname(__file__))
from services.food_analyzer import analyze_food_image

# I'll use a dummy valid image file if possible, or just check the code path
# Let's try to find an image in the temp_uploads if any, or create a tiny black one.
from PIL import Image

dummy_path = 'dummy_test.jpg'
img = Image.new('RGB', (224, 224), color = 'red')
img.save(dummy_path)

try:
    print("Testing analyze_food_image...")
    result = analyze_food_image(dummy_path)
    print("Result:", result)
except Exception as e:
    import traceback
    print("CRASHED!")
    traceback.print_exc()
finally:
    if os.path.exists(dummy_path):
        os.remove(dummy_path)
