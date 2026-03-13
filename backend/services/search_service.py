from typing import List, Dict, Any
from services.rag_service import RAGService

_rag_search_instance = None

def get_rag_search():
    global _rag_search_instance
    if _rag_search_instance is None:
        _rag_search_instance = RAGService()
    return _rag_search_instance

EMOJI_MAP = {
    "milk": "🥛",
    "pizza": "🍕",
    "beef": "🥩",
    "steak": "🥩",
    "rice": "🍚",
    "chicken": "🍗",
    "apple": "🍎",
    "banana": "🍌",
    "egg": "🥚",
    "spaghetti": "🍝",
    "pasta": "🍝",
    "salad": "🥗",
    "salmon": "🐟",
    "fish": "🐟"
}

def _get_emoji(name: str) -> str:
    name = name.lower()
    for key, emoji in EMOJI_MAP.items():
        if key in name:
            return emoji
    return "🍽"

def search_foods(query: str) -> List[Dict[str, Any]]:
    """
    Searches for food items by name using the RAG vector store.
    """
    rag = get_rag_search()
    if not rag.vector_db:
        return []
        
    # Search for top 5 matches
    docs = rag.vector_db.similarity_search(query, k=5)
    
    results = []
    for doc in docs:
        meta = doc.metadata
        name = meta.get("name") or meta.get("food_name")
        if not name:
            continue
        results.append({
            "name": str(name),
            "calories": float(meta.get("calories", 0)),
            "protein": float(meta.get("protein", 0)),
            "carbs": float(meta.get("carbs", 0)),
            "fat": float(meta.get("fat", 0)),
            "emoji": _get_emoji(str(name))
        })
    return results
