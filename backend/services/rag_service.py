import os
import pandas as pd
import numpy as np
from typing import List, Dict, Any, Optional
from langchain_community.vectorstores import Chroma
from langchain_openai import OpenAIEmbeddings
from langchain_community.embeddings import DeterministicFakeEmbedding
from langchain_core.documents import Document

# Paths 
FNDDS_EXCEL = os.getenv("FNDDS_DATA_PATH", "FNDDS/2019-2020 FNDDS At A Glance - FNDDS Nutrient Values.xlsx")
FNDDS_DESC_EXCEL = os.getenv("FNDDS_DESC_PATH", "FNDDS/2019-2020 FNDDS At A Glance - Foods and Beverages.xlsx")
CHROMA_DIR = os.getenv("CHROMA_DB_PATH", "db/chroma")

class RAGService:
    def __init__(self):
        self.use_fake = True  # Default to fake if no API key
        if os.getenv("OPENAI_API_KEY"):
            self.embeddings = OpenAIEmbeddings()
            self.use_fake = False
        else:
            self.embeddings = DeterministicFakeEmbedding(size=1536)

        self._name_lookup = {}  # keyword -> nutrition dict for fallback when vector search is unreliable
        self.vector_db = None
        self._initialize_db()

    def _initialize_db(self):
        """
        Loads FNDDS data and creates/loads a vector database.
        """
        # Ensure path exists
        os.makedirs(CHROMA_DIR, exist_ok=True)
        
        if os.path.exists(os.path.join(CHROMA_DIR, "index")):
            self.vector_db = Chroma(persist_directory=CHROMA_DIR, embedding_function=self.embeddings)
            self._name_lookup = self._build_name_lookup()
            return

        # Attempt to load data for indexing
        documents, self._name_lookup = self._get_initial_docs()
        self.vector_db = Chroma.from_documents(
            documents=documents,
            embedding=self.embeddings,
            persist_directory=CHROMA_DIR
        )

    def _get_initial_docs(self) -> tuple:
        """Provides a set of real-world food items from FNDDS and Indian datasets. Also builds name_lookup for keyword fallback."""
        name_lookup = {}
        # 1. Base FNDDS Data (Western/Global)
        base_data = [
            {"code": "11111111", "name": "Milk, whole", "calories": 61, "protein": 3.15, "carbs": 4.8, "fat": 3.25},
            {"code": "11111211", "name": "Milk, reduced fat", "calories": 50, "protein": 3.3, "carbs": 4.8, "fat": 1.99},
            {"code": "53108200", "name": "Pizza", "calories": 266, "protein": 11.4, "carbs": 33.3, "fat": 9.7},
            {"code": "23111000", "name": "Beef Steak", "calories": 204, "protein": 30.2, "carbs": 0, "fat": 8.5},
            {"code": "72101100", "name": "Rice, white", "calories": 130, "protein": 2.7, "carbs": 28.2, "fat": 0.3},
            {"code": "24101000", "name": "Chicken breast", "calories": 165, "protein": 31, "carbs": 0, "fat": 3.6},
            {"code": "41101010", "name": "Apple", "calories": 52, "protein": 0.26, "carbs": 13.8, "fat": 0.17},
            {"code": "41101020", "name": "Banana", "calories": 89, "protein": 1.09, "carbs": 22.8, "fat": 0.33},
            {"code": "11111100", "name": "Egg", "calories": 155, "protein": 12.6, "carbs": 1.1, "fat": 10.6},
            {"code": "73101010", "name": "Spaghetti", "calories": 158, "protein": 5.8, "carbs": 30.9, "fat": 0.9}
        ]
        
        docs = []
        for item in base_data:
            content = f"The image shows {item['name']}. Nutritional values: {item['calories']} kcal."
            docs.append(Document(
                page_content=content,
                metadata={**item, "source": "FNDDS"}
            ))
            name_lookup[item["name"].lower()] = {
                "food_name": item["name"],
                "calories": float(item["calories"]),
                "protein": float(item["protein"]),
                "carbs": float(item["carbs"]),
                "fat": float(item["fat"]),
                "fndds_code": item["code"],
                "source": "FNDDS RAG Pipeline"
            }

        # 2. Indian Food Expansion (USP)
        indian_path = "datasets/indian_food_nutrition.csv"
        if os.path.exists(indian_path):
            try:
                df = pd.read_csv(indian_path)
                for _, row in df.iterrows():
                    content = f"Indian dish: {row['food_name']}. {row['description']}. Nutrition: {row['calories']} kcal."
                    meta = {
                        "name": row['food_name'],
                        "calories": row['calories'],
                        "protein": row['protein'],
                        "carbs": row['carbs'],
                        "fat": row['fat'],
                        "code": "IND_" + str(row['food_name'][:3]).upper(),
                        "source": "IFCT_Custom"
                    }
                    docs.append(Document(page_content=content, metadata=meta))
                    name_lower = str(row['food_name']).lower()
                    name_lookup[name_lower] = {
                        "food_name": meta["name"],
                        "calories": float(meta["calories"]),
                        "protein": float(meta["protein"]),
                        "carbs": float(meta["carbs"]),
                        "fat": float(meta["fat"]),
                        "fndds_code": meta["code"],
                        "source": "FNDDS RAG Pipeline"
                    }
                    # Also index by key terms (e.g. "biryani" -> Chicken Biryani)
                    for word in name_lower.replace(",", " ").split():
                        if len(word) >= 4 and word not in name_lookup:
                            name_lookup[word] = name_lookup[name_lower]
            except Exception as e:
                print(f"Error loading Indian dataset: {e}")

        return docs, name_lookup

    def _build_name_lookup(self) -> dict:
        """Build keyword -> nutrition dict from base data + Indian CSV (for fallback when vector search fails)."""
        name_lookup = {}
        base_data = [
            {"code": "11111111", "name": "Milk, whole", "calories": 61, "protein": 3.15, "carbs": 4.8, "fat": 3.25},
            {"code": "11111211", "name": "Milk, reduced fat", "calories": 50, "protein": 3.3, "carbs": 4.8, "fat": 1.99},
            {"code": "53108200", "name": "Pizza", "calories": 266, "protein": 11.4, "carbs": 33.3, "fat": 9.7},
            {"code": "23111000", "name": "Beef Steak", "calories": 204, "protein": 30.2, "carbs": 0, "fat": 8.5},
            {"code": "72101100", "name": "Rice, white", "calories": 130, "protein": 2.7, "carbs": 28.2, "fat": 0.3},
            {"code": "24101000", "name": "Chicken breast", "calories": 165, "protein": 31, "carbs": 0, "fat": 3.6},
            {"code": "41101010", "name": "Apple", "calories": 52, "protein": 0.26, "carbs": 13.8, "fat": 0.17},
            {"code": "41101020", "name": "Banana", "calories": 89, "protein": 1.09, "carbs": 22.8, "fat": 0.33},
            {"code": "11111100", "name": "Egg", "calories": 155, "protein": 12.6, "carbs": 1.1, "fat": 10.6},
            {"code": "73101010", "name": "Spaghetti", "calories": 158, "protein": 5.8, "carbs": 30.9, "fat": 0.9}
        ]
        for item in base_data:
            name_lookup[item["name"].lower()] = {
                "food_name": item["name"],
                "calories": float(item["calories"]),
                "protein": float(item["protein"]),
                "carbs": float(item["carbs"]),
                "fat": float(item["fat"]),
                "fndds_code": item["code"],
                "source": "FNDDS RAG Pipeline"
            }
        indian_path = "datasets/indian_food_nutrition.csv"
        if os.path.exists(indian_path):
            try:
                df = pd.read_csv(indian_path)
                for _, row in df.iterrows():
                    name_lower = str(row['food_name']).lower()
                    rec = {
                        "food_name": str(row['food_name']),
                        "calories": float(row['calories']),
                        "protein": float(row['protein']),
                        "carbs": float(row['carbs']),
                        "fat": float(row['fat']),
                        "fndds_code": "IND_" + str(row['food_name'])[:3].upper(),
                        "source": "FNDDS RAG Pipeline"
                    }
                    name_lookup[name_lower] = rec
                    for word in name_lower.replace(",", " ").split():
                        if len(word) >= 4 and word not in name_lookup:
                            name_lookup[word] = rec
            except Exception as e:
                print(f"Error building name lookup: {e}")
        return name_lookup

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

    def query_nutrition(self, query: str) -> Optional[Dict[str, Any]]:
        """
        Finds the closest matching food from the database.
        """
        if not self.vector_db:
            return None
            
        results = self.vector_db.similarity_search(query, k=1)
        if not results:
            return None
            
        meta = results[0].metadata
        name = meta.get("name") or meta.get("food_name")
        if not name:
            return None
        return {
            "food_name": str(name),
            "calories": float(meta.get("calories", 0)),
            "protein": float(meta.get("protein", 0)),
            "carbs": float(meta.get("carbs", 0)),
            "fat": float(meta.get("fat", 0)),
            "fndds_code": meta.get("code", "unknown"),
            "source": "FNDDS RAG Pipeline"
        }
