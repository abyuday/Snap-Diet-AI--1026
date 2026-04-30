import pandas as pd
import os
import csv

def extract_full_nutrition5k():
    metadata_path = r'c:\Users\srineer\Downloads\DietitianAI\datasets\Nutrition5k_dataset\metadata\dish_metadata_cafe1.csv'
    output_path = r'c:\Users\srineer\Downloads\DietitianAI\datasets\global_food_nutrition.csv'
    
    if not os.path.exists(metadata_path):
        print(f"Error: {metadata_path} not found.")
        return

    dish_entries = []

    print("Parsing all 5,000+ dishes from Nutrition5k dataset...")
    with open(metadata_path, 'r') as f:
        reader = csv.reader(f)
        for row in reader:
            # Format: dish_id, total_calories, total_weight, total_fat, total_carbs, total_protein, [ingredients...]
            try:
                dish_id = row[0]
                total_calories = float(row[1])
                total_weight = float(row[2])
                total_fat = float(row[3])
                total_carbs = float(row[4])
                total_protein = float(row[5])

                if total_weight <= 0: continue

                # Extract ingredient names to create a descriptive dish title
                ingr_names = []
                for i in range(6, len(row), 7):
                    if i + 1 < len(row):
                        name = row[i+1].strip().lower()
                        if name and name != 'deprecated':
                            ingr_names.append(name)
                
                # Create a searchable name like "Dish with chicken, rice, broccoli"
                ingredients_str = ", ".join(ingr_names[:5]) # limit to first 5
                searchable_name = f"Meal with {ingredients_str}"
                
                # Scale values to 100g for RAG consistency
                scale = 100.0 / total_weight
                
                dish_entries.append({
                    'food_name': searchable_name,
                    'calories': round(total_calories * scale, 1),
                    'protein': round(total_protein * scale, 2),
                    'carbs': round(total_carbs * scale, 2),
                    'fat': round(total_fat * scale, 2),
                    'description': f"Full dish from Nutrition5k ({dish_id}). Ingredients: {ingredients_str}",
                    'emoji': '🍱',
                    'standard_portion_grams': total_weight,
                    'portion_unit': '1 plate'
                })
            except:
                continue

    print(f"Successfully processed {len(dish_entries)} dishes.")
    
    df = pd.DataFrame(dish_entries)
    df.to_csv(output_path, index=False)
    print(f"Successfully updated {output_path} with full dish data!")

if __name__ == "__main__":
    extract_full_nutrition5k()
