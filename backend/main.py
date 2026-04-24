from fastapi import FastAPI, UploadFile, File, Form, HTTPException, Depends, status
from fastapi.security import OAuth2PasswordBearer
from fastapi.middleware.cors import CORSMiddleware
import json
from pydantic import BaseModel, EmailStr
import shutil
import os
import mimetypes
import uuid
import re
from typing import Optional, List
from dotenv import load_dotenv
from services.cache_service import cache, TTL_SEARCH, TTL_CHAT, TTL_BARCODE
from database import user_collection, user_helper
from services.auth_service import verify_password, get_password_hash, create_access_token, decode_token

# Load environment variables from .env
load_dotenv()

from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

# Services will be imported lazily within endpoints to prevent startup hangs
# from services.food_analyzer import analyze_food_image, predict_food
# from services.search_service import search_foods
# from services.chat_service import get_chat_response

app = FastAPI(title="SnapDiet AI API", version="1.0.0")

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request, exc):
    print(f"ERROR: Validation failed for {request.url}: {exc.errors()}", flush=True)
    return JSONResponse(
        status_code=422,
        content={"detail": exc.errors(), "body": str(exc.body)},
    )

# CORS: "*" requires allow_credentials=False; set CORS_ORIGINS for specific origins
_cors_origins = [o.strip() for o in os.getenv("CORS_ORIGINS", "*").split(",") if o.strip()] or ["*"]
app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins,
    allow_credentials="*" not in _cors_origins,
    allow_methods=["*"],
    allow_headers=["*"],
)

class NutritionResponse(BaseModel):
    food_name: str
    portion_size: str
    estimated_weight_grams: Optional[float] = 0.0
    calories: float
    protein: float
    carbs: float
    fat: float
    fiber_g: Optional[float] = 0.0
    sugar_g: Optional[float] = 0.0
    sodium_mg: Optional[float] = 0.0
    potassium_mg: Optional[float] = 0.0
    vitamin_a_mcg: Optional[float] = 0.0
    vitamin_c_mg: Optional[float] = 0.0
    calcium_mg: Optional[float] = 0.0
    iron_mg: Optional[float] = 0.0
    raw_data: Optional[dict] = None

class SearchResult(BaseModel):
    name: str
    calories: float
    protein: float
    carbs: float
    fat: float
    emoji: str
    fiber_g: Optional[float] = 0.0
    sugar_g: Optional[float] = 0.0
    sodium_mg: Optional[float] = 0.0
    potassium_mg: Optional[float] = 0.0
    vitamin_a_mcg: Optional[float] = 0.0
    vitamin_c_mg: Optional[float] = 0.0
    calcium_mg: Optional[float] = 0.0
    iron_mg: Optional[float] = 0.0
    standard_portion_grams: Optional[float] = 0.0

class ChatRequest(BaseModel):
    message: str
    profile: Optional[dict] = {}
    history: Optional[List[dict]] = []
    goals: Optional[dict] = {}

class ChatResponse(BaseModel):
    reply: str
    recommendations: List[dict]
    recipes: Optional[List[dict]] = []
    logged_foods: Optional[List[dict]] = []

import threading

def _warmup_services():
    """Import heavy models in background after server binds to port."""
    try:
        print("INFO: Starting background warmup of heavy ML services...", flush=True)
        # 1. Warm up RAG and Food database
        from services.rag_service import get_rag_service
        get_rag_service()
        
        # 2. Warm up Volume Service (Depth model)
        from services.volume_service import _load_depth_model
        _load_depth_model()
        
        # 3. Warm up VLM Client and local analyzer bits
        from services.food_analyzer import get_local_classifier, _client, _AI_MODEL
        get_local_classifier()
        if _client:
             try:
                 print(f"INFO: Waking up Cloud VLM ({_AI_MODEL})...", flush=True)
                 _client.chat.completions.create(
                     model=_AI_MODEL,
                     messages=[{"role": "user", "content": "ping"}],
                     max_tokens=1,
                     timeout=5.0
                 )
             except Exception:
                 pass

        # 4. Warm up YOLO detector
        from services.yolo_service import get_yolo_model
        get_yolo_model()
        
        print("INFO: Background warmup complete. All heavy services pre-loaded.", flush=True)
    except Exception as e:
        print(f"WARNING: Background warmup failed: {e}", flush=True)

@app.on_event("startup")
async def startup_event():
    # Connect Redis cache first (non-blocking, degrades gracefully)
    await cache.connect()
    # Then warm up heavy ML models in background
    threading.Thread(target=_warmup_services, daemon=True).start()

@app.on_event("shutdown")
async def shutdown_event():
    await cache.close()

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="api/auth/login")

async def get_current_user(token: str = Depends(oauth2_scheme)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    payload = decode_token(token)
    if payload is None:
        raise credentials_exception
    email: str = payload.get("sub")
    if email is None:
        raise credentials_exception
    user = await user_collection.find_one({"email": email})
    if user is None:
        raise credentials_exception
    return user_helper(user)

class UserSignup(BaseModel):
    name: str
    email: EmailStr
    password: str
    calorieGoal: Optional[int] = 2000
    proteinGoal: Optional[int] = 120
    carbsGoal: Optional[int] = 250
    fatGoal: Optional[int] = 70

class UserLogin(BaseModel):
    email: EmailStr
    password: str
    
class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: dict

@app.post("/api/auth/signup", response_model=TokenResponse)
async def signup(user: UserSignup):
    existing = await user_collection.find_one({"email": user.email})
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")
    
    user_dict = {
        "name": user.name,
        "email": user.email,
        "password": get_password_hash(user.password),
        "rank": "Nutrition Novice",
        "goals": {
            "calorieGoal": user.calorieGoal,
            "proteinGoal": user.proteinGoal,
            "carbsGoal": user.carbsGoal,
            "fatGoal": user.fatGoal,
            "waterGoal": 2500,
        }
    }
    new_user = await user_collection.insert_one(user_dict)
    created_user = await user_collection.find_one({"_id": new_user.inserted_id})
    token = create_access_token(data={"sub": created_user["email"]})
    return {"access_token": token, "user": user_helper(created_user)}

@app.post("/api/auth/login", response_model=TokenResponse)
async def login(creds: UserLogin):
    user = await user_collection.find_one({"email": creds.email})
    if not user or not verify_password(creds.password, user["password"]):
        raise HTTPException(status_code=401, detail="Incorrect email or password")
    token = create_access_token(data={"sub": user["email"]})
    return {"access_token": token, "user": user_helper(user)}

@app.get("/api/auth/me")
async def get_me(current_user: dict = Depends(get_current_user)):
    return current_user

@app.get("/")
def read_root():
    return {"message": "API V2 READY"}

@app.get("/search", response_model=List[SearchResult])
async def search(q: str):
    """
    Search for food items by name. Results are cached in Redis for 1 hour.
    """
    cache_key = cache.make_key("search", {"q": q.lower().strip()})
    cached = await cache.get(cache_key)
    if cached is not None:
        return cached

    from services.search_service import search_foods
    results = search_foods(q)
    await cache.set(cache_key, results, TTL_SEARCH)
    return results

@app.get("/analyze-barcode", response_model=NutritionResponse)
async def analyze_barcode(barcode: str):
    """
    Look up a food item by barcode via OpenFoodFacts, returning full nutrition data.
    Results are cached in Redis for 24 hours (product data rarely changes).
    Endpoint: GET /analyze-barcode?barcode=<EAN13>
    """
    cache_key = cache.make_key("barcode", {"barcode": barcode})
    cached = await cache.get(cache_key)
    if cached is not None:
        return cached

    import httpx
    url = f"https://world.openfoodfacts.org/api/v0/product/{barcode}.json"
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.get(url)
        data = resp.json()
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"OpenFoodFacts unreachable: {exc}")

    if data.get("status") != 1 or "product" not in data:
        raise HTTPException(status_code=404, detail="Barcode not found in OpenFoodFacts database.")

    product = data["product"]
    nutrients = product.get("nutriments", {})
    food_name = (
        product.get("product_name_en")
        or product.get("product_name")
        or product.get("generic_name")
        or "Unknown Product"
    )

    def _n(key: str, fallback: float = 0.0) -> float:
        # OpenFoodFacts uses _100g suffix for per-100g values
        return float(nutrients.get(f"{key}_100g", nutrients.get(key, fallback)) or fallback)

    result = NutritionResponse(
        food_name=food_name,
        portion_size="100g",
        estimated_weight_grams=100.0,
        calories=_n("energy-kcal"),
        protein=_n("proteins"),
        carbs=_n("carbohydrates"),
        fat=_n("fat"),
        fiber_g=_n("fiber"),
        sugar_g=_n("sugars"),
        sodium_mg=_n("sodium") * 1000,
        potassium_mg=_n("potassium") * 1000,
        vitamin_a_mcg=_n("vitamin-a", 0.0),
        vitamin_c_mg=_n("vitamin-c", 0.0),
        calcium_mg=_n("calcium") * 1000,
        iron_mg=_n("iron") * 1000,
        raw_data={
            "barcode": barcode,
            "source": "OpenFoodFacts",
            "brand": product.get("brands", ""),
            "image_url": product.get("image_url", ""),
        }
    )
    await cache.set(cache_key, result.dict(), TTL_BARCODE)
    return result


def _sanitize_filename(filename: Optional[str]) -> str:
    """Safe filename to prevent path traversal. Falls back to UUID if invalid."""
    if not filename or not filename.strip():
        return f"{uuid.uuid4().hex}.jpg"
    # Remove path components, keep only basename
    safe = os.path.basename(filename).strip()
    # Strip dangerous chars
    safe = re.sub(r"[^\w\-\.]", "_", safe) or uuid.uuid4().hex
    return safe[:64] or f"{uuid.uuid4().hex}.jpg"


@app.post("/analyze", response_model=NutritionResponse)
def analyze_food(file: UploadFile = File(...)):
    """
    Endpoint to receive a food image, analyze it using GPT-4V,
    determine the food code, estimate portion size, and calculate nutrition.
    """
    safe_filename = _sanitize_filename(file.filename)
    content_type = file.content_type
    if not content_type or content_type == "application/octet-stream":
        content_type = (mimetypes.guess_type(safe_filename)[0] or "application/octet-stream")

    if not content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image.")

    temp_dir = "temp_uploads"
    os.makedirs(temp_dir, exist_ok=True)
    file_path = os.path.join(temp_dir, safe_filename)

    try:
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        from services.food_analyzer import analyze_food_image
        result = analyze_food_image(file_path)
        return result
    except Exception:
        raise HTTPException(status_code=500, detail="Image analysis failed.")
    finally:
        if os.path.exists(file_path):
            try:
                os.remove(file_path)
            except OSError:
                pass


@app.post("/predict")
def predict(file: UploadFile = File(...)):
    """
    Endpoint to classify a food image using HuggingFace model
    and return nutrition info.
    Returns: {food, confidence, nutrition}
    """
    safe_filename = _sanitize_filename(file.filename)
    content_type = file.content_type
    if not content_type or content_type == "application/octet-stream":
        content_type = (mimetypes.guess_type(safe_filename)[0] or "application/octet-stream")

    if not content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image.")

    temp_dir = "temp_uploads"
    os.makedirs(temp_dir, exist_ok=True)
    file_path = os.path.join(temp_dir, safe_filename)

    try:
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        from services.food_analyzer import predict_food
        result = predict_food(file_path)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Prediction failed: {str(e)}")
    finally:
        if os.path.exists(file_path):
            try:
                os.remove(file_path)
            except OSError:
                pass


@app.post("/analyze-multi", response_model=NutritionResponse)
def analyze_food_multi(files: List[UploadFile] = File(...)):
    """
    Endpoint to receive multiple food images (different angles),
    analyze them together for better accuracy in food identification
    and portion/weight estimation.
    """
    if not files:
        raise HTTPException(status_code=400, detail="At least one image is required.")
    if len(files) > 6:
        raise HTTPException(status_code=400, detail="Maximum 6 images allowed.")

    temp_dir = "temp_uploads"
    os.makedirs(temp_dir, exist_ok=True)
    saved_paths = []

    try:
        for f in files:
            safe_name = _sanitize_filename(f.filename)
            ct = f.content_type
            if not ct or ct == "application/octet-stream":
                ct = mimetypes.guess_type(safe_name)[0] or "application/octet-stream"
            if not ct.startswith("image/"):
                raise HTTPException(status_code=400, detail=f"File '{f.filename}' is not an image.")

            # Add unique prefix to avoid name collisions
            unique_name = f"{uuid.uuid4().hex[:8]}_{safe_name}"
            fpath = os.path.join(temp_dir, unique_name)
            with open(fpath, "wb") as buffer:
                shutil.copyfileobj(f.file, buffer)
            saved_paths.append(fpath)

        from services.food_analyzer import analyze_food_images_multi
        result = analyze_food_images_multi(saved_paths)
        return result
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=500, detail="Multi-image analysis failed.")
    finally:
        for p in saved_paths:
            if os.path.exists(p):
                try:
                    os.remove(p)
                except OSError:
                    pass


class TextAnalyzeRequest(BaseModel):
    query: str

@app.post("/analyze-text", response_model=NutritionResponse)
def analyze_food_text(req: TextAnalyzeRequest):
    """
    Endpoint for Manual Food Logging via text.
    Takes a natural language query like "2 bowls of dal tadka" and returns scaled nutrition.
    """
    if not req.query or not req.query.strip():
        raise HTTPException(status_code=400, detail="Text query cannot be empty.")

    try:
        from services.food_analyzer import predict_food_text, _prediction_to_response
        prediction = predict_food_text(req.query.strip())
        return _prediction_to_response(prediction)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Text analysis failed: {str(e)}")


@app.post("/analyze-ar", response_model=NutritionResponse)
def analyze_food_ar(files: List[UploadFile] = File(...), pose_data: Optional[str] = Form(None)):
    """
    Endpoint for AR-enhanced multiple food images analysis.
    Takes images and an optional JSON string containing camera pose metadata.
    """
    if not files:
        raise HTTPException(status_code=400, detail="At least one image is required.")
    if len(files) > 6:
        raise HTTPException(status_code=400, detail="Maximum 6 images allowed.")

    parsed_pose_data = None
    if pose_data:
        try:
            parsed_pose_data = json.loads(pose_data)
        except json.JSONDecodeError:
            print("WARNING: Failed to parse pose_data JSON", flush=True)

    temp_dir = "temp_uploads"
    os.makedirs(temp_dir, exist_ok=True)
    saved_paths = []

    try:
        for f in files:
            safe_name = _sanitize_filename(f.filename)
            ct = f.content_type
            if not ct or ct == "application/octet-stream":
                ct = mimetypes.guess_type(safe_name)[0] or "application/octet-stream"
            if not ct.startswith("image/"):
                raise HTTPException(status_code=400, detail=f"File '{f.filename}' is not an image.")

            unique_name = f"{uuid.uuid4().hex[:8]}_{safe_name}"
            fpath = os.path.join(temp_dir, unique_name)
            with open(fpath, "wb") as buffer:
                shutil.copyfileobj(f.file, buffer)
            saved_paths.append(fpath)

        from services.food_analyzer import analyze_food_images_multi
        result = analyze_food_images_multi(saved_paths, pose_data=parsed_pose_data)
        return result
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=500, detail="AR-enhanced multi-image analysis failed.")
    finally:
        for p in saved_paths:
            if os.path.exists(p):
                try:
                    os.remove(p)
                except OSError:
                    pass


@app.post("/chat", response_model=ChatResponse)
async def chat_with_ai(request: ChatRequest):
    """
    Interactive dietitian chat endpoint.
    Identical questions (same message text, same goals) are cached for 15 minutes.
    Personalized history is NOT part of the cache key to avoid stale responses.
    """
    try:
        # Cache key: message + goals only (history makes responses too unique)
        cache_key = cache.make_key("chat", {
            "msg": request.message.strip().lower(),
            "cal_goal": request.goals.get("daily_calories", 2000),
            "prot_goal": request.goals.get("protein_target", 50),
        })
        cached = await cache.get(cache_key)
        if cached is not None:
            return cached

        from services.chat_service import get_chat_response
        response = get_chat_response(
            request.message,
            request.profile,
            request.history,
            request.goals
        )

        # Only cache standard advice (not recipe/logging responses which are unique)
        if not response.get("recipes") and not response.get("logged_foods"):
            await cache.set(cache_key, response, TTL_CHAT)

        return response
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Chat request failed: {str(e)}")


@app.get("/cache/stats")
async def cache_stats():
    """Admin endpoint: Redis cache availability and basic info."""
    if not cache.is_available:
        return {"status": "unavailable", "message": "Redis is not connected"}
    try:
        import redis.asyncio as aioredis
        client = aioredis.from_url(os.getenv("REDIS_URL", "redis://localhost:6379"),
                                   decode_responses=True)
        info = await client.info("stats")
        keyspace = await client.info("keyspace")
        await client.aclose()
        return {
            "status": "available",
            "redis_url": os.getenv("REDIS_URL", "redis://localhost:6379"),
            "total_commands_processed": info.get("total_commands_processed"),
            "keyspace_hits": info.get("keyspace_hits"),
            "keyspace_misses": info.get("keyspace_misses"),
            "hit_rate": round(
                info.get("keyspace_hits", 0) /
                max(info.get("keyspace_hits", 0) + info.get("keyspace_misses", 1), 1) * 100, 1
            ),
            "keyspace": keyspace,
        }
    except Exception as e:
        return {"status": "error", "detail": str(e)}
