import csv
import os

CSV_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "datasets", "indian_food_nutrition.csv"))

# food_name,calories,protein,carbs,fat,description,emoji,fiber_g,sugar_g,sodium_mg,potassium_mg,vitamin_a_mcg,vitamin_c_mg,calcium_mg,iron_mg,standard_portion_grams,portion_unit
global_foods = [
    ["Apple", 52, 0.3, 13.8, 0.2, "Crisp and sweet fruit", "🍎", 2.4, 10.4, 1.0, 107.0, 3.0, 4.6, 6.0, 0.1, 150, "1 medium"],
    ["Watermelon", 30, 0.6, 7.6, 0.2, "Refreshing summary fruit", "🍉", 0.4, 6.2, 1.0, 112.0, 28.0, 8.1, 7.0, 0.2, 200, "1 cup"],
    ["Banana", 89, 1.1, 22.8, 0.3, "Potassium rich fruit", "🍌", 2.6, 12.2, 1.0, 358.0, 3.0, 8.7, 5.0, 0.3, 118, "1 medium"],
    ["Orange", 47, 0.9, 11.8, 0.1, "Citrus fruit packed with Vitamin C", "🍊", 2.4, 9.4, 0.0, 181.0, 11.0, 53.2, 40.0, 0.1, 131, "1 medium"],
    ["Strawberry", 32, 0.7, 7.7, 0.3, "Sweet red berries", "🍓", 2.0, 4.9, 1.0, 153.0, 1.0, 58.8, 16.0, 0.4, 144, "1 cup"],
    ["Grapes", 69, 0.7, 18.1, 0.2, "Sweet bite-sized fruit", "🍇", 0.9, 15.5, 2.0, 191.0, 3.0, 3.2, 10.0, 0.4, 151, "1 cup"],
    ["Avocado", 160, 2.0, 8.5, 14.7, "Creamy fruit rich in healthy fats", "🥑", 6.7, 0.7, 7.0, 485.0, 7.0, 10.0, 12.0, 0.5, 150, "1 half"],
    ["Cucumber", 15, 0.6, 3.6, 0.1, "Hydrating crisp vegetable", "🥒", 0.5, 1.7, 2.0, 147.0, 5.0, 2.8, 16.0, 0.3, 104, "1/2 cup"],
    ["Tomato", 18, 0.9, 3.9, 0.2, "Versatile red fruit used as vegetable", "🍅", 1.2, 2.6, 5.0, 237.0, 42.0, 13.7, 10.0, 0.3, 123, "1 medium"],
    ["Carrot", 41, 0.9, 9.6, 0.2, "Crunchy orange root vegetable", "🥕", 2.8, 4.7, 69.0, 320.0, 835.0, 5.9, 33.0, 0.3, 61, "1 medium"],
    ["Broccoli", 34, 2.8, 6.6, 0.4, "Green cruciferous vegetable", "🥦", 2.6, 1.7, 33.0, 316.0, 31.0, 89.2, 47.0, 0.7, 91, "1 cup"],
    ["Spinach", 23, 2.9, 3.6, 0.4, "Leafy green vegetable", "🥬", 2.2, 0.4, 79.0, 558.0, 469.0, 28.1, 99.0, 2.7, 30, "1 cup"],
    ["Potato", 77, 2.0, 17.5, 0.1, "Starchy root vegetable", "🥔", 2.2, 0.8, 6.0, 421.0, 0.0, 19.7, 12.0, 0.8, 150, "1 medium"],
    ["Milk (Whole)", 61, 3.1, 4.8, 3.3, "Whole dairy milk", "🥛", 0.0, 5.0, 43.0, 150.0, 46.0, 0.0, 113.0, 0.0, 240, "1 cup"],
    ["Milk (Slim)", 34, 3.4, 5.0, 0.1, "Skimmed dairy milk", "🥛", 0.0, 5.1, 44.0, 156.0, 0.0, 0.0, 122.0, 0.0, 240, "1 cup"],
    ["Cheddar Cheese", 402, 25.0, 1.3, 33.1, "Aged hard cheese", "🧀", 0.0, 0.5, 621.0, 98.0, 330.0, 0.0, 721.0, 0.7, 28, "1 slice"],
    ["Yogurt", 59, 10.0, 3.6, 0.4, "Plain Greek Yogurt", "🥣", 0.0, 3.2, 36.0, 141.0, 0.0, 0.0, 110.0, 0.0, 150, "1 cup"],
    ["Egg", 155, 12.6, 1.1, 10.6, "Whole boiled egg", "🥚", 0.0, 1.1, 124.0, 126.0, 149.0, 0.0, 50.0, 1.2, 50, "1 piece"],
    ["Chicken Breast", 165, 31.0, 0.0, 3.6, "Roasted chicken breast", "🍗", 0.0, 0.0, 74.0, 256.0, 0.0, 0.0, 15.0, 1.0, 150, "1 piece"],
    ["Beef Steak", 250, 26.0, 0.0, 15.0, "Grilled beef steak", "🥩", 0.0, 0.0, 54.0, 318.0, 0.0, 0.0, 18.0, 2.6, 170, "1 piece"],
    ["Salmon", 208, 20.0, 0.0, 13.0, "Cooked salmon fish", "🐟", 0.0, 0.0, 59.0, 363.0, 14.0, 0.0, 9.0, 0.3, 100, "1 piece"],
    ["Rice (White)", 130, 2.7, 28.2, 0.3, "Cooked white rice", "🍚", 0.4, 0.1, 1.0, 35.0, 0.0, 0.0, 10.0, 1.2, 150, "1 bowl"],
    ["Rice (Brown)", 111, 2.6, 23.0, 0.9, "Cooked brown rice", "🍚", 1.8, 0.4, 5.0, 43.0, 0.0, 0.0, 10.0, 0.4, 150, "1 bowl"],
    ["Pasta", 131, 5.0, 25.0, 1.1, "Cooked spaghetti or pasta", "🍝", 1.2, 0.4, 1.0, 24.0, 0.0, 0.0, 6.0, 1.0, 140, "1 cup"],
    ["Bread (White)", 265, 9.0, 49.0, 3.2, "Sliced white bread", "🍞", 2.7, 5.0, 491.0, 115.0, 0.0, 0.0, 260.0, 3.6, 35, "1 slice"],
    ["Bread (Whole Wheat)", 252, 12.4, 43.0, 3.5, "Sliced whole wheat bread", "🍞", 6.0, 4.3, 400.0, 254.0, 0.0, 0.0, 161.0, 2.5, 35, "1 slice"],
    ["Pizza", 266, 11.4, 33.3, 9.7, "Standard cheese pizza", "🍕", 2.3, 3.6, 598.0, 172.0, 107.0, 1.4, 188.0, 2.5, 107, "1 slice"],
    ["Burger", 295, 17.0, 24.0, 14.0, "Classic beef hamburger", "🍔", 1.1, 5.0, 414.0, 206.0, 6.0, 0.5, 51.0, 2.8, 150, "1 piece"],
    ["Chocolate", 546, 4.9, 61.2, 31.3, "Milk chocolate bar", "🍫", 3.4, 51.5, 79.0, 372.0, 49.0, 0.0, 189.0, 2.4, 45, "1 bar"],
    ["Peanut Butter", 588, 25.0, 20.0, 50.0, "Smooth peanut butter", "🥜", 6.0, 9.0, 17.0, 649.0, 0.0, 0.0, 43.0, 1.9, 32, "2 tbsp"],
    ["Honey", 304, 0.3, 82.4, 0.0, "Natural sweet honey", "🍯", 0.0, 82.1, 4.0, 52.0, 0.0, 0.5, 6.0, 0.4, 21, "1 tbsp"],
    ["Ice Cream", 207, 3.5, 23.6, 11.0, "Vanilla ice cream", "🍦", 0.7, 21.2, 80.0, 199.0, 119.0, 0.6, 128.0, 0.1, 100, "1 scoop"],
    ["Almonds", 579, 21.1, 21.6, 49.9, "Raw unroasted almonds", "🥜", 12.5, 4.4, 1.0, 733.0, 0.0, 0.0, 269.0, 3.7, 30, "1 handful"],
    ["Walnuts", 654, 15.2, 13.7, 65.2, "Raw shelled walnuts", "🥜", 6.7, 2.6, 2.0, 441.0, 1.0, 1.3, 98.0, 2.9, 30, "1 handful"],
    ["Olive Oil", 884, 0.0, 0.0, 100.0, "Extra virgin olive oil", "🫒", 0.0, 0.0, 2.0, 1.0, 0.0, 0.0, 1.0, 0.6, 15, "1 tbsp"],
    ["Butter", 717, 0.8, 0.1, 81.1, "Dairy butter", "🧈", 0.0, 0.1, 11.0, 24.0, 684.0, 0.0, 24.0, 0.0, 14, "1 tbsp"],
    ["Maggie Noodles", 420, 8.0, 60.0, 15.0, "Instant packaged noodles", "🍜", 2.0, 2.5, 1200.0, 150.0, 5.0, 0.0, 40.0, 3.0, 70, "1 packet"],
    ["Oats", 389, 16.9, 66.3, 6.9, "Rolled plain oats", "🥣", 10.6, 0.0, 2.0, 429.0, 0.0, 0.0, 54.0, 4.7, 40, "1/2 cup"],
    ["Cornflakes", 357, 7.5, 84.0, 0.4, "Flaked corn cereal", "🥣", 1.2, 10.0, 729.0, 112.0, 815.0, 60.0, 4.0, 28.9, 30, "1 bowl"],
]

existing_foods = set()
with open(CSV_PATH, 'r', encoding='utf-8') as f:
    reader = csv.reader(f)
    next(reader)
    for row in reader:
        existing_foods.add(row[0].strip().lower())

added = 0
with open(CSV_PATH, 'a', encoding='utf-8', newline='') as f:
    writer = csv.writer(f)
    for item in global_foods:
        if item[0].lower() not in existing_foods:
            writer.writerow(item)
            added += 1

print(f"Added {added} global foods to the CSV database!")
