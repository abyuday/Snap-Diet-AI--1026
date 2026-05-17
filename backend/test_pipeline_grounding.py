import os
import sys

# Add backend to path
sys.path.append(os.path.dirname(__file__))

from services.food_analyzer import _ground_prediction, _prediction_to_response
from services.rag_service import get_rag_service

print("==================================================")
print("SNAP DIETAI PIPELINE GROUNDING & ENSEMBLE TEST")
print("==================================================")

# Initialize RAG Service
rag = get_rag_service()

# ----------------------------------------------------
# Test 1: Grounded Indian Food (Masala Dosa)
# ----------------------------------------------------
print("\n--- TEST 1: Indian Food Grounding (Masala Dosa) ---")
vlm_result_1 = {
    "food": "Masala Dosa",
    "portion_description": "3 pieces",
    "confidence": 0.95,
    "engine": "Cloud VLM"
}
# Simulate local ViT also predicting 'masala dosa' to test agreement
vit_result_1 = {
    "food": "masala dosa",
    "confidence": 0.91,
    "engine": "Local ViT"
}

grounded_1 = _ground_prediction(vlm_result_1, vit_result_1)
response_1 = _prediction_to_response(grounded_1)

print(f"Prediction: {response_1['food_name']}")
print(f"Portion Description: {response_1['portion_size']}")
print(f"Grounded Weight: {response_1['estimated_weight_grams']}g (Expected: 300.0g)")
print(f"Macros -> Calories: {response_1['calories']} kcal, Protein: {response_1['protein']}g, Carbs: {response_1['carbs']}g, Fat: {response_1['fat']}g")
print(f"Micros -> Calcium: {response_1['calcium_mg']}mg, Iron: {response_1['iron_mg']}mg, Fiber: {response_1['fiber_g']}g")
print(f"Confidence Boosted? {response_1['raw_data']['confidence']} (Expected: >0.95)")
assert 200.0 <= response_1['estimated_weight_grams'] <= 300.0, "Dosa grounding failed!"
assert response_1['calories'] > 0.0, "Dosa calories are zero!"
assert response_1['calcium_mg'] > 0.0 or response_1['iron_mg'] > 0.0, "Dosa micronutrients are missing!"


# ----------------------------------------------------
# Test 2: Global Dish & ViT Bias Bypass (Fruit Salad)
# ----------------------------------------------------
print("\n--- TEST 2: Global Dish & ViT Bias Bypass (Fruit Salad) ---")
vlm_result_2 = {
    "food": "Fruit Salad (Apple, Banana, Orange)",
    "portion_description": "1 bowl",
    "confidence": 0.92,
    "engine": "Cloud VLM"
}
# Simulate local ViT incorrectly guessing 'dhokla' (collapsing to Indian class)
vit_result_2 = {
    "food": "dhokla",
    "confidence": 0.85,
    "engine": "Local ViT"
}

grounded_2 = _ground_prediction(vlm_result_2, vit_result_2)
response_2 = _prediction_to_response(grounded_2)

print(f"Prediction: {response_2['food_name']}")
print(f"Portion: {response_2['portion_size']}")
print(f"Grounded Weight: {response_2['estimated_weight_grams']}g")
print(f"Engine: {response_2['raw_data']['engine']}")
print(f"Confidence: {response_2['raw_data']['confidence']} (Expected: 0.92, should NOT be boosted by incorrect ViT)")
assert "dhokla" not in response_2['raw_data']['engine'].lower(), "ViT over-bias bypass failed!"


# ----------------------------------------------------
# Test 3: VLM Fallback AI Estimate (Egg Salad)
# ----------------------------------------------------
print("\n--- TEST 3: VLM Fallback (Partial Nutrition & Micronutrient Safeguards) ---")
vlm_result_3 = {
    "food": "Extremely Rare Dragon Fruit and Chia Parfait",
    "portion_description": "1 piece",
    "confidence": 0.88,
    "engine": "Cloud VLM",
    "vlm_nutrition": {
        "calories": 250,
        "protein": 12.0,
        "carbs": 20.0,
        "fat": 14.0,
        "fiber_g": 2.5,
        "sodium_mg": 400.0,
        "calcium_mg": 40.0,
        "iron_mg": 1.8
    }
}

grounded_3 = _ground_prediction(vlm_result_3, None)
response_3 = _prediction_to_response(grounded_3)

print(f"Prediction: {response_3['food_name']}")
print(f"Grounded Weight: {response_3['estimated_weight_grams']}g")
print(f"Macros (Kept) -> Calories: {response_3['calories']} kcal, Protein: {response_3['protein']}g, Carbs: {response_3['carbs']}g, Fat: {response_3['fat']}g")
print(f"Micros (Zeroed out to prevent VLM hallucination) -> Calcium: {response_3['calcium_mg']}mg, Iron: {response_3['iron_mg']}mg, Fiber: {response_3['fiber_g']}g")
assert response_3['calories'] > 0.0, "VLM fallback calories failed!"
assert response_3['calcium_mg'] == 0.0 and response_3['iron_mg'] == 0.0 and response_3['fiber_g'] == 0.0, "Micronutrient hallucination safeguard failed!"


# ----------------------------------------------------
# Test 4: Confidence Validation (Low Confidence Case)
# ----------------------------------------------------
print("\n--- TEST 4: Confidence Validation (Low Confidence Case) ---")
vlm_result_4 = {
    "food": "Burger",
    "portion_description": "1 piece",
    "confidence": 0.45,
    "engine": "Cloud VLM",
    "probable_matches": ["Burger", "Sandwich", "Samosa"]
}

grounded_4 = _ground_prediction(vlm_result_4, None)
response_4 = _prediction_to_response(grounded_4)

print(f"Prediction: {response_4['food_name']}")
print(f"Calories: {response_4['calories']} (Expected: 0.0 for unreliable prediction)")
assert "unable to confidently identify food" in response_4['food_name'].lower(), "Low confidence validation failed!"
assert response_4['calories'] == 0.0, "Low confidence nutrition block failed!"

print("\n==================================================")
print("SUCCESS: ALL PIPELINE GROUNDING & SAFEGUARD TESTS PASSED!")
print("==================================================")
