from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import shutil
import os
import mimetypes
import uuid
import re
from typing import Optional, List
from dotenv import load_dotenv

# Load environment variables from .env
load_dotenv()

# Services will be imported lazily within endpoints to prevent startup hangs
# from services.food_analyzer import analyze_food_image, predict_food
# from services.search_service import search_foods
# from services.chat_service import get_chat_response

app = FastAPI(title="AI Dietitian API", version="1.0.0")

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

class ChatRequest(BaseModel):
    message: str
    profile: dict
    history: List[dict]
    goals: dict

class ChatResponse(BaseModel):
    reply: str
    recommendations: List[dict]

@app.get("/")
def read_root():
    return {"message": "API V2 READY"}

@app.get("/search", response_model=List[SearchResult])
async def search(q: str):
    """
    Search for food items by name.
    """
    from services.search_service import search_foods
    return search_foods(q)

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


@app.post("/chat", response_model=ChatResponse)
async def chat_with_ai(request: ChatRequest):
    """
    Interactive dietitian chat endpoint.
    """
    try:
        from services.chat_service import get_chat_response
        response = get_chat_response(
            request.message, 
            request.profile, 
            request.history, 
            request.goals
        )
        return response
    except Exception:
        raise HTTPException(status_code=500, detail="Chat request failed.")
