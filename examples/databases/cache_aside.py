"""
Cache-aside (lazy loading) pattern with Redis (ElastiCache) in front of a database.

pip install redis
Run locally against Docker:  docker run -p 6379:6379 redis:7
On AWS set REDIS_HOST to the ElastiCache primary endpoint.
"""
import json
import os
import time

import redis

r = redis.Redis(host=os.environ.get("REDIS_HOST", "localhost"), port=6379, decode_responses=True)
TTL_SECONDS = 300


def slow_db_query(user_id: str) -> dict:
    """Pretend this is an expensive SQL query on RDS."""
    time.sleep(1.0)
    return {"id": user_id, "name": "Kanishka", "plan": "pro"}


def get_user(user_id: str) -> dict:
    key = f"user:{user_id}"
    cached = r.get(key)
    if cached:                                   # 1. HIT -> return straight from memory
        return json.loads(cached)
    user = slow_db_query(user_id)                # 2. MISS -> go to the database
    r.set(key, json.dumps(user), ex=TTL_SECONDS)  # 3. store with TTL for next time
    return user


def update_user(user_id: str, data: dict) -> None:
    # write to the DB first (omitted), then invalidate so the next read refreshes the cache
    r.delete(f"user:{user_id}")


if __name__ == "__main__":
    for attempt in (1, 2):
        start = time.perf_counter()
        get_user("42")
        print(f"call {attempt}: {(time.perf_counter() - start) * 1000:.1f} ms")
    # call 1: ~1000 ms (miss)   call 2: ~1 ms (hit)
