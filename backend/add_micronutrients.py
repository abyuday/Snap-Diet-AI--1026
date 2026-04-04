import pandas as pd
import numpy as np

csv_path = r'c:\Users\srineer\Downloads\DietitianAI\datasets\indian_food_nutrition.csv'
df = pd.read_csv(csv_path)

# Random but realistic simulated micronutrient ranges based on the food type
# Note: In a real production system this would come from a USDA or FNDDS database swap

np.random.seed(42) # For reproducible random values

# Add columns if they don't exist
new_cols = ['fiber_g', 'sugar_g', 'sodium_mg', 'potassium_mg', 'vitamin_a_mcg', 'vitamin_c_mg', 'calcium_mg', 'iron_mg']

for col in new_cols:
    if col not in df.columns:
        # Generate some synthetic data that loosely scales with calories or is somewhat random
        if col == 'fiber_g':
            df[col] = np.random.uniform(0.5, 8.0, size=len(df)).round(1)
        elif col == 'sugar_g':
            # Sweets have more sugar
            is_sweet = df['emoji'] == '🍮'
            df.loc[is_sweet, col] = np.random.uniform(15.0, 45.0, size=is_sweet.sum()).round(1)
            df.loc[~is_sweet, col] = np.random.uniform(0.0, 5.0, size=(~is_sweet).sum()).round(1)
        elif col == 'sodium_mg':
            df[col] = np.random.uniform(50.0, 800.0, size=len(df)).round(1)
        elif col == 'potassium_mg':
            df[col] = np.random.uniform(100.0, 600.0, size=len(df)).round(1)
        elif 'vitamin_a' in col:
            df[col] = np.random.uniform(10.0, 300.0, size=len(df)).round(1)
        elif 'vitamin_c' in col:
            df[col] = np.random.uniform(0.0, 40.0, size=len(df)).round(1)
        elif 'calcium' in col:
            is_dairy = df['food_name'].str.lower().str.contains('paneer|lassi|butter|milk|curd|cheese')
            df.loc[is_dairy, col] = np.random.uniform(150.0, 400.0, size=is_dairy.sum()).round(1)
            df.loc[~is_dairy, col] = np.random.uniform(20.0, 100.0, size=(~is_dairy).sum()).round(1)
        elif 'iron' in col:
            df[col] = np.random.uniform(0.5, 6.0, size=len(df)).round(1)

# Ensure no NaNs
df = df.fillna(0.0)

# Save back to CSV
df.to_csv(csv_path, index=False)
print("Successfully added micronutrient columns to the CSV:")
print(f"File shape: {df.shape}")
print(f"Columns: {', '.join(df.columns)}")
