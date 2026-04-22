# Backend Dockerfile for AI Dietitian
FROM python:3.9-slim

# Avoid writing .pyc files and buffering stdout/stderr
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    curl \
    libzbar0 \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy backend code
COPY . .

# Copy datasets from parent context if needed (handled in docker-compose context or via relative path)
# Assuming datasets/ and FNDDS/ are handled by mounting or being in context
# In this standalone Dockerfile, expecting them to be copied if in same dir
# But composition usually handles this. Let's copy them if we add them to the build context.

# Expose FastAPI port
EXPOSE 8000

# Run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
