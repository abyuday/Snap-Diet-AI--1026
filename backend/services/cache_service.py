"""
cache_service.py – Async Redis cache layer for DietitianAI.

Design decisions:
  - Uses redis-py asyncio client (no extra deps, ships with redis[hiredis]).
  - Gracefully degrades to a no-op if Redis is unavailable (so the API
    never hard-fails because of a cache miss/outage).
  - Separate TTLs per endpoint type:
      /search  →  1 hour  (static CSV data, rarely changes)
      /chat    →  15 min  (user-specific but short conversation window)
      /analyze-barcode → 24 hrs (OpenFoodFacts product data doesn't change)
  - Cache key = sha256(endpoint + sorted JSON of inputs) so semantically
    identical queries always hit the same key regardless of key order.
"""

import os
import json
import hashlib
import logging
from typing import Any, Optional

logger = logging.getLogger("cache_service")

# TTL constants (seconds)
TTL_SEARCH = 3600          # 1 hour
TTL_CHAT = 900             # 15 minutes
TTL_BARCODE = 86400        # 24 hours
TTL_DEFAULT = 1800         # 30 minutes fallback


class CacheService:
    def __init__(self):
        self._client = None
        self._available = False
        self._redis_url = os.getenv("REDIS_URL", "redis://localhost:6379")

    async def connect(self) -> None:
        """Attempt to connect to Redis. Silently disables cache if unavailable."""
        try:
            import redis.asyncio as aioredis
            self._client = aioredis.from_url(
                self._redis_url,
                encoding="utf-8",
                decode_responses=True,
                socket_connect_timeout=2,
                socket_timeout=2,
            )
            # Test connection
            await self._client.ping()
            self._available = True
            logger.info(f"[Cache] Connected to Redis at {self._redis_url}")
        except Exception as e:
            self._available = False
            self._client = None
            logger.warning(f"[Cache] Redis unavailable – operating in passthrough mode. Reason: {e}")

    async def close(self) -> None:
        if self._client:
            await self._client.aclose()

    # ------------------------------------------------------------------ #
    #  Public interface
    # ------------------------------------------------------------------ #

    def make_key(self, namespace: str, payload: Any) -> str:
        """Deterministic SHA-256 cache key from namespace + payload."""
        raw = json.dumps(payload, sort_keys=True, default=str)
        digest = hashlib.sha256(f"{namespace}:{raw}".encode()).hexdigest()
        return f"dietitian:{namespace}:{digest[:24]}"

    async def get(self, key: str) -> Optional[Any]:
        """Return cached value (parsed JSON) or None."""
        if not self._available or not self._client:
            return None
        try:
            data = await self._client.get(key)
            if data:
                logger.debug(f"[Cache] HIT  {key}")
                return json.loads(data)
            logger.debug(f"[Cache] MISS {key}")
            return None
        except Exception as e:
            logger.warning(f"[Cache] get() failed: {e}")
            return None

    async def set(self, key: str, value: Any, ttl: int = TTL_DEFAULT) -> None:
        """Store value as JSON with a TTL. Silently swallowed on failure."""
        if not self._available or not self._client:
            return
        try:
            await self._client.setex(key, ttl, json.dumps(value, default=str))
            logger.debug(f"[Cache] SET  {key}  (ttl={ttl}s)")
        except Exception as e:
            logger.warning(f"[Cache] set() failed: {e}")

    async def delete(self, key: str) -> None:
        if not self._available or not self._client:
            return
        try:
            await self._client.delete(key)
        except Exception:
            pass

    async def flush_namespace(self, namespace: str) -> int:
        """Delete all keys matching a namespace prefix. Returns count deleted."""
        if not self._available or not self._client:
            return 0
        pattern = f"dietitian:{namespace}:*"
        try:
            keys = await self._client.keys(pattern)
            if keys:
                return await self._client.delete(*keys)
            return 0
        except Exception:
            return 0

    @property
    def is_available(self) -> bool:
        return self._available


# Singleton – imported by main.py
cache = CacheService()
