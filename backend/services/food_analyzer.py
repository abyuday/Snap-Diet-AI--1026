"""
Food Analyzer — DietAI24-Enhanced Pipeline

Implements a three-stage analysis based on the DietAI24 methodology:
  Stage 1: VLM identifies food + portion description (not weight guessing)
  Stage 2: RAG retrieves matching food from FNDDS/Indian database
  Stage 3: Portion-weight grounding converts portion description to grams

Additional enhancements:
  - ViT ensemble classifier (therealcyberlord/vit-indian-food) for cross-validation
  - Scaled nutrition: values proportional to actual portion size
"""

import os
import json
import re
import base64
from typing import Dict, Any, Optional, List

from openai import OpenAI

# ---------------------------------------------------------------------------
# Global AI Config
# ---------------------------------------------------------------------------

_HF_TOKEN = os.getenv("HF_TOKEN")
_OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
_AI_BASE_URL = os.getenv("AI_BASE_URL", "https://router.huggingface.co/v1")
_AI_MODEL = os.getenv("AI_MODEL", "Qwen/Qwen2.5-VL-72B-Instruct")

_client: Optional[OpenAI] = None
if _HF_TOKEN or _OPENAI_API_KEY:
    try:
        _client = OpenAI(api_key=_HF_TOKEN or _OPENAI_API_KEY, base_url=_AI_BASE_URL)
        print(f"INFO: Cloud VLM Client initialized with model {_AI_MODEL}", flush=True)
    except Exception as e:
        print(f"WARNING: Failed to init Cloud VLM client: {e}", flush=True)


# ---------------------------------------------------------------------------
# Local ViT model fallback (upgraded: therealcyberlord/vit-indian-food)
# ---------------------------------------------------------------------------

_classifier = None

_VIT_MODEL_ID = os.getenv(
    "LOCAL_VIT_MODEL",
    "therealcyberlord/vit-indian-food"   # 96.67% accuracy on Indian food
)
_VIT_FALLBACK_MODEL_ID = "dima806/indian_food_image_detection"  # 20-class fallback


def get_local_classifier():
    """Lazily load the local ViT classifier. Tries the upgraded model first."""
    global _classifier
    if _classifier is not None:
        return _classifier

    if os.getenv("USE_LOCAL_MODEL", "false").lower() != "true":
        print("INFO: Local model skip (USE_LOCAL_MODEL=false). Returning UNAVAILABLE.", flush=True)
        _classifier = "UNAVAILABLE"
        return _classifier

    for model_id in [_VIT_MODEL_ID, _VIT_FALLBACK_MODEL_ID]:
        try:
            from transformers import pipeline
            print(f"INFO: Loading local ViT model ({model_id})…", flush=True)
            _classifier = pipeline("image-classification", model=model_id)
            print(f"INFO: Local model loaded: {model_id}", flush=True)
            return _classifier
        except Exception as e:
            print(f"WARNING: Failed to load {model_id}: {e}", flush=True)

    print("WARNING: All local models failed. Using UNAVAILABLE fallback.", flush=True)
    _classifier = "UNAVAILABLE"
    return _classifier


# ---------------------------------------------------------------------------
# CSV nutrition lookup (still used as a fast fallback)
# ---------------------------------------------------------------------------

import difflib

_nutrition_df = None


def get_nutrition_df():
    global _nutrition_df
    if _nutrition_df is not None:
        return _nutrition_df

    _BASE_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    _CSV_PATH = os.path.join(_BASE_PATH, "datasets", "indian_food_nutrition.csv")
    if not os.path.exists(_CSV_PATH):
        _CSV_PATH = "/app/datasets/indian_food_nutrition.csv"

    if os.path.exists(_CSV_PATH):
        try:
            import pandas as pd
            _nutrition_df = pd.read_csv(_CSV_PATH)
            _nutrition_df.columns = [c.strip().lower() for c in _nutrition_df.columns]
            print(f"INFO: Loaded nutrition CSV from {_CSV_PATH} with {len(_nutrition_df)} entries.", flush=True)
        except Exception as e:
            print(f"ERROR: Failed to read CSV at {_CSV_PATH}: {e}", flush=True)
    else:
        print(f"WARNING: Nutrition CSV not found at: {_CSV_PATH}", flush=True)
    return _nutrition_df


def lookup_nutrition(food_label: str) -> Optional[Dict[str, float]]:
    """
    Look up nutrition info for *food_label* in the CSV.
    Now also returns portion metadata for DietAI24 grounding.
    """
    df = get_nutrition_df()
    if df is None or df.empty:
        return None

    label_lower = food_label.lower().strip()
    food_names = df["food_name"].tolist()
    food_names_lower = [f.lower().strip() for f in food_names]

    # 1. Exact match
    if label_lower in food_names_lower:
        idx = food_names_lower.index(label_lower)
        return _row_to_dict(df.iloc[idx])

    # 2. Fuzzy match
    matches = difflib.get_close_matches(label_lower, food_names_lower, n=1, cutoff=0.7)
    if matches:
        idx = food_names_lower.index(matches[0])
        print(f"INFO: Fuzzy match: '{food_label}' -> '{food_names[idx]}'", flush=True)
        return _row_to_dict(df.iloc[idx])

    # 3. Word-level overlap
    label_words = set(label_lower.replace("-", " ").replace("_", " ").split())
    for _, row in df.iterrows():
        csv_name = str(row["food_name"]).lower().strip()
        csv_words = set(csv_name.replace("-", " ").replace("_", " ").split())
        if label_words & csv_words:
            return _row_to_dict(row)

    return None


def _row_to_dict(row) -> Dict[str, float]:
    """Extract nutrition numbers from a CSV row, including portion data."""
    return {
        "calories": float(row.get("calories", 0) or 0),
        "protein": float(row.get("protein", 0) or 0),
        "carbs": float(row.get("carbs", 0) or 0),
        "fat": float(row.get("fat", 0) or 0),
        "fiber_g": float(row.get("fiber_g", 0) or 0),
        "sugar_g": float(row.get("sugar_g", 0) or 0),
        "sodium_mg": float(row.get("sodium_mg", 0) or 0),
        "potassium_mg": float(row.get("potassium_mg", 0) or 0),
        "vitamin_a_mcg": float(row.get("vitamin_a_mcg", 0) or 0),
        "vitamin_c_mg": float(row.get("vitamin_c_mg", 0) or 0),
        "calcium_mg": float(row.get("calcium_mg", 0) or 0),
        "iron_mg": float(row.get("iron_mg", 0) or 0),
        "standard_portion_grams": float(row.get("standard_portion_grams", 0) or 0),
        "portion_unit": str(row.get("portion_unit", "1 serving")),
    }


# ---------------------------------------------------------------------------
# Helper: parse structured JSON from VLM response
# ---------------------------------------------------------------------------

def _parse_vlm_json(raw_text: str) -> Optional[Dict[str, Any]]:
    """Try to extract a JSON object from the VLM response text."""
    text = raw_text.strip()
    md_match = re.search(r'```(?:json)?\s*({.*?})\s*```', text, re.DOTALL)
    if md_match:
        text = md_match.group(1)
    else:
        json_match = re.search(r'\{[^{}]*\}', text, re.DOTALL)
        if json_match:
            text = json_match.group(0)
    try:
        return json.loads(text)
    except (json.JSONDecodeError, ValueError):
        return None


# ---------------------------------------------------------------------------
# DietAI24-Enhanced VLM Prompts
# ---------------------------------------------------------------------------
# Key difference from before: We ask the VLM to describe the portion using
# standard food-service descriptors (pieces, bowls, cups, plates) instead of
# guessing weight in grams. The gram conversion happens via RAG lookup.

_SINGLE_IMAGE_PROMPT = """You are a food analysis expert performing dietary assessment.

Analyze this food image and identify the dish. Describe the portion using STANDARD portion descriptors.

IMPORTANT: Do NOT guess the weight in grams. Instead, describe the portion using countable units:
- For discrete items (idli, samosa, roti): count the pieces (e.g., "3 pieces")
- For served dishes (biryani, curry): use serving containers (e.g., "1 plate", "1 bowl")
- For drinks: use glass/cup (e.g., "1 glass")

Return ONLY a JSON object in this exact format (no extra text):
{"food": "<dish name>", "portion_description": "<e.g. 3 pieces, 1 bowl, 1 plate>", "confidence_note": "<brief reason for identification>"}

Examples:
{"food": "Idli", "portion_description": "3 pieces", "confidence_note": "Round white steamed rice cakes visible"}
{"food": "Chicken Biryani", "portion_description": "1 plate", "confidence_note": "Yellow rice with chicken pieces and garnish"}
{"food": "Masala Dosa", "portion_description": "1 piece", "confidence_note": "Golden crispy crepe folded with filling"}"""


_MULTI_IMAGE_PROMPT = """You are a food analysis expert. You have multiple images of the SAME dish from different angles.

Analyze ALL images together. The multiple angles help you:
- Confirm the dish identity (see toppings, fillings, color from different sides)
- Count items more accurately (see items that may be hidden in one view)
- Judge portion size better (thickness, spread, depth visible from side angles)

IMPORTANT: Do NOT guess the weight in grams. Instead, describe the portion using standard descriptors:
- For discrete items: count pieces (e.g., "4 pieces")
- For served dishes: use containers (e.g., "1 large bowl", "1 plate")
- For drinks: use glass/cup (e.g., "1 tall glass")

Return ONLY a JSON object in this exact format (no extra text):
{"food": "<dish name>", "portion_description": "<e.g. 3 pieces, 1 bowl, 1 plate>", "confidence_note": "<brief reason using multi-angle info>"}"""

_TEXT_LOG_PROMPT = """You are a food analysis expert. The user has provided a text description of what they ate.

Extract the EXACT food identity and standardize the portion description.

IMPORTANT: Do NOT guess the weight in grams. Instead, use standard portion counts as provided in the text.
- If the user says "2 plates of chicken biryani", output food: "Chicken Biryani", portion_description: "2 plates"
- If they say "3 idlis", output food: "Idli", portion_description: "3 pieces"
- If the user provides an exact weight amount (e.g., "500 grams of salmon"), output portion_description: "500 grams" 

Return ONLY a JSON object in this exact format (no extra text):
{"food": "<standardized dish name>", "portion_description": "<parsed portion unit or grams>", "confidence_note": "Parsed from text log"}"""

# ---------------------------------------------------------------------------

# Core prediction — DietAI24 pipeline
# ---------------------------------------------------------------------------

def predict_food(image_path: str) -> Dict[str, Any]:
    """
    DietAI24-enhanced prediction pipeline:
      1. VLM identifies food + portion description (NOT weight)
      2. RAG grounds the food name to database entry
      3. Portion-weight calculator converts description to grams
      4. Nutrition is scaled proportionally to actual portion
    """
    # Ensemble: run ViT classifier in parallel context if available
    vit_prediction = _get_vit_prediction(image_path)

    # Stage 1: Cloud VLM identification
    if _client:
        vlm_result = _call_vlm_single(image_path)
        if vlm_result:
            return _ground_prediction(vlm_result, vit_prediction)

    # Stage 2: Fallback to local ViT model alone
    if vit_prediction:
        return _ground_prediction(vit_prediction, None)

    return _empty_prediction()


def predict_food_multi(image_paths: List[str]) -> Dict[str, Any]:
    """
    Multi-image DietAI24 pipeline.
    Sends all images to VLM in a single request for cross-view analysis.
    """
    if not image_paths:
        return _empty_prediction()

    if len(image_paths) == 1:
        return predict_food(image_paths[0])

    # Run ViT on the first image for ensemble
    vit_prediction = _get_vit_prediction(image_paths[0])

    # Multi-image VLM call
    if _client:
        vlm_result = _call_vlm_multi(image_paths)
        if vlm_result:
            vlm_result["images_used"] = len(image_paths)
            return _ground_prediction(vlm_result, vit_prediction)

    # Fallback to single-image prediction
    return predict_food(image_paths[0])


def predict_food_text(query: str) -> Dict[str, Any]:
    """
    DietAI24 pipeline for TEXT inputs.
    Sends user's raw text to VLM to extract food and quantity, then grounds it.
    """
    if not query.strip():
        return _empty_prediction()

    if _client:
        try:
            print(f"INFO: [Stage 1] Calling Cloud VLM for Text: '{query}'...", flush=True)
            response = _client.chat.completions.create(
                model=_AI_MODEL,
                messages=[{
                    "role": "user",
                    "content": _TEXT_LOG_PROMPT + f"\n\nUser text input:\n'{query}'",
                }],
                max_tokens=150,
                timeout=10.0,
            )

            raw = response.choices[0].message.content.strip()
            print(f"INFO: [Stage 1] Text VLM response: {raw}", flush=True)

            parsed = _parse_vlm_json(raw)
            if parsed and "food" in parsed:
                vlm_result = {
                    "food": parsed["food"].strip(),
                    "portion_description": parsed.get("portion_description", "1 serving"),
                    "confidence_note": parsed.get("confidence_note", "Text log"),
                    "confidence": 1.0,
                    "engine": f"Cloud VLM Text ({_AI_MODEL})",
                }
                return _ground_prediction(vlm_result, None)
        except Exception as e:
            print(f"WARNING: [Stage 1] Text VLM failed: {e}", flush=True)

    # Fallback if VLM fails: just pass it directly to RAG
    # Assume 1 serving if they hit fallback
    fallback_result = {
        "food": query.strip(),
        "portion_description": "1 serving",
        "confidence_note": "VLM Offline Fallback",
        "confidence": 0.5,
        "engine": "Text Fallback",
    }
    return _ground_prediction(fallback_result, None)


# ---------------------------------------------------------------------------
# Stage 1: VLM calls
# ---------------------------------------------------------------------------

def _call_vlm_single(image_path: str) -> Optional[Dict[str, Any]]:
    """Call Cloud VLM with single image. Returns raw prediction dict or None."""
    try:
        from services.yolo_service import detect_and_annotate
        print(f"INFO: [Stage 1] Calling YOLO for {os.path.basename(image_path)}...", flush=True)
        annotated_path, detected_items = detect_and_annotate(image_path)
        
        final_img_path = annotated_path if os.path.exists(annotated_path) else image_path
        
        prompt = _SINGLE_IMAGE_PROMPT
        if len(detected_items) > 1:
            print(f"INFO: [Stage 1] YOLO detected plate items: {', '.join(detected_items)}", flush=True)
            prompt += f"\n\nHint: Object detection identified multiple items: {', '.join(detected_items)}. If this is a mixed plate (like a Thali), provide an aggregated name representing the whole meal and sum the overall portion (e.g. '1 large mixed plate')."

        print(f"INFO: [Stage 1] Calling Cloud VLM for {os.path.basename(final_img_path)}...", flush=True)
        with open(final_img_path, "rb") as f:
            base64_image = base64.b64encode(f.read()).decode("utf-8")

        response = _client.chat.completions.create(
            model=_AI_MODEL,
            messages=[{
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{base64_image}"}},
                ],
            }],
            max_tokens=200,
            timeout=15.0,
        )

        raw = response.choices[0].message.content.strip()
        print(f"INFO: [Stage 1] VLM response: {raw}", flush=True)

        parsed = _parse_vlm_json(raw)
        if parsed and "food" in parsed:
            return {
                "food": parsed["food"].strip(),
                "portion_description": parsed.get("portion_description", "1 serving"),
                "confidence_note": parsed.get("confidence_note", ""),
                "confidence": 0.95,
                "engine": f"Cloud VLM ({_AI_MODEL})",
            }

        # Fallback: raw text as food name
        vlm_label = raw.split("\n")[0].split(".")[0].strip().strip("'").strip('"')
        if vlm_label:
            return {
                "food": vlm_label,
                "portion_description": "1 serving",
                "confidence_note": "Parsed from unstructured VLM output",
                "confidence": 0.80,
                "engine": f"Cloud VLM ({_AI_MODEL}) [unstructured]",
            }

    except Exception as e:
        print(f"WARNING: [Stage 1] VLM failed: {e}", flush=True)

    return None


def _call_vlm_multi(image_paths: List[str]) -> Optional[Dict[str, Any]]:
    """Call Cloud VLM with multiple images."""
    try:
        print(f"INFO: [Stage 1] Multi-image VLM call with {len(image_paths)} images...", flush=True)

        from services.yolo_service import detect_and_annotate

        all_detected = set()
        final_image_paths = []
        for img_path in image_paths:
            annotated_path, detected_items = detect_and_annotate(img_path)
            if detected_items:
                all_detected.update(detected_items)
            final_image_paths.append(annotated_path if os.path.exists(annotated_path) else img_path)

        prompt = _MULTI_IMAGE_PROMPT
        if len(all_detected) > 1:
            prompt += f"\n\nHint: Object detection across these images identified multiple items: {', '.join(all_detected)}. If this is a mixed plate (like a Thali), provide an aggregated name representing the whole meal and sum the overall portion (e.g. '1 large mixed plate')."

        content_parts = [{"type": "text", "text": prompt}]
        for i, img_path in enumerate(final_image_paths):
            with open(img_path, "rb") as f:
                b64 = base64.b64encode(f.read()).decode("utf-8")
            content_parts.append({
                "type": "image_url",
                "image_url": {"url": f"data:image/jpeg;base64,{b64}"},
            })
            print(f"INFO:   Attached image {i+1}: {os.path.basename(img_path)}", flush=True)

        response = _client.chat.completions.create(
            model=_AI_MODEL,
            messages=[{"role": "user", "content": content_parts}],
            max_tokens=200,
            timeout=25.0,
        )

        raw = response.choices[0].message.content.strip()
        print(f"INFO: [Stage 1] Multi-VLM response: {raw}", flush=True)

        parsed = _parse_vlm_json(raw)
        if parsed and "food" in parsed:
            return {
                "food": parsed["food"].strip(),
                "portion_description": parsed.get("portion_description", "1 serving"),
                "confidence_note": parsed.get("confidence_note", ""),
                "confidence": 0.97,  # Higher confidence with multi-view
                "engine": f"Cloud VLM Multi ({_AI_MODEL})",
            }

    except Exception as e:
        print(f"WARNING: [Stage 1] Multi-VLM failed: {e}", flush=True)

    return None


# ---------------------------------------------------------------------------
# Ensemble: ViT classifier
# ---------------------------------------------------------------------------

def _get_vit_prediction(image_path: str) -> Optional[Dict[str, Any]]:
    """Run local ViT model if available. Used for ensemble cross-validation."""
    clf = get_local_classifier()
    if not clf or clf == "UNAVAILABLE":
        return None

    try:
        from PIL import Image
        img = Image.open(image_path).convert("RGB")
        results = clf(img)

        if results:
            top = results[0]
            label = top["label"].replace("_", " ")
            score = round(top["score"], 4)
            print(f"INFO: [Ensemble] ViT prediction: {label} ({score})", flush=True)
            return {
                "food": label,
                "portion_description": "1 serving",
                "confidence": score,
                "engine": f"Local ViT ({_VIT_MODEL_ID})",
            }
    except Exception as e:
        print(f"WARNING: [Ensemble] ViT failed: {e}", flush=True)

    return None


# ---------------------------------------------------------------------------
# Stage 2 & 3: RAG grounding + portion-weight calculation
# ---------------------------------------------------------------------------

def _ground_prediction(
    primary: Dict[str, Any],
    vit_secondary: Optional[Dict[str, Any]] = None
) -> Dict[str, Any]:
    """
    DietAI24 Stages 2 & 3:
      - Stage 2: RAG lookup to match food to database
      - Stage 3: Convert portion description to gram weight
      - Bonus: Ensemble cross-validation with ViT
    """
    food_name = primary["food"]
    portion_desc = primary.get("portion_description", "1 serving")
    confidence = primary.get("confidence", 0.90)
    engine = primary.get("engine", "Unknown")

    # --- Ensemble confidence adjustment ---
    if vit_secondary:
        vit_food = vit_secondary["food"].lower().strip()
        vlm_food = food_name.lower().strip()
        if vit_food == vlm_food or vit_food in vlm_food or vlm_food in vit_food:
            # Both models agree: boost confidence
            confidence = min(0.99, confidence + 0.04)
            engine += " + ViT ✓"
            print(f"INFO: [Ensemble] VLM+ViT AGREE on '{food_name}'. Confidence → {confidence}", flush=True)
        else:
            # Models disagree: note it but trust VLM (it sees more context)
            engine += f" (ViT: {vit_secondary['food']})"
            print(f"INFO: [Ensemble] VLM='{food_name}' vs ViT='{vit_secondary['food']}'. Trusting VLM.", flush=True)

    # --- Stage 2: RAG retrieval ---
    nutrition = None
    try:
        from services.rag_service import get_rag_service
        rag = get_rag_service()
        nutrition = rag.query_nutrition(food_name)
        if nutrition:
            print(f"INFO: [Stage 2] RAG matched: '{food_name}' → '{nutrition.get('food_name', food_name)}'", flush=True)
    except Exception as e:
        print(f"WARNING: [Stage 2] RAG failed: {e}. Falling back to CSV.", flush=True)

    # Fallback to direct CSV lookup
    if not nutrition:
        nutrition = lookup_nutrition(food_name)
        if nutrition:
            print(f"INFO: [Stage 2] CSV matched: '{food_name}'", flush=True)

    # --- Stage 3: Portion-weight grounding ---
    weight_grams = 0.0
    grounded = False
    try:
        from services.rag_service import get_rag_service
        rag = get_rag_service()
        portion_result = rag.query_portion_weight(food_name, portion_desc)
        weight_grams = portion_result["estimated_weight_grams"]
        grounded = portion_result["grounded"]
        portion_desc = portion_result["portion_description"]

        if grounded and nutrition:
            std_grams = portion_result["standard_portion_grams"]
            if std_grams > 0:
                # Scale nutrition proportionally to actual portion
                nutrition = rag.scale_nutrition_by_weight(nutrition, std_grams, weight_grams)
                print(f"INFO: [Stage 3] Grounded: {portion_desc} = {weight_grams}g "
                      f"(scaled from {std_grams}g standard)", flush=True)
        elif grounded:
            print(f"INFO: [Stage 3] Grounded weight: {weight_grams}g (no nutrition to scale)", flush=True)
        else:
            print(f"INFO: [Stage 3] Ungrounded - no portion data in DB for '{food_name}'", flush=True)

    except Exception as e:
        print(f"WARNING: [Stage 3] Portion grounding failed: {e}", flush=True)

    return {
        "food": food_name,
        "confidence": confidence,
        "nutrition": nutrition,
        "weight_grams": weight_grams,
        "portion_description": portion_desc,
        "engine": engine,
        "grounded": grounded,
        "images_used": primary.get("images_used", 1),
    }


def _empty_prediction() -> Dict[str, Any]:
    """Return a default empty prediction."""
    return {
        "food": "Unknown",
        "confidence": 0.0,
        "nutrition": None,
        "weight_grams": 0.0,
        "portion_description": "Unknown",
        "engine": "None",
        "grounded": False,
    }


# ---------------------------------------------------------------------------
# Response builder (frontend-compatible format)
# ---------------------------------------------------------------------------

def _prediction_to_response(prediction: Dict[str, Any]) -> Dict[str, Any]:
    """
    Convert internal prediction dict to the response format expected by
    the Flutter frontend.
    """
    food_name = prediction["food"]
    confidence = prediction["confidence"]
    nutrition = prediction["nutrition"]
    engine = prediction.get("engine", "Unknown Engine")
    weight_grams = prediction.get("weight_grams", 0.0)
    portion_desc = prediction.get("portion_description", "Standard Serving")
    grounded = prediction.get("grounded", False)

    if nutrition:
        return {
            "food_name": food_name.title(),
            "portion_size": portion_desc,
            "estimated_weight_grams": weight_grams,
            "calories": round(nutrition.get("calories", 0), 1),
            "protein": round(nutrition.get("protein", 0), 1),
            "carbs": round(nutrition.get("carbs", 0), 1),
            "fat": round(nutrition.get("fat", 0), 1),
            "fiber_g": round(nutrition.get("fiber_g", 0), 1),
            "sugar_g": round(nutrition.get("sugar_g", 0), 1),
            "sodium_mg": round(nutrition.get("sodium_mg", 0), 1),
            "potassium_mg": round(nutrition.get("potassium_mg", 0), 1),
            "vitamin_a_mcg": round(nutrition.get("vitamin_a_mcg", 0), 1),
            "vitamin_c_mg": round(nutrition.get("vitamin_c_mg", 0), 1),
            "calcium_mg": round(nutrition.get("calcium_mg", 0), 1),
            "iron_mg": round(nutrition.get("iron_mg", 0), 1),
            "raw_data": {
                "engine": engine,
                "confidence": confidence,
                "grounded_weight": grounded,
                "methodology": "DietAI24 (RAG + FNDDS)" if grounded else "VLM Estimate",
                "images_used": prediction.get("images_used", 1),
            },
        }

    # No nutrition match — return zeroes with the predicted name
    return {
        "food_name": food_name,
        "portion_size": portion_desc,
        "estimated_weight_grams": weight_grams,
        "calories": 0.0,
        "protein": 0.0,
        "carbs": 0.0,
        "fat": 0.0,
        "raw_data": {
            "engine": engine,
            "confidence": confidence,
            "grounded_weight": grounded,
            "note": "No nutrition data found in database",
        },
    }


# ---------------------------------------------------------------------------
# Public API — keeps /analyze and /analyze-multi endpoints working
# ---------------------------------------------------------------------------

def analyze_food_image(image_path: str) -> Dict[str, Any]:
    """Analyse a single food image. Returns frontend-compatible response."""
    try:
        prediction = predict_food(image_path)
        return _prediction_to_response(prediction)
    except Exception as e:
        import traceback
        print(f"ERROR: Food analysis failed: {e}\n{traceback.format_exc()}", flush=True)
        return {
            "food_name": "Unknown Food",
            "portion_size": "N/A",
            "estimated_weight_grams": 0.0,
            "calories": 0.0, "protein": 0.0, "carbs": 0.0, "fat": 0.0,
            "raw_data": {"error": str(e), "traceback": traceback.format_exc()},
        }


def analyze_food_images_multi(image_paths: List[str], pose_data: Optional[List[Dict[str, Any]]] = None) -> Dict[str, Any]:
    """
    Analyse multiple food images. Returns frontend-compatible response.
    
    When pose_data is present (AR mode), additionally runs:
      - Phase 2: Pose validation & diversity scoring
      - Phase 3: DPT depth estimation → volumetric weight calculation
    """
    try:
        prediction = predict_food_multi(image_paths)
        response = _prediction_to_response(prediction)
        
        if pose_data:
            # --- Phase 2: Pose validation ---
            from services.pose_service import validate_and_save_pose_data
            temp_dir = os.path.dirname(image_paths[0]) if image_paths else "temp_uploads"
            prefix = os.path.basename(image_paths[0]).split('_')[0] if image_paths else "unknown"
            
            is_valid, score = validate_and_save_pose_data(pose_data, temp_dir, prefix)
            if is_valid:
                response["raw_data"]["ar_enhanced"] = True
                response["raw_data"]["pose_diversity_score"] = round(score, 2)
                if score > 0.4:
                    response["raw_data"]["pose_quality"] = "high"
                elif score > 0.2:
                    response["raw_data"]["pose_quality"] = "medium"
                else:
                    response["raw_data"]["pose_quality"] = "low"

            # --- Phase 3: Volumetric depth estimation ---
            try:
                from services.volume_service import estimate_volume_multi
                print(f"INFO: [Phase 3] Running depth-based volume estimation on {len(image_paths)} images...", flush=True)
                
                vol_result = estimate_volume_multi(image_paths)
                
                if vol_result["success"] and vol_result["volume_cm3"] > 0:
                    volume_cm3 = vol_result["volume_cm3"]
                    
                    # Use density lookup for weight
                    food_name = response.get("food_name", prediction.get("food", "Unknown"))
                    from services.rag_service import get_rag_service
                    rag = get_rag_service()
                    vol_weight = rag.query_weight_from_volume(food_name, volume_cm3)
                    
                    volumetric_grams = vol_weight["estimated_weight_grams"]
                    density_used = vol_weight["density_g_cm3"]
                    
                    print(f"INFO: [Phase 3] Volume={volume_cm3} cm³ × density={density_used} g/cm³ "
                          f"= {volumetric_grams}g (was {response.get('estimated_weight_grams', 0)}g)", flush=True)
                    
                    # Override weight with volumetric estimate
                    response["estimated_weight_grams"] = volumetric_grams

                    # Re-scale nutrition to match volumetric weight
                    old_weight = prediction.get("weight_grams", 0)
                    if old_weight > 0 and prediction.get("nutrition"):
                        scale = volumetric_grams / old_weight
                        nutrition = prediction["nutrition"]
                        for key in ["calories", "protein", "carbs", "fat",
                                    "fiber_g", "sugar_g", "sodium_mg", "potassium_mg",
                                    "vitamin_a_mcg", "vitamin_c_mg", "calcium_mg", "iron_mg"]:
                            if key in response:
                                response[key] = round(response[key] * scale, 1)
                    
                    # Add volumetric metadata to raw_data
                    response["raw_data"]["volume_cm3"] = volume_cm3
                    response["raw_data"]["density_g_cm3"] = density_used
                    response["raw_data"]["volume_method"] = vol_result["method"]
                    response["raw_data"]["depth_stats"] = vol_result["depth_map_stats"]
                    response["raw_data"]["methodology"] = "DietAI24 + VolTex Depth (Phase 3)"
                else:
                    print(f"INFO: [Phase 3] Volume estimation did not succeed, keeping heuristic weight.", flush=True)
                    
            except Exception as ve:
                print(f"WARNING: [Phase 3] Volume estimation failed: {ve}", flush=True)
                    
        return response
    except Exception as e:
        import traceback
        print(f"ERROR: Multi-image analysis failed: {e}\n{traceback.format_exc()}", flush=True)
        return {
            "food_name": "Unknown Food",
            "portion_size": "N/A",
            "estimated_weight_grams": 0.0,
            "calories": 0.0, "protein": 0.0, "carbs": 0.0, "fat": 0.0,
            "raw_data": {"error": str(e), "traceback": traceback.format_exc()},
        }

