"""
RAG Service — DietAI24-style FNDDS + Indian Food Knowledge Base

Implements the Retrieval-Augmented Generation approach from DietAI24:
1. Index food items with descriptions, nutrition, AND portion-weight mappings
2. Retrieve the best matching food given a VLM description
3. Return standard portion weights for accurate gram estimation
"""

import os
import re
import pandas as pd
import numpy as np
from typing import List, Dict, Any, Optional, Tuple
from langchain_community.vectorstores import Chroma
from langchain_openai import OpenAIEmbeddings
from langchain_community.embeddings import DeterministicFakeEmbedding
from langchain_core.documents import Document
import difflib

# Paths 
FNDDS_EXCEL = os.getenv("FNDDS_DATA_PATH", "FNDDS/2019-2020 FNDDS At A Glance - FNDDS Nutrient Values.xlsx")
FNDDS_DESC_EXCEL = os.getenv("FNDDS_DESC_PATH", "FNDDS/2019-2020 FNDDS At A Glance - Foods and Beverages.xlsx")
CHROMA_DIR = os.getenv("CHROMA_DB_PATH", "db/chroma")


# ---------------------------------------------------------------------------
# Portion parsing utilities
# ---------------------------------------------------------------------------

# Maps common portion words to numeric multipliers
_PORTION_NUMBER_WORDS = {
    "a": 1, "an": 1, "one": 1, "two": 2, "three": 3, "four": 4,
    "five": 5, "six": 6, "seven": 7, "eight": 8, "half": 0.5,
    "quarter": 0.25, "dozen": 12, "couple": 2,
}

def _dietai_safe_float(val, default=0.0):
    try:
        if pd.isna(val): return default
        return float(val)
    except (ValueError, TypeError):
        return default

def parse_portion_count(portion_description: str) -> float:
    """
    Extract numeric count from a portion description.
    Examples:
        "3 pieces" -> 3.0
        "1 plate"  -> 1.0
        "half bowl" -> 0.5
        "2 glasses" -> 2.0
    """
    if not portion_description:
        return 1.0

    desc = portion_description.lower().strip()

    # Try leading number (int or float)
    num_match = re.match(r'^(\d+(?:\.\d+)?)\s*', desc)
    if num_match:
        return float(num_match.group(1))

    # Try word-based numbers
    first_word = desc.split()[0] if desc.split() else ""
    if first_word in _PORTION_NUMBER_WORDS:
        return float(_PORTION_NUMBER_WORDS[first_word])

    return 1.0


def normalize_portion_unit(portion_description: str) -> str:
    """
    Extract and normalize the unit from a portion description.
    "3 pieces" -> "piece"
    "1 bowl"   -> "bowl"
    "2 plates" -> "plate"
    """
    if not portion_description:
        return "serving"

    desc = portion_description.lower().strip()
    # Remove leading numbers / number words
    desc = re.sub(r'^(\d+(?:\.\d+)?)\s*', '', desc)
    for word in _PORTION_NUMBER_WORDS:
        if desc.startswith(word + " "):
            desc = desc[len(word):].strip()
            break

    # Singularize common units
    unit = desc.strip().rstrip("s").rstrip("es") if desc.strip() else "serving"
    # Fix over-stripping
    if unit in ("piec", "glas"):
        unit = {"piec": "piece", "glas": "glass"}.get(unit, unit)
    return unit or "serving"


class RAGService:
    def __init__(self):
        self.use_fake = True  # Default to fake if no API key
        if os.getenv("OPENAI_API_KEY"):
            self.embeddings = OpenAIEmbeddings()
            self.use_fake = False
        else:
            self.embeddings = DeterministicFakeEmbedding(size=1536)

        # Core lookup dictionaries
        self._name_lookup: Dict[str, Dict] = {}     # keyword -> nutrition dict
        self._portion_lookup: Dict[str, Dict] = {}   # food_name_lower -> {grams_per_unit, unit, ...}
        self._density_lookup: Dict[str, float] = {}  # food_name_lower -> density_g_cm3
        self._load_density()
        self._name_lookup, self._portion_lookup = {}, {}
        self._initialize_db()

    def _load_density(self):
        """Loads food density table for volumetric weight heuristic fallback."""
        density_path = os.path.join(os.path.dirname(__file__), "..", "..", "datasets", "food_density.csv")
        if not os.path.exists(density_path):
            density_path = "datasets/food_density.csv"
        
        if os.path.exists(density_path):
            try:
                df = pd.read_csv(density_path)
                for _, row in df.iterrows():
                    name_lower = str(row["food_name"]).lower().strip()
                    self._density_lookup[name_lower] = float(row["density_g_cm3"])
                print(f"INFO [RAG]: Loaded {len(self._density_lookup)} food density mappings.", flush=True)
            except Exception as e:
                print(f"WARNING [RAG]: Failed to load density lookup: {e}", flush=True)

    # ------------------------------------------------------------------
    # Initialization
    # ------------------------------------------------------------------

    def _initialize_db(self):
        """Loads food data into fast in-memory dictionaries. Skips ChromaDB (corrupted)."""
        self.vector_db = None  # ChromaDB disabled - using dict lookups only (faster & more reliable)
        # Build the in-memory name/portion lookup from all CSV sources
        _, self._name_lookup, self._portion_lookup = self._get_initial_docs()
        print(f"INFO [RAG]: Fast-mode ready. {len(self._name_lookup)} foods indexed.", flush=True)

    def _get_initial_docs(self) -> Tuple[list, dict, dict]:
        """Build documents, name lookup, and portion lookup from all data sources."""
        name_lookup = {}
        portion_lookup = {}

        # -----------------------------------------------------------
        # 1. Base FNDDS Data (Western/Global) with portion weights
        # -----------------------------------------------------------
        base_data = []
        
        docs = []
        for item in base_data:
            content = (
                f"Food: {item['name']}. "
                f"Standard portion: {item['portion_unit']} ({item['portion_grams']}g). "
                f"Nutrition per 100g: {item['calories']} kcal, "
                f"{item['protein']}g protein, {item['carbs']}g carbs, {item['fat']}g fat."
            )
            docs.append(Document(
                page_content=content,
                metadata={**item, "source": "FNDDS"}
            ))
            key = item["name"].lower()
            name_lookup[key] = {
                "food_name": item["name"],
                "calories": float(item["calories"]),
                "protein": float(item["protein"]),
                "carbs": float(item["carbs"]),
                "fat": float(item["fat"]),
                "fndds_code": item["code"],
                "source": "FNDDS RAG Pipeline"
            }
            portion_lookup[key] = {
                "food_name": item["name"],
                "standard_portion_grams": float(item["portion_grams"]),
                "portion_unit": item["portion_unit"],
            }

        # -----------------------------------------------------------
        # 2. Indian Food Expansion (Primary Knowledge Base)
        # -----------------------------------------------------------
        indian_path = "datasets/indian_food_nutrition.csv"
        if os.path.exists(indian_path):
            try:
                df = pd.read_csv(indian_path)
                for _, row in df.iterrows():
                    food_name = str(row['food_name'])
                    std_grams = _dietai_safe_float(row.get('standard_portion_grams'))
                    portion_unit = str(row.get('portion_unit', '1 serving'))

                    # Rich document text for better semantic retrieval
                    content = (
                        f"Indian dish: {food_name}. {row.get('description', '')}. "
                        f"Standard portion: {portion_unit} ({std_grams}g). "
                        f"Nutrition: {row['calories']} kcal, "
                        f"{row['protein']}g protein, {row['carbs']}g carbs, {row['fat']}g fat. "
                        f"Fiber: {row.get('fiber_g', 0)}g, Sodium: {row.get('sodium_mg', 0)}mg, "
                        f"Calcium: {row.get('calcium_mg', 0)}mg, Iron: {row.get('iron_mg', 0)}mg."
                    )
                    meta = {
                        "name": food_name,
                        "calories": float(row['calories']),
                        "protein": float(row['protein']),
                        "carbs": float(row['carbs']),
                        "fat": float(row['fat']),
                        "fiber_g": float(row.get('fiber_g', 0) or 0),
                        "sugar_g": float(row.get('sugar_g', 0) or 0),
                        "sodium_mg": float(row.get('sodium_mg', 0) or 0),
                        "potassium_mg": float(row.get('potassium_mg', 0) or 0),
                        "vitamin_a_mcg": float(row.get('vitamin_a_mcg', 0) or 0),
                        "vitamin_c_mg": float(row.get('vitamin_c_mg', 0) or 0),
                        "calcium_mg": float(row.get('calcium_mg', 0) or 0),
                        "iron_mg": float(row.get('iron_mg', 0) or 0),
                        "standard_portion_grams": std_grams,
                        "portion_unit": portion_unit,
                        "code": "IND_" + food_name[:3].upper(),
                        "source": "IFCT_Custom"
                    }
                    docs.append(Document(page_content=content, metadata=meta))

                    name_lower = food_name.lower()
                    nutrition_rec = {
                        "food_name": food_name,
                        "calories": meta["calories"],
                        "protein": meta["protein"],
                        "carbs": meta["carbs"],
                        "fat": meta["fat"],
                        "fiber_g": meta["fiber_g"],
                        "sugar_g": meta["sugar_g"],
                        "sodium_mg": meta["sodium_mg"],
                        "potassium_mg": meta["potassium_mg"],
                        "vitamin_a_mcg": meta["vitamin_a_mcg"],
                        "vitamin_c_mg": meta["vitamin_c_mg"],
                        "calcium_mg": meta["calcium_mg"],
                        "iron_mg": meta["iron_mg"],
                        "fndds_code": meta["code"],
                        "source": "FNDDS RAG Pipeline"
                    }
                    name_lookup[name_lower] = nutrition_rec
                    portion_lookup[name_lower] = {
                        "food_name": food_name,
                        "standard_portion_grams": std_grams,
                        "portion_unit": portion_unit,
                    }

                    # Also index by key terms (e.g. "biryani" -> Chicken Biryani)
                    for word in name_lower.replace(",", " ").split():
                        if len(word) >= 4 and word not in name_lookup:
                            name_lookup[word] = nutrition_rec
                            portion_lookup[word] = portion_lookup[name_lower]

                print(f"INFO [RAG]: Indexed {len(df)} Indian food items with portion data.", flush=True)
            except Exception as e:
                print(f"ERROR [RAG]: Loading Indian dataset: {e}", flush=True)

        # -----------------------------------------------------------
        # 2b. Full INDB / IFCT 2017 Expansion (1,000+ items)
        # -----------------------------------------------------------
        ifct_path = "datasets/ifct_2017_full.csv"
        if os.path.exists(ifct_path):
            try:
                df_ifct = pd.read_csv(ifct_path)
                for _, row in df_ifct.iterrows():
                    # INDB format mapping
                    food_name = str(row.get('food_name', ''))
                    if not food_name: continue
                    
                    # Primary macros (per 100g)
                    calories = _dietai_safe_float(row.get('energy_kcal'))
                    protein = _dietai_safe_float(row.get('protein_g'))
                    carbs = _dietai_safe_float(row.get('carb_g'))
                    fat = _dietai_safe_float(row.get('fat_g'))
                    
                    content = f"Indian Food (INDB): {food_name}. Rich nutritional data available."
                    meta = {
                        "name": food_name,
                        "calories": calories,
                        "protein": protein,
                        "carbs": carbs,
                        "fat": fat,
                        "fiber_g": _dietai_safe_float(row.get('fibre_g')),
                        "iron_mg": _dietai_safe_float(row.get('iron_mg')),
                        "calcium_mg": _dietai_safe_float(row.get('calcium_mg')),
                        "sodium_mg": _dietai_safe_float(row.get('sodium_mg')),
                        "standard_portion_grams": 100.0,
                        "portion_unit": "100g",
                        "source": "INDB_Full"
                    }
                    docs.append(Document(page_content=content, metadata=meta))
                    
                    name_lower = food_name.lower()
                    rec = {
                        "food_name": food_name,
                        "calories": calories,
                        "protein": protein,
                        "carbs": carbs,
                        "fat": fat,
                        "fiber_g": meta["fiber_g"],
                        "iron_mg": meta["iron_mg"],
                        "calcium_mg": meta["calcium_mg"],
                        "sodium_mg": meta["sodium_mg"],
                        "fiber_g": meta["fiber_g"],
                        "iron_mg": meta["iron_mg"],
                        "calcium_mg": meta["calcium_mg"],
                        "source": "INDB Full Database"
                    }
                    name_lookup[name_lower] = rec
                    portion_lookup[name_lower] = {
                        "food_name": food_name,
                        "standard_portion_grams": 100.0,
                        "portion_unit": "100g",
                    }
                print(f"INFO [RAG]: Successfully indexed {len(df_ifct)} high-detail items from INDB dataset.", flush=True)
            except Exception as e:
                print(f"ERROR [RAG]: Loading INDB dataset: {e}", flush=True)

        # -----------------------------------------------------------
        # 3. Global Nutrition Expansion (Nutrition5k)
        # -----------------------------------------------------------
        global_path = "datasets/global_food_nutrition.csv"
        if os.path.exists(global_path):
            try:
                df_global = pd.read_csv(global_path)
                for _, row in df_global.iterrows():
                    food_name = str(row['food_name'])
                    # Nutrition5k ingredients are per 100g. Standard portion is 100g.
                    content = (
                        f"Global ingredient: {food_name}. "
                        f"Nutrition per 100g: {row['calories']} kcal, "
                        f"{row['protein']}g protein, {row['carbs']}g carbs, {row['fat']}g fat."
                    )
                    meta = {
                        "name": food_name,
                        "calories": float(row['calories']),
                        "protein": float(row['protein']),
                        "carbs": float(row['carbs']),
                        "fat": float(row['fat']),
                        "standard_portion_grams": 100.0,
                        "portion_unit": "100g",
                        "source": "Nutrition5k"
                    }
                    docs.append(Document(page_content=content, metadata=meta))

                    name_lower = food_name.lower()
                    name_lookup[name_lower] = {
                        "food_name": food_name,
                        "calories": meta["calories"],
                        "protein": meta["protein"],
                        "carbs": meta["carbs"],
                        "fat": meta["fat"],
                        "source": "Nutrition5k"
                    }
                    portion_lookup[name_lower] = {
                        "food_name": food_name,
                        "standard_portion_grams": 100.0,
                        "portion_unit": "100g",
                    }
                print(f"INFO [RAG]: Indexed {len(df_global)} global food items from Nutrition5k.", flush=True)
            except Exception as e:
                print(f"ERROR [RAG]: Loading global dataset: {e}", flush=True)

        return docs, name_lookup, portion_lookup

    def _build_lookups(self) -> Tuple[dict, dict]:
        """Build keyword -> nutrition/portion dicts (for existing vector DB reload)."""
        name_lookup = {}
        portion_lookup = {}

        # Base Global Data (Expanded Fallback for missing FNDDS files)
        # Nutrition values are PER 100g as per IFCT/FNDDS standards
        base_data = [
            # Proteins
            {"code": "24101000", "name": "Chicken breast",     "calories": 165, "protein": 31,   "carbs": 0,    "fat": 3.6,  "portion_grams": 172, "portion_unit": "1 piece"},
            {"code": "23111000", "name": "Beef Steak",         "calories": 252, "protein": 27,   "carbs": 0,    "fat": 15.0, "portion_grams": 170, "portion_unit": "1 piece"},
            {"code": "22211000", "name": "Salmon",             "calories": 208, "protein": 22,   "carbs": 0,    "fat": 13.0, "portion_grams": 150, "portion_unit": "1 piece"},
            {"code": "11111100", "name": "Egg",                "calories": 155, "protein": 12.6, "carbs": 1.1,  "fat": 10.6, "portion_grams": 50,  "portion_unit": "1 piece"},
            {"code": "21101000", "name": "Pork Chop",          "calories": 242, "protein": 26,   "carbs": 0,    "fat": 14.0, "portion_grams": 150, "portion_unit": "1 piece"},
            {"code": "25111000", "name": "Tofu",               "calories": 76,  "protein": 8,    "carbs": 1.9,  "fat": 4.8,  "portion_grams": 100, "portion_unit": "1 block"},
            
            # Carbs/Grains
            {"code": "72101100", "name": "Rice, white",        "calories": 130, "protein": 2.7,  "carbs": 28.2, "fat": 0.3,  "portion_grams": 186, "portion_unit": "1 cup"},
            {"code": "72101200", "name": "Rice, brown",        "calories": 111, "protein": 2.6,  "carbs": 23.0, "fat": 0.9,  "portion_grams": 190, "portion_unit": "1 cup"},
            {"code": "73101010", "name": "Spaghetti",          "calories": 158, "protein": 5.8,  "carbs": 30.9, "fat": 0.9,  "portion_grams": 140, "portion_unit": "1 cup"},
            {"code": "51101010", "name": "Bread, white",       "calories": 265, "protein": 9,    "carbs": 49,   "fat": 3.2,  "portion_grams": 35,  "portion_unit": "1 slice"},
            {"code": "51101210", "name": "Bread, whole wheat", "calories": 247, "protein": 13,   "carbs": 41,   "fat": 3.4,  "portion_grams": 35,  "portion_unit": "1 slice"},
            {"code": "71101010", "name": "Potato, boiled",     "calories": 87,  "protein": 1.9,  "carbs": 20,   "fat": 0.1,  "portion_grams": 150, "portion_unit": "1 medium"},
            
            # Dairy/Fats
            {"code": "11111111", "name": "Milk, whole",       "calories": 61,  "protein": 3.15, "carbs": 4.8,  "fat": 3.25, "portion_grams": 244, "portion_unit": "1 cup"},
            {"code": "11111211", "name": "Milk, reduced fat",  "calories": 50,  "protein": 3.3,  "carbs": 4.8,  "fat": 1.99, "portion_grams": 244, "portion_unit": "1 cup"},
            {"code": "14111100", "name": "Cheddar Cheese",    "calories": 403, "protein": 25,   "carbs": 1.3,  "fat": 33,   "portion_grams": 28,  "portion_unit": "1 slice"},
            {"code": "11511100", "name": "Yogurt, plain",      "calories": 59,  "protein": 10,   "carbs": 3.6,  "fat": 0.4,  "portion_grams": 170, "portion_unit": "1 container"},
            {"code": "81101010", "name": "Butter",             "calories": 717, "protein": 0.8,  "carbs": 0.1,  "fat": 81,   "portion_grams": 14,  "portion_unit": "1 tbsp"},
            {"code": "82101010", "name": "Olive Oil",          "calories": 884, "protein": 0,    "carbs": 0,    "fat": 100,  "portion_grams": 15,  "portion_unit": "1 tbsp"},
            
            # Fruits/Veg
            {"code": "41101010", "name": "Apple",              "calories": 52,  "protein": 0.26, "carbs": 13.8, "fat": 0.17, "portion_grams": 182, "portion_unit": "1 piece"},
            {"code": "41101020", "name": "Banana",             "calories": 89,  "protein": 1.09, "carbs": 22.8, "fat": 0.33, "portion_grams": 118, "portion_unit": "1 piece"},
            {"code": "42101010", "name": "Broccoli",           "calories": 34,  "protein": 2.8,  "carbs": 6.6,  "fat": 0.4,  "portion_grams": 91,  "portion_unit": "1 cup"},
            {"code": "42111010", "name": "Spinach",            "calories": 23,  "protein": 2.9,  "carbs": 3.6,  "fat": 0.4,  "portion_grams": 30,  "portion_unit": "1 cup"},
            {"code": "42101020", "name": "Tomato",             "calories": 18,  "protein": 0.9,  "carbs": 3.9,  "fat": 0.2,  "portion_grams": 123, "portion_unit": "1 medium"},
            {"code": "41101030", "name": "Avocado",            "calories": 160, "protein": 2,    "carbs": 8.5,  "fat": 14.7, "portion_grams": 150, "portion_unit": "1 half"},
            
            # Common Western Prepared
            {"code": "53108200", "name": "Pizza, cheese",      "calories": 266, "protein": 11.4, "carbs": 33.3, "fat": 9.7,  "portion_grams": 107, "portion_unit": "1 slice"},
            {"code": "53108300", "name": "Pizza, pepperoni",   "calories": 298, "protein": 12.0, "carbs": 32.0, "fat": 13.0, "portion_grams": 115, "portion_unit": "1 slice"},
            {"code": "58101010", "name": "Burger, beef",       "calories": 295, "protein": 17,   "carbs": 24,   "fat": 14,   "portion_grams": 150, "portion_unit": "1 piece"},
            {"code": "58101020", "name": "Cheeseburger",       "calories": 303, "protein": 16,   "carbs": 24,   "fat": 15,   "portion_grams": 155, "portion_unit": "1 piece"},
            {"code": "71501010", "name": "French Fries",       "calories": 312, "protein": 3.4,  "carbs": 41,   "fat": 15,   "portion_grams": 100, "portion_unit": "1 medium serving"},
            {"code": "53201010", "name": "Caesar Salad",       "calories": 190, "protein": 4,    "carbs": 8,    "fat": 16,   "portion_grams": 150, "portion_unit": "1 bowl"},
            {"code": "58106010", "name": "Sushi, California",  "calories": 143, "protein": 4,    "carbs": 28,   "fat": 2,    "portion_grams": 100, "portion_unit": "4 pieces"},
        ]
        for item in base_data:
            key = item["name"].lower()
            name_lookup[key] = {
                "food_name": item["name"],
                "calories": float(item["calories"]),
                "protein": float(item["protein"]),
                "carbs": float(item["carbs"]),
                "fat": float(item["fat"]),
                "fndds_code": item["code"],
                "source": "FNDDS RAG Pipeline"
            }
            portion_lookup[key] = {
                "food_name": item["name"],
                "standard_portion_grams": float(item["portion_grams"]),
                "portion_unit": item["portion_unit"],
            }

        # Indian CSV
        indian_path = "datasets/indian_food_nutrition.csv"
        if os.path.exists(indian_path):
            try:
                df = pd.read_csv(indian_path)
                for _, row in df.iterrows():
                    food_name = str(row['food_name'])
                    name_lower = food_name.lower()
                    std_grams = float(row.get('standard_portion_grams', 0) or 0)
                    portion_unit = str(row.get('portion_unit', '1 serving'))

                    rec = {
                        "food_name": food_name,
                        "calories": float(row['calories']),
                        "protein": float(row['protein']),
                        "carbs": float(row['carbs']),
                        "fat": float(row['fat']),
                        "fiber_g": float(row.get('fiber_g', 0) or 0),
                        "sugar_g": float(row.get('sugar_g', 0) or 0),
                        "sodium_mg": float(row.get('sodium_mg', 0) or 0),
                        "potassium_mg": float(row.get('potassium_mg', 0) or 0),
                        "vitamin_a_mcg": float(row.get('vitamin_a_mcg', 0) or 0),
                        "vitamin_c_mg": float(row.get('vitamin_c_mg', 0) or 0),
                        "calcium_mg": float(row.get('calcium_mg', 0) or 0),
                        "iron_mg": float(row.get('iron_mg', 0) or 0),
                        "fndds_code": "IND_" + food_name[:3].upper(),
                        "source": "FNDDS RAG Pipeline"
                    }
                    name_lookup[name_lower] = rec
                    portion_lookup[name_lower] = {
                        "food_name": food_name,
                        "standard_portion_grams": std_grams,
                        "portion_unit": portion_unit,
                    }
                    for word in name_lower.replace(",", " ").split():
                        if len(word) >= 4 and word not in name_lookup:
                            name_lookup[word] = rec
                            portion_lookup[word] = portion_lookup[name_lower]
            except Exception as e:
                print(f"ERROR [RAG]: Building lookups: {e}", flush=True)

        # 3. Global CSV
        global_path = "datasets/global_food_nutrition.csv"
        if os.path.exists(global_path):
            try:
                df_g = pd.read_csv(global_path)
                for _, row in df_g.iterrows():
                    name_lower = str(row['food_name']).lower()
                    rec = {
                        "food_name": str(row['food_name']),
                        "calories": float(row['calories']),
                        "protein": float(row['protein']),
                        "carbs": float(row['carbs']),
                        "fat": float(row['fat']),
                        "source": "Nutrition5k"
                    }
                    name_lookup[name_lower] = rec
                    portion_lookup[name_lower] = {
                        "food_name": str(row['food_name']),
                        "standard_portion_grams": 100.0,
                        "portion_unit": "100g",
                    }
                    # Also index by key terms
                    for word in name_lower.split():
                        if len(word) >= 4 and word not in name_lookup:
                            name_lookup[word] = rec
                            portion_lookup[word] = portion_lookup[name_lower]
            except: pass

        return name_lookup, portion_lookup

    # ------------------------------------------------------------------
    # Query methods
    # ------------------------------------------------------------------

    def query_nutrition_by_keywords(self, *keywords: str) -> Optional[Dict[str, Any]]:
        """Try to find a food by exact keyword (e.g. 'biryani'). Works without API key."""
        for k in keywords:
            key = k.strip().lower()
            if not key:
                continue
            if key in self._name_lookup:
                return self._name_lookup[key]
            # try partial: any key that contains the keyword
            for name, rec in self._name_lookup.items():
                if key in name or (len(key) >= 4 and key in name):
                    return rec
        return None

    def search_all_by_keyword(self, query: str) -> List[Dict[str, Any]]:
        """Finds up to 10 foods that match the substring."""
        query = query.strip().lower()
        if not query:
            return []
            
        results = []
        seen_names = set()
        
        for name, rec in self._name_lookup.items():
            # Match directly against the formal food_name to avoid partial word duplication issues
            food_name = rec["food_name"]
            if query in food_name.lower() and food_name not in seen_names:
                results.append(rec)
                seen_names.add(food_name)
                if len(results) >= 10:
                    break
        
        return results

    def query_nutrition(self, query: str) -> Optional[Dict[str, Any]]:
        """
        Finds the closest matching food from the vector database.
        Falls back to keyword lookup if vector search returns weak results.
        """
        # First try keyword (fast, no API needed)
        keyword_result = self.query_nutrition_by_keywords(query)
        
        # FIX: If we have an exact match in our CSV, ALWAYS USE IT over vector similarity search!
        if keyword_result:
            return keyword_result

        if not self.vector_db:
            return None
            
        try:
            results = self.vector_db.similarity_search(query, k=1)
        except Exception:
            return None

        if not results:
            return None
            
        meta = results[0].metadata
        name = meta.get("name") or meta.get("food_name")
        if not name:
            return keyword_result

        return {
            "food_name": str(name),
            "calories": float(meta.get("calories", 0)),
            "protein": float(meta.get("protein", 0)),
            "carbs": float(meta.get("carbs", 0)),
            "fat": float(meta.get("fat", 0)),
            "fiber_g": float(meta.get("fiber_g", 0)),
            "sugar_g": float(meta.get("sugar_g", 0)),
            "sodium_mg": float(meta.get("sodium_mg", 0)),
            "potassium_mg": float(meta.get("potassium_mg", 0)),
            "vitamin_a_mcg": float(meta.get("vitamin_a_mcg", 0)),
            "vitamin_c_mg": float(meta.get("vitamin_c_mg", 0)),
            "calcium_mg": float(meta.get("calcium_mg", 0)),
            "iron_mg": float(meta.get("iron_mg", 0)),
            "fndds_code": meta.get("code", "unknown"),
            "source": "FNDDS RAG Pipeline"
        }

    # ------------------------------------------------------------------
    # DietAI24-style portion-weight grounding
    # ------------------------------------------------------------------

    def query_portion_weight(self, food_name: str, portion_description: str = "") -> Dict[str, Any]:
        """
        DietAI24 approach: Given a food name and a VLM portion description,
        calculate the actual weight in grams using the FNDDS/CSV portion database.

        Instead of trusting VLM weight guesses, we:
        1. Look up the standard portion weight for the food (e.g., Idli = 40g/piece)
        2. Parse the VLM's portion count (e.g., "3 pieces" -> 3)
        3. Calculate: weight = count × standard_grams_per_unit

        Returns:
            {
                "food_name": str,
                "estimated_weight_grams": float,
                "portion_description": str,
                "standard_portion_grams": float,
                "portion_count": float,
                "grounded": bool   # True if we used DB data, False if using VLM estimate
            }
        """
        food_lower = food_name.lower().strip()

        # Try exact match first, then fuzzy
        portion_info = self._find_portion_info(food_lower)

        portion_count = parse_portion_count(portion_description) if portion_description else 1.0

        if portion_info and portion_info["standard_portion_grams"] > 0:
            # GROUNDED estimation: use database portion weights
            std_grams = portion_info["standard_portion_grams"]
            
            # Catch raw gram inputs (e.g. "550 grams")
            desc_lower = (portion_description or "").lower()
            if "gram" in desc_lower or " g " in f" {desc_lower} " or desc_lower.endswith("g") or desc_lower.endswith("gms"):
                estimated_weight = round(portion_count, 1)
            else:
                estimated_weight = round(portion_count * std_grams, 1)

            return {
                "food_name": portion_info["food_name"],
                "estimated_weight_grams": estimated_weight,
                "portion_description": portion_description or portion_info["portion_unit"],
                "standard_portion_grams": std_grams,
                "portion_count": portion_count,
                "grounded": True,
            }

        # DENSITY FALLBACK estimation (Phase 1 Heuristic)
        density = self._get_density(food_lower)
        if density > 0:
            # Heuristic volume based on portion description unit
            unit = normalize_portion_unit(portion_description)
            volume_cm3 = 200  # Default 1 serving = 200 cm3
            if "bowl" in unit or "cup" in unit:
                volume_cm3 = 250
            elif "piece" in unit:
                volume_cm3 = 70
            elif "plate" in unit:
                volume_cm3 = 450
            elif "glass" in unit:
                volume_cm3 = 240
            
            estimated_weight = round(portion_count * volume_cm3 * density, 1)
            
            return {
                "food_name": food_name,
                "estimated_weight_grams": estimated_weight,
                "portion_description": portion_description or f"{portion_count} serving",
                "standard_portion_grams": round(volume_cm3 * density, 1),
                "portion_count": portion_count,
                "grounded": True, # Pseudo-grounded via density
            }

        # UNGROUNDED: no DB match, return zeros (let caller use VLM estimate)
        return {
            "food_name": food_name,
            "estimated_weight_grams": 0.0,
            "portion_description": portion_description or "Standard Serving",
            "standard_portion_grams": 0.0,
            "portion_count": portion_count,
            "grounded": False,
        }

    def _get_density(self, food_lower: str) -> float:
        if food_lower in self._density_lookup:
            return self._density_lookup[food_lower]
        # Check fuzzy logic or sub-words
        for k, v in self._density_lookup.items():
            if k in food_lower or food_lower in k:
                return v
        return 0.0

    def query_weight_from_volume(self, food_name: str, volume_cm3: float) -> Dict[str, Any]:
        """
        Phase 3: Convert a measured 3D volume (cm³) to weight (g) using density table.
        This is the most accurate weight estimation method — used when depth estimation succeeds.
        
        Returns:
            {
                "food_name": str,
                "estimated_weight_grams": float,
                "volume_cm3": float,
                "density_g_cm3": float,
                "method": "volumetric_depth"
            }
        """
        food_lower = food_name.lower().strip()
        density = self._get_density(food_lower)

        if density <= 0:
            # Default density for unknown foods (roughly water-like)
            density = 0.85
            print(f"INFO [RAG]: No density for '{food_name}', using default {density} g/cm³", flush=True)

        weight_grams = round(volume_cm3 * density, 1)

        return {
            "food_name": food_name,
            "estimated_weight_grams": weight_grams,
            "volume_cm3": round(volume_cm3, 1),
            "density_g_cm3": density,
            "method": "volumetric_depth",
        }

    def _find_portion_info(self, food_lower: str) -> Optional[Dict]:
        """Find portion info by exact match, then fuzzy match."""
        # Exact
        if food_lower in self._portion_lookup:
            return self._portion_lookup[food_lower]

        # Fuzzy match against all keys
        all_keys = list(self._portion_lookup.keys())
        matches = difflib.get_close_matches(food_lower, all_keys, n=1, cutoff=0.6)
        if matches:
            return self._portion_lookup[matches[0]]

        # Word-overlap fallback
        food_words = set(food_lower.replace("-", " ").replace("_", " ").split())
        for key, info in self._portion_lookup.items():
            key_words = set(key.replace("-", " ").replace("_", " ").split())
            if food_words & key_words and len(food_words & key_words) >= 1:
                return info

        return None

    def scale_nutrition_by_weight(
        self, nutrition: Dict[str, Any], standard_portion_grams: float,
        actual_weight_grams: float
    ) -> Dict[str, Any]:
        """
        Scale nutrition values. 
        Most food databases (FNDDS, IFCT) provide values PER 100g.
        
        If CSV says "Biryani: 190 cal" (implicitly per 100g) and VLM sees 500g,
        scaled calories = 190 * (500 / 100) = 950 kcal.
        """
        if actual_weight_grams <= 0:
            return nutrition

        # We assume nutrient values in our database are PER 100g
        ratio = actual_weight_grams / 100.0
        scaled = dict(nutrition)

        nutrient_keys = [
            "calories", "protein", "carbs", "fat",
            "fiber_g", "sugar_g", "sodium_mg", "potassium_mg",
            "vitamin_a_mcg", "vitamin_c_mg", "calcium_mg", "iron_mg"
        ]
        for key in nutrient_keys:
            if key in scaled and isinstance(scaled[key], (int, float)):
                scaled[key] = round(float(scaled[key]) * ratio, 1)

        return scaled


# ---------------------------------------------------------------------------
# Singleton instance
# ---------------------------------------------------------------------------

_rag_instance: Optional[RAGService] = None

def get_rag_service() -> RAGService:
    """Get or create the singleton RAG service instance."""
    global _rag_instance
    if _rag_instance is None:
        print("INFO [RAG]: Initializing DietAI24-style RAG service...", flush=True)
        _rag_instance = RAGService()
        print(f"INFO [RAG]: Ready. {len(_rag_instance._name_lookup)} foods indexed, "
              f"{len(_rag_instance._portion_lookup)} portion entries.", flush=True)
    return _rag_instance
