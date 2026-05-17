import os
import requests
import pandas as pd

# Core base paths
BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DATASETS_DIR = os.path.join(BASE_DIR, "datasets")
os.makedirs(DATASETS_DIR, exist_ok=True)

# 1. Create food_density.csv
DENSITY_CSV = os.path.join(DATASETS_DIR, "food_density.csv")
density_data = """food_name,density_g_cm3
rice,0.85
dal,1.02
paneer,0.95
chicken,0.92
roti,0.45
naan,0.48
biryani,0.82
samosa,0.65
jalebi,1.25
curry,1.05
sweet,1.15
salad,0.35
soup,1.0
milk,1.03
yogurt,1.06
water,1.0
fruit,0.60
dhokla,0.72
dosa,0.50
poha,0.40
upma,0.80
kachori,0.65
idli,0.62
"""

print("Initializing food_density.csv...")
with open(DENSITY_CSV, "w", encoding="utf-8") as f:
    f.write(density_data.strip())
print(f"Created {DENSITY_CSV}")

# 2. Create indian_food_nutrition.csv baseline
INDIAN_CSV = os.path.join(DATASETS_DIR, "indian_food_nutrition.csv")
base_indian_data = """food_name,calories,protein,carbs,fat,description,emoji,standard_portion_grams,portion_unit
Chicken Biryani,190,8.5,22,6.5,Spicy layered chicken rice,🍚,350,1 plate
Paneer Tikka,220,16,6,15,Grilled paneer chunks,🥘,120,6 pieces
Masala Dosa,170,3.5,30,4.5,Thin crepe with potato filling,🌯,150,1 piece
Dal Tadka,110,6,15,3.5,Yellow lentil curry,🍲,200,1 bowl
Butter Chicken,240,15,9,16,Creamy tomato-based chicken,🥘,250,1 bowl
Naan Bread,290,9,52,5,Tandoor baked flatbread,🫓,90,1 piece
Naan,290,9,52,5,Tandoor baked flatbread,🫓,90,1 piece
Palak Paneer,150,11,8,9,Cottage cheese in spinach gravy,🥘,220,1 bowl
Chole Bhature,270,8,42,9.5,Spiced chickpeas with fried bread,🥯,350,1 plate
Samosa,310,5,36,17,Fried pastry with savory filling,🥟,80,1 piece
Gulab Jamun,380,4,68,11,Syrup-soaked milk solids,🍮,40,1 piece
Idli,145,4.5,31,0.5,Steamed rice cakes,⚪,40,1 piece
Alu Paratha,210,5,35,6,Stuffed potato flatbread,🫓,120,1 piece
Tandoori Chicken,160,24,1,7,Spiced roasted chicken,🍗,200,1 piece
Poha,180,3.5,36,3,Flattened rice snack,🍚,180,1 bowl
Rajma Chawal,140,5,25,2.5,Kidney bean curry with rice,🍚,350,1 plate
Vada Pav,280,6,44,10,Potato fritter inside a bun,🍔,170,1 piece
Aloo Gobi,110,3,14,5,Spiced potato and cauliflower,🥘,200,1 bowl
Mutton Rogan Josh,210,18,4,14,Aromatic Kashmiri lamb curry,🥘,250,1 bowl
Pav Bhaji,160,4,22,6.5,Spiced vegetable mash with buttered buns,🥘,350,1 plate
Dhokla,165,7,30,3.5,Steamed savory gram flour cake,🍰,50,1 piece
Bhelpuri,180,4,35,3,Puffed rice street snack,🥗,120,1 bowl
Chole,160,7,23,5,Spiced chickpea curry,🍲,200,1 bowl
Paneer Butter Masala,230,12,10,16,Rich paneer in butter gravy,🥘,220,1 bowl
Dal Makhani,160,6,18,8,Creamy black lentils,🍲,200,1 bowl
Burger,250,13,30,9,Savory burger patty,🍔,200,1 piece
Pepperoni Pizza,270,12,32,10,Classic pizza slice,🍕,100,1 slice
Pasta,220,10,25,12,Spiced tomato pasta,🍝,250,1 bowl
French Fries,312,3.4,41,15,Crispy golden potatoes,🍟,100,1 serving
Salad,190,7,8,15,Fresh mixed vegetable salad,🥗,200,1 bowl
"""

print("Initializing indian_food_nutrition.csv...")
with open(INDIAN_CSV, "w", encoding="utf-8") as f:
    f.write(base_indian_data.strip())
print(f"Created {INDIAN_CSV}")

# 3. Path Rewriting Function
def rewrite_paths(file_path, old_str, new_str):
    if not os.path.exists(file_path):
        return
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()
    if old_str in content:
        content = content.replace(old_str, new_str)
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"Successfully rewritten paths in {file_path}")

# Rewrite all hardcoded srineer paths in dataset-populating python scripts
backend_files = [
    ("expand_indian.py", "c:\\Users\\srineer\\Downloads\\DietitianAI\\datasets\\indian_food_nutrition.csv"),
    ("expand_csv.py", "c:\\Users\\srineer\\Downloads\\DietitianAI\\datasets\\indian_food_nutrition.csv"),
    ("add_micronutrients.py", "c:\\Users\\srineer\\Downloads\\DietitianAI\\datasets\\indian_food_nutrition.csv"),
    ("audit_nutrition.py", "c:\\Users\\srineer\\Downloads\\DietitianAI\\datasets\\indian_food_nutrition.csv"),
    ("add_global_foods.py", "C:\\Users\\srineer\\Downloads\\DietitianAI\\datasets\\indian_food_nutrition.csv"),
    ("expand_database.py", "c:\\Users\\srineer\\Downloads\\DietitianAI\\datasets\\"),
]

for filename, old_path in backend_files:
    full_path = os.path.join(os.path.dirname(__file__), filename)
    relative_replacement = os.path.join(DATASETS_DIR, "indian_food_nutrition.csv").replace("\\", "\\\\")
    if filename == "expand_database.py":
        relative_replacement = DATASETS_DIR.replace("\\", "\\\\") + "\\\\"
    rewrite_paths(full_path, old_path, relative_replacement)

# Also rewrite manage_datasets.py hardcoded paths
manage_script = os.path.join(BASE_DIR, "manage_datasets.py")
if os.path.exists(manage_script):
    rewrite_paths(manage_script, 'target = r"c:\\Users\\srineer\\Downloads\\DietitianAI\\datasets\\ifct_2017_full.csv"', f'target = r"{os.path.join(DATASETS_DIR, "ifct_2017_full.csv")}"')
    rewrite_paths(manage_script, 'fndds_dir = r"c:\\Users\\srineer\\Downloads\\DietitianAI\\backend\\FNDDS"', f'fndds_dir = r"{os.path.join(os.path.dirname(__file__), "FNDDS")}"')

print("All file paths updated to use the active local workspace!")
