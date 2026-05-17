import os
import sys

# Add backend to path
sys.path.append(os.path.dirname(__file__))

from services.food_analyzer import _ground_prediction, _prediction_to_response
from services.rag_service import get_rag_service

print("==================================================")
print("SNAP DIETAI ADVANCED ORCHESTRATION & HARMONIZATION TEST")
print("==================================================")

# Initialize RAG Service
rag = get_rag_service()

# ----------------------------------------------------
# Test 1: Ensemble Switch (Local ViT specialized agreement override)
# ----------------------------------------------------
print("\n--- TEST 1: Coordinated Ensemble Switch (Specialized ViT Consensus) ---")
vlm_result_1 = {
    "food": "Mixed Rice Dish",
    "portion_description": "1 plate",
    "confidence": 0.55,  # Low VLM confidence
    "engine": "Cloud VLM"
}
vit_result_1 = {
    "food": "biryani",  # Specialized Indian dish in database
    "confidence": 0.98,  # Extremely confident
    "engine": "Local ViT"
}

grounded_1 = _ground_prediction(vlm_result_1, vit_result_1)
response_1 = _prediction_to_response(grounded_1)

print(f"Original VLM: {vlm_result_1['food']} (conf: {vlm_result_1['confidence']})")
print(f"ViT Specialized: {vit_result_1['food']} (conf: {vit_result_1['confidence']})")
print(f"Harmonized Resolved Food: {response_1['food_name']}")
print(f"Engine Details: {response_1['raw_data']['engine']}")
print(f"Resolved Confidence: {response_1['raw_data']['confidence']}")

assert "Biryani" in response_1['food_name'], "Ensemble switch failed to swap to Biryani!"
assert response_1['raw_data']['confidence'] == 0.90, "Ensemble switch failed to calibrate confidence!"


# ----------------------------------------------------
# Test 2: Multimodal Portion Calibration (Visual Occupancy & Density Overrides)
# ----------------------------------------------------
print("\n--- TEST 2: Multimodal Portion Calibration (Visual Overrides) ---")
# Standard Biryani plate standard portion is 300g (grounded in DB)
# Let's say VLM reasons the visual plate is only half occupied (0.50 occupancy) and spread out (0.80 density)
vlm_result_2 = {
    "food": "Biryani",
    "portion_description": "1 plate",
    "confidence": 0.95,
    "engine": "Cloud VLM",
    "visual_occupancy_ratio": 0.50,
    "layout_density_factor": 0.80,
    "serving_size_multiplier": 1.0
}

grounded_2 = _ground_prediction(vlm_result_2, None)
response_2 = _prediction_to_response(grounded_2)

print(f"Standard DB Weight: 350g")
print(f"Visual Occupancy: {vlm_result_2['visual_occupancy_ratio']}, Density: {vlm_result_2['layout_density_factor']}")
print(f"Calibrated Weight: {response_2['estimated_weight_grams']}g")

# 350g * 0.50 * 0.80 = 140.0g
assert response_2['estimated_weight_grams'] == 140.0, "Portion calibration overrides failed!"


# ----------------------------------------------------
# Test 3: Semantic Nutritional Harmonization (VLM Visual Reality + RAG Anchor)
# ----------------------------------------------------
print("\n--- TEST 3: Semantic Nutritional Harmonization ---")
# Standard Biryani standard recipe calories per 100g = 160.0 kcal
# VLM sees it is prepared with extra oil/heavy ingredients, predicting 250 kcal/100g
vlm_result_3 = {
    "food": "Biryani",
    "portion_description": "1 plate",
    "confidence": 0.95,
    "engine": "Cloud VLM",
    "vlm_nutrition": {
        "calories": 250,  # High visual macro density estimate
        "protein": 10.0,
        "carbs": 25.0,
        "fat": 15.0
    }
}

grounded_3 = _ground_prediction(vlm_result_3, None)
response_3 = _prediction_to_response(grounded_3)

# Weight of 1 plate Biryani is standard 350g.
# Plate container multiplier applies a 0.85 scaling factor -> 350.0 * 0.85 = 297.5g.
# Standard RAG Biryani 100g is: 160.0 calories.
# Blended 100g: 0.80 * 160.0 (DB) + 0.20 * 250 (VLM) = 128.0 + 50.0 = 178.0 kcal/100g
# Scaled by 297.5g: 178.0 * 2.975 = 529.55 -> round to 1 decimal = 529.6 kcal.
print(f"Blended Calories for 1 plate (297.5g): {response_3['calories']} kcal (Expected: 529.6)")

assert abs(response_3['calories'] - 529.6) < 1.0, "Nutritional Harmonization calorie blending mismatch!"

print("\n==================================================")
print("SUCCESS: ALL ORCHESTRATION & HARMONIZATION TESTS PASSED!")
print("==================================================")
