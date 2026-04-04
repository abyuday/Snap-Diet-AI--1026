import pandas as pd
import os

csv_path = r'c:\Users\srineer\Downloads\DietitianAI\datasets\indian_food_nutrition.csv'

# The 80 classes supported by the model
model_classes = [
    'adhirasam', 'aloo_gobi', 'aloo_matar', 'aloo_methi', 'aloo_shimla_mirch', 
    'aloo_tikki', 'anarsa', 'ariselu', 'bandar_laddu', 'basundi', 'bhatura', 
    'bhindi_masala', 'biryani', 'boondi', 'butter_chicken', 'chak_hao_kheer', 
    'cham_cham', 'chana_masala', 'chapati', 'chhena_kheeri', 'chicken_razala', 
    'chicken_tikka', 'chicken_tikka_masala', 'chikki', 'daal_baati_churma', 
    'daal_puri', 'dal_makhani', 'dal_tadka', 'dharwad_pedha', 'doodhpak', 
    'double_ka_meetha', 'dum_aloo', 'gajar_ka_halwa', 'gavvalu', 'ghevar', 
    'gulab_jamun', 'imarti', 'jalebi', 'kachori', 'kadai_paneer', 'kadhi_pakoda', 
    'kajjikaya', 'kakinada_khaja', 'kalakand', 'karela_bharta', 'kofta', 
    'kuzhi_paniyaram', 'lassi', 'ledikeni', 'litti_chokha', 'lyangcha', 
    'maach_jhol', 'makki_di_roti_sarson_da_saag', 'malapua', 'misi_roti', 
    'misti_doi', 'modak', 'mysore_pak', 'naan', 'navrattan_korma', 'palak_paneer', 
    'paneer_butter_masala', 'phirni', 'pithe', 'poha', 'poornalu', 'pootharekulu', 
    'qubani_ka_meetha', 'rabri', 'ras_malai', 'rasgulla', 'sandesh', 'shankarpali', 
    'sheer_korma', 'sheera', 'shrikhand', 'sohan_halwa', 'sohan_papdi', 'sutar_feni', 
    'unni_appam'
]

# Quick generic mapping for missing items (Calories, Protein, Carbs, Fat)
# We will use reasonable estimates for standard Indian sweets/curries
generic_nutrition = {
    'sweets': (300, 4, 45, 12, "Traditional Indian sweet"),
    'curry': (250, 8, 20, 15, "Traditional Indian curry"),
    'bread': (150, 4, 30, 2, "Traditional Indian bread/snack"),
    'rice': (200, 4, 40, 4, "Traditional Indian rice dish")
}

def guess_category(name):
    sweets = ['halwa', 'jamun', 'pedha', 'jalebi', 'laddu', 'meetha', 'kheer', 'ras', 'chikki', 'imarti', 'kalakand', 'modak', 'pak', 'payasam']
    breads = ['roti', 'naan', 'chapati', 'bhatura', 'puri', 'paratha', 'kachori', 'tikki', 'samosa', 'poha']
    rice = ['biryani', 'pulao', 'chawal']
    
    if any(s in name for s in sweets): return 'sweets'
    if any(b in name for b in breads): return 'bread'
    if any(r in name for r in rice): return 'rice'
    return 'curry' # default to curry/main dish

# Load existing df
df = pd.read_csv(csv_path)
existing_names = set(df['food_name'].str.lower().str.strip())
existing_names_no_spaces = set(df['food_name'].str.lower().str.replace(' ', '_').str.strip())

new_rows = []
for c in model_classes:
    if c not in existing_names and c not in existing_names_no_spaces:
        # Check if it was partially matched (like 'chicken_biryani' to 'biryani')
        # We will add it anyway with its exact model label to ensure 100% 1-to-1 matching
        
        # Format name nicely
        formatted_name = c.replace('_', ' ').title()
        cat = guess_category(c)
        cals, pro, carb, fat, desc = generic_nutrition[cat]
        
        new_rows.append({
            'food_name': formatted_name,
            'calories': cals,
            'protein': pro,
            'carbs': carb,
            'fat': fat,
            'description': f"{desc} ({formatted_name})",
            'emoji': '🥘' if cat == 'curry' else '🍮' if cat == 'sweets' else '🫓' if cat == 'bread' else '🍚'
        })

if new_rows:
    new_df = pd.DataFrame(new_rows)
    df = pd.concat([df, new_df], ignore_index=True)
    df.to_csv(csv_path, index=False)
    print(f"Added {len(new_rows)} new Indian food items to the CSV!")
else:
    print("All classes already exist in the CSV.")
