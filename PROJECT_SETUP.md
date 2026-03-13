# AI Dietitian - Project Setup

This project consists of a Python FastAPI backend and a Flutter mobile frontend.

## 1. Backend Setup (FastAPI)

1. Navigate to the `backend` directory.
2. Create a virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Configure environment:
   - Rename `.env.example` to `.env`.
   - Add your `OPENAI_API_KEY`.
5. Run the server:
   ```bash
   uvicorn main:app --reload
   ```
   The API will be available at `http://127.0.0.1:8000`.

## 2. Frontend Setup (Flutter)

1. Ensure Flutter is installed (`flutter --version`).
2. Navigate to the `frontend` directory.
3. Fetch dependencies:
   ```bash
   flutter pub get
   ```
4. Run the app:
   ```bash
   flutter run
   ```
   For Android emulator (to reach host backend): `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000`
   For physical device: use your machine's IP, e.g. `flutter run --dart-define=API_BASE_URL=http://192.168.1.100:8000`

## 3. Local Model Training (No API Key Required)

If you want the model to work offline and with high accuracy:
1.  **Download Subset**:
    ```bash
    python -m backend.services.download_data
    ```
    This downloads overhead images for 1000 dishes to get you started.
2.  **Start Training**:
    ```bash
    python -m backend.services.train
    ```
    The model will be saved to `models/food_nutrition_final.pth`.

## Features
- **Multimodal Analysis**: Uses a local EfficientNet-B0 or GPT-4 Vision.
- **RAG Pipeline**: Integrates with FNDDS nutrition data.
- **Premium UI**: Dark mode, smooth animations, and clean nutritional reporting.
