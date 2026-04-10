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
    Searches for food items by exact name matching first, avoiding dirty vector similarities.
    """
    rag = get_rag_search()
    
    # Use exact word search from CSV rather than fuzzy vector DB
    matched_records = rag.search_all_by_keyword(query)
    
    if not matched_records and rag.vector_db:
        # Fallback to vector search if totally unknown
        try:
            docs = rag.vector_db.similarity_search(query, k=5)
            matched_records = []
            for doc in docs:
                matched_records.append(doc.metadata)
        except Exception:
            pass
            
    results = []
    seen = set()
    for meta in matched_records:
        name = meta.get("name") or meta.get("food_name")
        if not name or name in seen:
            continue
        seen.add(name)
        results.append({
            "name": str(name),
            "calories": float(meta.get("calories", 0)),
            "protein": float(meta.get("protein", 0)),
            "carbs": float(meta.get("carbs", 0)),
            "fat": float(meta.get("fat", 0)),
            "emoji": _get_emoji(str(name))
        })
    return results
