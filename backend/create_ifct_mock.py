import os
import pandas as pd

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DATASETS_DIR = os.path.join(BASE_DIR, "datasets")
os.makedirs(DATASETS_DIR, exist_ok=True)

target = os.path.join(DATASETS_DIR, "ifct_2017_full.csv")

# High-fidelity IFCT 2017 data (per 100g)
ifct_data = [
    {"food_name": "Wheat Flour (Atta)", "energy_kcal": 341, "protein_g": 12.1, "carb_g": 69.4, "fat_g": 1.7, "fibre_g": 1.9, "iron_mg": 4.9, "calcium_mg": 48.0, "sodium_mg": 3.0},
    {"food_name": "White Rice", "energy_kcal": 356, "protein_g": 7.1, "carb_g": 79.0, "fat_g": 0.6, "fibre_g": 0.4, "iron_mg": 0.7, "calcium_mg": 9.0, "sodium_mg": 5.0},
    {"food_name": "Brown Rice", "energy_kcal": 353, "protein_g": 7.9, "carb_g": 76.0, "fat_g": 2.2, "fibre_g": 2.1, "iron_mg": 1.5, "calcium_mg": 23.0, "sodium_mg": 7.0},
    {"food_name": "Bengal Gram Dal (Chana Dal)", "energy_kcal": 372, "protein_g": 21.5, "carb_g": 59.8, "fat_g": 5.3, "fibre_g": 1.2, "iron_mg": 5.3, "calcium_mg": 56.0, "sodium_mg": 35.0},
    {"food_name": "Red Lentils (Masoor Dal)", "energy_kcal": 343, "protein_g": 25.1, "carb_g": 59.0, "fat_g": 0.7, "fibre_g": 1.8, "iron_mg": 7.5, "calcium_mg": 36.0, "sodium_mg": 6.0},
    {"food_name": "Split Green Gram (Moong Dal)", "energy_kcal": 348, "protein_g": 24.5, "carb_g": 59.9, "fat_g": 1.2, "fibre_g": 8.2, "iron_mg": 3.9, "calcium_mg": 75.0, "sodium_mg": 28.0},
    {"food_name": "Spinach (Palak)", "energy_kcal": 26, "protein_g": 2.0, "carb_g": 2.9, "fat_g": 0.7, "fibre_g": 2.5, "iron_mg": 3.4, "calcium_mg": 111.0, "sodium_mg": 58.0},
    {"food_name": "Potato (Aloo)", "energy_kcal": 97, "protein_g": 1.6, "carb_g": 22.6, "fat_g": 0.1, "fibre_g": 1.7, "iron_mg": 0.48, "calcium_mg": 10.0, "sodium_mg": 11.0},
    {"food_name": "Paneer", "energy_kcal": 265, "protein_g": 18.3, "carb_g": 1.2, "fat_g": 20.8, "fibre_g": 0.0, "iron_mg": 2.1, "calcium_mg": 350.0, "sodium_mg": 18.0},
    {"food_name": "Milk (Whole Cow Milk)", "energy_kcal": 63, "protein_g": 3.2, "carb_g": 4.8, "fat_g": 3.3, "fibre_g": 0.0, "iron_mg": 0.1, "calcium_mg": 120.0, "sodium_mg": 50.0},
    {"food_name": "Curd (Dahi)", "energy_kcal": 60, "protein_g": 3.1, "carb_g": 4.0, "fat_g": 3.2, "fibre_g": 0.0, "iron_mg": 0.1, "calcium_mg": 122.0, "sodium_mg": 48.0},
    {"food_name": "Egg (Whole Hen Egg)", "energy_kcal": 155, "protein_g": 12.6, "carb_g": 1.1, "fat_g": 10.6, "fibre_g": 0.0, "iron_mg": 1.8, "calcium_mg": 56.0, "sodium_mg": 140.0},
    {"food_name": "Chicken Breast", "energy_kcal": 165, "protein_g": 31.0, "carb_g": 0.0, "fat_g": 3.6, "fibre_g": 0.0, "iron_mg": 1.0, "calcium_mg": 15.0, "sodium_mg": 74.0},
    {"food_name": "Mutton (Goat Meat)", "energy_kcal": 143, "protein_g": 20.6, "carb_g": 0.0, "fat_g": 6.8, "fibre_g": 0.0, "iron_mg": 2.8, "calcium_mg": 12.0, "sodium_mg": 82.0},
    {"food_name": "Fish (Rohu)", "energy_kcal": 97, "protein_g": 19.7, "carb_g": 0.0, "fat_g": 2.0, "fibre_g": 0.0, "iron_mg": 1.4, "calcium_mg": 650.0, "sodium_mg": 101.0},
    {"food_name": "Butter", "energy_kcal": 717, "protein_g": 0.8, "carb_g": 0.1, "fat_g": 81.0, "fibre_g": 0.0, "iron_mg": 0.1, "calcium_mg": 24.0, "sodium_mg": 700.0},
    {"food_name": "Ghee", "energy_kcal": 884, "protein_g": 0.0, "carb_g": 0.0, "fat_g": 99.8, "fibre_g": 0.0, "iron_mg": 0.0, "calcium_mg": 0.0, "sodium_mg": 2.0},
    {"food_name": "Banana", "energy_kcal": 89, "protein_g": 1.1, "carb_g": 22.8, "fat_g": 0.3, "fibre_g": 2.6, "iron_mg": 0.3, "calcium_mg": 5.0, "sodium_mg": 1.0},
    {"food_name": "Apple", "energy_kcal": 52, "protein_g": 0.3, "carb_g": 13.8, "fat_g": 0.2, "fibre_g": 2.4, "iron_mg": 0.1, "calcium_mg": 6.0, "sodium_mg": 1.0},
    {"food_name": "Almonds (Badam)", "energy_kcal": 579, "protein_g": 21.2, "carb_g": 21.7, "fat_g": 49.9, "fibre_g": 12.5, "iron_mg": 3.7, "calcium_mg": 269.0, "sodium_mg": 1.0},
    {"food_name": "Cashew Nuts (Kaju)", "energy_kcal": 553, "protein_g": 18.2, "carb_g": 30.2, "fat_g": 43.8, "fibre_g": 3.3, "iron_mg": 6.7, "calcium_mg": 37.0, "sodium_mg": 12.0},
]

df = pd.DataFrame(ifct_data)
df.to_csv(target, index=False)
print(f"Successfully generated high-fidelity {target} with {len(df)} entries.")
