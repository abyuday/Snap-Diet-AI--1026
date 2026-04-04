import os
import json
import re
from typing import Dict, Any, Optional, List

# ---------------------------------------------------------------------------
# Global model & data — loaded once at import time, reused across requests
# ---------------------------------------------------------------------------

import base64
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

# Local model fallback (Lazy loading)
_classifier = None

def get_local_classifier():
    """Lazily load the local classifier only if needed."""
    global _classifier
    if _classifier is None:
        # Avoid huge 500MB+ downloads by default to prevent hanging the server
        if os.getenv("USE_LOCAL_MODEL", "false").lower() != "true":
            print("INFO: Local model skip (USE_LOCAL_MODEL=false). Returning UNAVAILABLE fallback.", flush=True)
            _classifier = "UNAVAILABLE"
            return _classifier

        try:
            from transformers import pipeline
            print("INFO: Loading local fallback model (dima806/indian_food_image_detection)…", flush=True)
            _classifier = pipeline(
                "image-classification",
                model="dima806/indian_food_image_detection",
            )
            print("INFO: Local model loaded successfully.", flush=True)
        except Exception as e:
            print(f"WARNING: Local model failed to load or download: {e}. Using label-only fallback.", flush=True)
            _classifier = "UNAVAILABLE"
    return _classifier

_nutrition_df = None

def get_nutrition_df():
    global _nutrition_df
    if _nutrition_df is not None:
        return _nutrition_df

    # Determine paths correctly
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


# ---------------------------------------------------------------------------
# Nutrition lookup (case-insensitive + partial matching)
# ---------------------------------------------------------------------------

import difflib

# ---------------------------------------------------------------------------
# Nutrition lookup (case-insensitive + fuzzy matching)
# ---------------------------------------------------------------------------

def lookup_nutrition(food_label: str) -> Optional[Dict[str, float]]:
    """
    Look up nutrition info for *food_label* in the CSV.

    Matching strategy (first hit wins):
      1. Exact match (case-insensitive)
      2. Fuzzy match (handles spelling variations like Idly vs Idli)
      3. Word-level overlap
    """
    df = get_nutrition_df()
    if df is None or df.empty:
        return None

    label_lower = food_label.lower().strip()
    food_names = df["food_name"].tolist()
    food_names_lower = [f.lower().strip() for f in food_names]

    # ---- 1. Exact match ----
    if label_lower in food_names_lower:
        idx = food_names_lower.index(label_lower)
        return _row_to_dict(df.iloc[idx])

    # ---- 2. Fuzzy match (get closest string) ----
    matches = difflib.get_close_matches(label_lower, food_names_lower, n=1, cutoff=0.7)
    if matches:
        idx = food_names_lower.index(matches[0])
        print(f"INFO: Fuzzy match: '{food_label}' -> '{food_names[idx]}'", flush=True)
        return _row_to_dict(df.iloc[idx])

    # ---- 3. Word-level overlap ----
    label_words = set(label_lower.replace("-", " ").replace("_", " ").split())
    for _, row in df.iterrows():
        csv_name = str(row["food_name"]).lower().strip()
        csv_words = set(csv_name.replace("-", " ").replace("_", " ").split())
        if label_words & csv_words:
            return _row_to_dict(row)

    return None


def _row_to_dict(row) -> Dict[str, float]:
    """Extract nutrition numbers from a CSV row."""
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
    }


# ---------------------------------------------------------------------------
# Helper: parse structured JSON from VLM response
# ---------------------------------------------------------------------------

def _parse_vlm_json(raw_text: str) -> Optional[Dict[str, Any]]:
    """Try to extract a JSON object from the VLM response text."""
    text = raw_text.strip()
    # Try to find JSON block in markdown code fences
    md_match = re.search(r'```(?:json)?\s*({.*?})\s*```', text, re.DOTALL)
    if md_match:
        text = md_match.group(1)
    else:
        # Try to find raw JSON object
        json_match = re.search(r'\{[^{}]*\}', text, re.DOTALL)
        if json_match:
            text = json_match.group(0)
    try:
        return json.loads(text)
    except (json.JSONDecodeError, ValueError):
        return None


# ---------------------------------------------------------------------------
# VLM prompt for food identification + weight estimation
# ---------------------------------------------------------------------------

_SINGLE_IMAGE_PROMPT = """Analyze this food image carefully. Identify the Indian dish and estimate its portion.

Return ONLY a JSON object in this exact format (no extra text):
{"food": "<dish name>", "weight_grams": <number>, "portion_description": "<e.g. 2 pieces, 1 bowl, 1 plate>"}

Examples:
{"food": "Idli", "weight_grams": 120, "portion_description": "3 pieces"}
{"food": "Chicken Biryani", "weight_grams": 350, "portion_description": "1 plate"}
{"food": "Masala Dosa", "weight_grams": 180, "portion_description": "1 piece"}

Be precise about the weight estimate based on visual portion size."""

_MULTI_IMAGE_PROMPT = """You are given multiple images of the SAME food item taken from different angles.
Analyze ALL images together to accurately identify the dish and estimate the portion size.

Using all angles, estimate:
- The exact dish name
- The weight in grams (use all views to judge thickness, height, spread)
- A portion description (number of pieces, bowls, etc.)

Return ONLY a JSON object in this exact format (no extra text):
{"food": "<dish name>", "weight_grams": <number>, "portion_description": "<e.g. 2 pieces, 1 bowl, 1 plate>"}

Be precise. Multiple angles give you better depth/size information."""


# ---------------------------------------------------------------------------
# Core prediction function — used by /predict endpoint
# ---------------------------------------------------------------------------

def predict_food(image_path: str) -> Dict[str, Any]:
    """
    Run prediction on *image_path*. Uses Cloud VLM first, then local fallback.
    Now returns weight estimate and portion description from VLM.
    """
    # 1. Try Cloud VLM
    if _client:
        try:
            print(f"INFO: Calling Cloud VLM for image ({os.path.basename(image_path)})...", flush=True)
            with open(image_path, "rb") as f:
                base64_image = base64.b64encode(f.read()).decode("utf-8")

            response = _client.chat.completions.create(
                model=_AI_MODEL,
                messages=[
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": _SINGLE_IMAGE_PROMPT},
                            {
                                "type": "image_url",
                                "image_url": {"url": f"data:image/jpeg;base64,{base64_image}"},
                            },
                        ],
                    }
                ],
                max_tokens=150,
                timeout=15.0,
            )

            raw_response = response.choices[0].message.content.strip()
            print(f"INFO: VLM raw response: {raw_response}", flush=True)

            parsed = _parse_vlm_json(raw_response)
            if parsed and "food" in parsed:
                food_name = parsed["food"].strip()
                weight_grams = float(parsed.get("weight_grams", 0))
                portion_desc = parsed.get("portion_description", "Standard Serving")
                print(f"INFO: VLM Parsed: {food_name}, {weight_grams}g, {portion_desc}", flush=True)

                nutrition = lookup_nutrition(food_name)
                return {
                    "food": food_name,
                    "confidence": 0.99,
                    "nutrition": nutrition,
                    "weight_grams": weight_grams,
                    "portion_description": portion_desc,
                    "engine": f"Cloud VLM ({_AI_MODEL})",
                }
            else:
                # Fallback: try to use raw text as food name
                vlm_label = raw_response.split("\n")[0].split(".")[0].strip().strip("'").strip('"')
                if vlm_label:
                    nutrition = lookup_nutrition(vlm_label)
                    return {
                        "food": vlm_label,
                        "confidence": 0.90,
                        "nutrition": nutrition,
                        "weight_grams": 0.0,
                        "portion_description": "Standard Serving",
                        "engine": f"Cloud VLM ({_AI_MODEL}) [unstructured]",
                    }

        except Exception as e:
            print(f"WARNING: Cloud VLM failed ({e}). Falling back...", flush=True)

    # 2. Fallback to Local Model
    clf = get_local_classifier()
    if clf and clf != "UNAVAILABLE":
        try:
            from PIL import Image
            img = Image.open(image_path).convert("RGB")
            results = clf(img)

            if results:
                top = results[0]
                label: str = top["label"].replace("_", " ")
                score: float = round(top["score"], 4)
                print(f"INFO: Local Prediction: {label} ({score})", flush=True)

                nutrition = lookup_nutrition(label)
                return {
                    "food": label,
                    "confidence": score,
                    "nutrition": nutrition,
                    "weight_grams": 0.0,
                    "portion_description": "Standard Serving",
                    "engine": "Local (dima806/indian_food_image_detection)",
                }
        except Exception as e:
            print(f"ERROR: Local model prediction failed: {e}", flush=True)

    return {
        "food": "Unknown",
        "confidence": 0.0,
        "nutrition": None,
        "weight_grams": 0.0,
        "portion_description": "Unknown",
        "engine": "None",
    }


# ---------------------------------------------------------------------------
# Multi-image prediction — used by /analyze-multi endpoint
# ---------------------------------------------------------------------------

def predict_food_multi(image_paths: List[str]) -> Dict[str, Any]:
    """
    Run prediction on multiple images of the same food item.
    Sends all images to the Cloud VLM in a single request for better accuracy.
    Falls back to single-image prediction on the first image if multi fails.
    """
    if not image_paths:
        return {
            "food": "Unknown",
            "confidence": 0.0,
            "nutrition": None,
            "weight_grams": 0.0,
            "portion_description": "Unknown",
            "engine": "None",
        }

    # If only one image, use single prediction
    if len(image_paths) == 1:
        return predict_food(image_paths[0])

    # Try Cloud VLM with multiple images
    if _client:
        try:
            print(f"INFO: Calling Cloud VLM with {len(image_paths)} images...", flush=True)

            # Build content array with text prompt + all images
            content_parts = [{"type": "text", "text": _MULTI_IMAGE_PROMPT}]
            for i, img_path in enumerate(image_paths):
                with open(img_path, "rb") as f:
                    b64 = base64.b64encode(f.read()).decode("utf-8")
                content_parts.append({
                    "type": "image_url",
                    "image_url": {"url": f"data:image/jpeg;base64,{b64}"},
                })
                print(f"INFO: Attached image {i+1}: {os.path.basename(img_path)}", flush=True)

            response = _client.chat.completions.create(
                model=_AI_MODEL,
                messages=[{"role": "user", "content": content_parts}],
                max_tokens=200,
                timeout=25.0,  # More time for multi-image
            )

            raw_response = response.choices[0].message.content.strip()
            print(f"INFO: Multi-VLM raw response: {raw_response}", flush=True)

            parsed = _parse_vlm_json(raw_response)
            if parsed and "food" in parsed:
                food_name = parsed["food"].strip()
                weight_grams = float(parsed.get("weight_grams", 0))
                portion_desc = parsed.get("portion_description", "Standard Serving")
                print(f"INFO: Multi-VLM Parsed: {food_name}, {weight_grams}g, {portion_desc}", flush=True)

                nutrition = lookup_nutrition(food_name)
                return {
                    "food": food_name,
                    "confidence": 0.99,
                    "nutrition": nutrition,
                    "weight_grams": weight_grams,
                    "portion_description": portion_desc,
                    "engine": f"Cloud VLM Multi ({_AI_MODEL})",
                    "images_used": len(image_paths),
                }

        except Exception as e:
            print(f"WARNING: Multi-image VLM failed ({e}). Falling back to single...", flush=True)

    # Fallback: use single prediction on first image
    return predict_food(image_paths[0])


# ---------------------------------------------------------------------------
# Helper: build frontend-compatible response from prediction dict
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
            "note": "No nutrition data found in CSV",
        },
    }


# ---------------------------------------------------------------------------
# Legacy function — keeps /analyze endpoint & Flutter frontend working
# ---------------------------------------------------------------------------

def analyze_food_image(image_path: str) -> Dict[str, Any]:
    """
    Analyse a food image and return nutrition in the format expected by the
    existing Flutter frontend (food_name, portion_size, calories, …).
    """
    try:
        prediction = predict_food(image_path)
        return _prediction_to_response(prediction)
    except Exception as e:
        import traceback
        error_msg = f"Food analysis failed: {str(e)}\n{traceback.format_exc()}"
        print(error_msg, flush=True)
        return {
            "food_name": "Unknown Food",
            "portion_size": "N/A",
            "estimated_weight_grams": 0.0,
            "calories": 0.0,
            "protein": 0.0,
            "carbs": 0.0,
            "fat": 0.0,
            "raw_data": {"error": str(e), "traceback": traceback.format_exc()},
        }


def analyze_food_images_multi(image_paths: List[str]) -> Dict[str, Any]:
    """
    Analyse multiple food images (different angles of the same dish)
    and return nutrition in the frontend format.
    """
    try:
        prediction = predict_food_multi(image_paths)
        return _prediction_to_response(prediction)
    except Exception as e:
        import traceback
        error_msg = f"Multi-image food analysis failed: {str(e)}\n{traceback.format_exc()}"
        print(error_msg, flush=True)
        return {
            "food_name": "Unknown Food",
            "portion_size": "N/A",
            "estimated_weight_grams": 0.0,
            "calories": 0.0,
            "protein": 0.0,
            "carbs": 0.0,
            "fat": 0.0,
            "raw_data": {"error": str(e), "traceback": traceback.format_exc()},
        }
