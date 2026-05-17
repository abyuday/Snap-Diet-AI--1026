import os
import base64
from openai import OpenAI
from dotenv import load_dotenv

if os.path.exists(".env"):
    load_dotenv(".env")
elif os.path.exists("backend/.env"):
    load_dotenv("backend/.env")

HF_TOKEN = os.getenv("HF_TOKEN")
AI_BASE_URL = "https://router.huggingface.co/v1"
AI_MODEL = "Qwen/Qwen2.5-VL-72B-Instruct" 

print(f"Testing HF Router with model: {AI_MODEL}")
print(f"Token present: {bool(HF_TOKEN)}")

client = OpenAI(api_key=HF_TOKEN, base_url=AI_BASE_URL)

import base64

# Dummy 1x1 black pixel base64
dummy_image = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="

try:
    print(f"Testing Multimodal with model: {AI_MODEL}")
    response = client.chat.completions.create(
        model=AI_MODEL,
        messages=[{
            "role": "user",
            "content": [
                {"type": "text", "text": "Identify the food in this image."},
                {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{dummy_image}"}}
            ]
        }],
        max_tokens=20
    )
    print("SUCCESS: Multimodal response received:")
    print(response.choices[0].message.content)
except Exception as e:
    print(f"ERROR: Multimodal test failed: {e}")
