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

# Install torch CPU-only first (avoids downloading ~1.5 GB of CUDA libs unnecessarily)
RUN pip install --no-cache-dir --timeout=300 --retries=10 \
    torch torchvision --index-url https://download.pytorch.org/whl/cpu

# Install remaining requirements (excluding torch/torchvision already installed above)
RUN grep -vE '^(torch|torchvision)' requirements.txt > /tmp/requirements_no_torch.txt \
    && pip install --no-cache-dir --timeout=300 --retries=10 -r /tmp/requirements_no_torch.txt

# Install missing database and auth dependencies
RUN pip install --no-cache-dir --timeout=300 --retries=10 \
    motor "passlib[bcrypt]" "python-jose[cryptography]" email-validator

# Copy backend code
COPY . .

# Expose FastAPI port
EXPOSE 8000

# Run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
