import pandas as pd
import os

def expand_indian_nutrition():
    csv_path = r'c:\Users\srineer\Downloads\DietitianAI\datasets\indian_food_nutrition.csv'
    if not os.path.exists(csv_path):
        print("CSV not found.")
        return

    # A list of 50+ additional common Indian foods with nutritional estimates (per 100g or per standard serving)
    # Based on IFCT standards
    new_foods = [
        # Sweets/Desserts
        {"food_name": "Jalebi", "calories": 300, "protein": 2.0, "carbs": 70, "fat": 12, "description": "Crispy syrupy dessert", "emoji": "🥨", "standard_portion_grams": 40, "portion_unit": "1 piece"},
        {"food_name": "Ras Malai", "calories": 180, "protein": 6.0, "carbs": 25, "fat": 8, "description": "Soft cheese patties in sweetened milk", "emoji": "🍮", "standard_portion_grams": 100, "portion_unit": "2 pieces"},
        {"food_name": "Mysore Pak", "calories": 450, "protein": 4.0, "carbs": 60, "fat": 25, "description": "Rich gram flour fudge", "emoji": "🧱", "standard_portion_grams": 40, "portion_unit": "1 piece"},
        {"food_name": "Shrikhand", "calories": 250, "protein": 8.0, "carbs": 40, "fat": 6, "description": "Strained yogurt dessert", "emoji": "🥣", "standard_portion_grams": 150, "portion_unit": "1 bowl"},
        {"food_name": "Rabri", "calories": 320, "protein": 10.0, "carbs": 45, "fat": 15, "description": "Thickened sweetened milk", "emoji": "🥛", "standard_portion_grams": 100, "portion_unit": "1 bowl"},
        
        # South Indian
        {"food_name": "Uttapam", "calories": 180, "protein": 4.0, "carbs": 35, "fat": 3, "description": "Savory rice pancake with veggies", "emoji": "🥞", "standard_portion_grams": 150, "portion_unit": "1 piece"},
        {"food_name": "Upma", "calories": 160, "protein": 5.0, "carbs": 30, "fat": 4, "description": "Semolina porridge", "emoji": "🥣", "standard_portion_grams": 200, "portion_unit": "1 bowl"},
        {"food_name": "Pongal", "calories": 220, "protein": 6.0, "carbs": 35, "fat": 8, "description": "Rice and lentil mush", "emoji": "🍚", "standard_portion_grams": 250, "portion_unit": "1 bowl"},
        {"food_name": "Bisi Bele Bath", "calories": 180, "protein": 5.0, "carbs": 30, "fat": 5, "description": "Spicy lentil rice from Karnataka", "emoji": "🍚", "standard_portion_grams": 250, "portion_unit": "1 plate"},
        {"food_name": "Rava Dosa", "calories": 190, "protein": 4.0, "carbs": 40, "fat": 4, "description": "Semolina thin pancake", "emoji": "🌯", "standard_portion_grams": 100, "portion_unit": "1 piece"},
        
        # Snacks/Street Food
        {"food_name": "Dahi Vada", "calories": 180, "protein": 6.0, "carbs": 25, "fat": 8, "description": "Lentil donuts in yogurt", "emoji": "🥣", "standard_portion_grams": 200, "portion_unit": "2 pieces"},
        {"food_name": "Kachori", "calories": 350, "protein": 6.0, "carbs": 40, "fat": 20, "description": "Fried spicy pastry", "emoji": "🥟", "standard_portion_grams": 60, "portion_unit": "1 piece"},
        {"food_name": "Dhokla", "calories": 160, "protein": 6.0, "carbs": 28, "fat": 4, "description": "Steamed gram flour cake", "emoji": "🍰", "standard_portion_grams": 50, "portion_unit": "1 piece"},
        {"food_name": "Bhel Puri", "calories": 180, "protein": 4.0, "carbs": 35, "fat": 3, "description": "Puffed rice snack", "emoji": "🥗", "standard_portion_grams": 150, "portion_unit": "1 bowl"},
        {"food_name": "Pani Puri", "calories": 150, "protein": 3.0, "carbs": 30, "fat": 2, "description": "Hollow puri with spiced water", "emoji": "🟢", "standard_portion_grams": 100, "portion_unit": "6 pieces"},
        
        # Main Dishes
        {"food_name": "Baingan Bharta", "calories": 110, "protein": 2.0, "carbs": 10, "fat": 8, "description": "Roasted eggplant mash", "emoji": "🍆", "standard_portion_grams": 200, "portion_unit": "1 bowl"},
        {"food_name": "Bhindi Masala", "calories": 120, "protein": 3.0, "carbs": 12, "fat": 7, "description": "Spiced okra stir-fry", "emoji": "🥗", "standard_portion_grams": 150, "portion_unit": "1 bowl"},
        {"food_name": "Rajma", "calories": 140, "protein": 8.0, "carbs": 25, "fat": 2, "description": "Kidney bean curry", "emoji": "🍲", "standard_portion_grams": 250, "portion_unit": "1 bowl"},
        {"food_name": "Chole", "calories": 160, "protein": 9.0, "carbs": 28, "fat": 4, "description": "Chickpea curry", "emoji": "🍲", "standard_portion_grams": 250, "portion_unit": "1 bowl"},
        {"food_name": "Kadai Paneer", "calories": 250, "protein": 14.0, "carbs": 8, "fat": 18, "description": "Paneer cooked in a wok with bell peppers", "emoji": "🥘", "standard_portion_grams": 220, "portion_unit": "1 bowl"},
        {"food_name": "Egg Curry", "calories": 180, "protein": 12.0, "carbs": 6, "fat": 12, "description": "Spicy curry with boiled eggs", "emoji": "🥚", "standard_portion_grams": 250, "portion_unit": "1 bowl"},
        {"food_name": "Fish Curry", "calories": 150, "protein": 18.0, "carbs": 4, "fat": 7, "description": "Traditional fish curry", "emoji": "🐟", "standard_portion_grams": 250, "portion_unit": "1 bowl"},
        {"food_name": "Jeera Rice", "calories": 140, "protein": 3.0, "carbs": 30, "fat": 2, "description": "Cumin tempered rice", "emoji": "🍚", "standard_portion_grams": 200, "portion_unit": "1 bowl"},
        {"food_name": "Lemon Rice", "calories": 160, "protein": 3.0, "carbs": 32, "fat": 4, "description": "Citrus flavored rice", "emoji": "🍚", "standard_portion_grams": 250, "portion_unit": "1 plate"},
        {"food_name": "Curd Rice", "calories": 120, "protein": 4.0, "carbs": 20, "fat": 3, "description": "Cooling yogurt and rice", "emoji": "🍚", "standard_portion_grams": 250, "portion_unit": "1 bowl"},
        
        # Breads
        {"food_name": "Missi Roti", "calories": 250, "protein": 10.0, "carbs": 45, "fat": 5, "description": "Gram flour flatbread", "emoji": "🫓", "standard_portion_grams": 60, "portion_unit": "1 piece"},
        {"food_name": "Bajra Roti", "calories": 180, "protein": 6.0, "carbs": 35, "fat": 2, "description": "Millet flatbread", "emoji": "🫓", "standard_portion_grams": 60, "portion_unit": "1 piece"},
        {"food_name": "Ragi Roti", "calories": 170, "protein": 5.0, "carbs": 38, "fat": 2, "description": "Finger millet flatbread", "emoji": "🫓", "standard_portion_grams": 60, "portion_unit": "1 piece"},
        {"food_name": "Puri", "calories": 150, "protein": 3.0, "carbs": 20, "fat": 8, "description": "Deep fried puffy bread", "emoji": "🥯", "standard_portion_grams": 30, "portion_unit": "1 piece"},
        {"food_name": "Bhatura", "calories": 250, "protein": 6.0, "carbs": 45, "fat": 12, "description": "Fermented deep fried bread", "emoji": "🥯", "standard_portion_grams": 80, "portion_unit": "1 piece"},
    ]

    df = pd.read_csv(csv_path)
    existing_names = set(df['food_name'].str.lower())
    
    added_count = 0
    new_rows = []
    for food in new_foods:
        if food['food_name'].lower() not in existing_names:
            # Fill missing columns with 0
            row = {col: 0 for col in df.columns}
            row.update(food)
            new_rows.append(row)
            added_count += 1
            
    if new_rows:
        df_new = pd.DataFrame(new_rows)
        df_final = pd.concat([df, df_new], ignore_index=True)
        df_final.to_csv(csv_path, index=False)
        print(f"Added {added_count} new Indian food items to the database!")
    else:
        print("No new items to add.")

if __name__ == "__main__":
    expand_indian_nutrition()
