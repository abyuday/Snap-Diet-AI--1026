"""
Standalone training script for the AI Dietitian local model.
Run from the DietitianAI root directory:
    python train_model.py
"""
import os
import sys
import torch
import torch.nn as nn
from torch.utils.data import DataLoader, Dataset
from torchvision import models, transforms
from PIL import Image
import pandas as pd
import numpy as np
from tqdm import tqdm

# ── Model ─────────────────────────────────────────────────────────────────────
class FoodNutritionModel(nn.Module):
    def __init__(self):
        super().__init__()
        self.backbone = models.efficientnet_b0(weights=models.EfficientNet_B0_Weights.DEFAULT)
        in_features = self.backbone.classifier[1].in_features
        self.backbone.classifier = nn.Identity()
        # Regression head: predict [calories, protein, carbs, fat]
        self.regressor = nn.Sequential(
            nn.Linear(in_features, 256),
            nn.ReLU(),
            nn.Dropout(0.3),
            nn.Linear(256, 4)
        )

    def forward(self, x):
        features = self.backbone(x)
        return self.regressor(features)

# ── Dataset ───────────────────────────────────────────────────────────────────
def parse_metadata(meta_paths):
    rows = []
    for path in meta_paths:
        if not os.path.exists(path):
            print(f"Metadata not found: {path}")
            continue
        with open(path, encoding='utf-8', errors='ignore') as f:
            for line in f:
                parts = line.strip().split(',')
                if len(parts) >= 6:
                    try:
                        rows.append({
                            'dish_id': parts[0],
                            'calories': float(parts[1]),
                            'mass':     float(parts[2]),
                            'fat':      float(parts[3]),
                            'carbs':    float(parts[4]),
                            'protein':  float(parts[5]),
                        })
                    except ValueError:
                        continue
    return pd.DataFrame(rows).set_index('dish_id')

class Nutrition5kDataset(Dataset):
    def __init__(self, image_root, meta_df, transform):
        self.transform = transform
        self.samples = []
        for dish_id, row in meta_df.iterrows():
            img_path = os.path.join(image_root, dish_id, 'rgb.png')
            if os.path.exists(img_path):
                self.samples.append((img_path, [
                    row['calories'], row['protein'], row['carbs'], row['fat']
                ]))
        print(f"  -> Found {len(self.samples)} images with matching metadata")

    def __len__(self):
        return len(self.samples)

    def __getitem__(self, idx):
        path, labels = self.samples[idx]
        img = Image.open(path).convert('RGB')
        return self.transform(img), torch.tensor(labels, dtype=torch.float32)

# ── Main ──────────────────────────────────────────────────────────────────────
def main():
    DATASET_ROOT = "datasets/Nutrition5k_dataset"
    IMAGE_DIR    = os.path.join(DATASET_ROOT, "imagery/realsense_overhead")
    META_PATHS   = [
        os.path.join(DATASET_ROOT, "metadata/dish_metadata_cafe1.csv"),
        os.path.join(DATASET_ROOT, "metadata/dish_metadata_cafe2.csv"),
    ]
    MODEL_SAVE   = "models/food_nutrition_final.pth"
    NUM_EPOCHS   = 10
    BATCH_SIZE   = 16
    LR           = 1e-3

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"\n[START] Starting training on: {device}")
    if device.type == "cpu":
        print("   (No GPU detected -- training on CPU, this will take longer)")

    # Data
    transform = transforms.Compose([
        transforms.Resize(256),
        transforms.CenterCrop(224),
        transforms.RandomHorizontalFlip(),
        transforms.ColorJitter(brightness=0.2, contrast=0.2),
        transforms.ToTensor(),
        transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
    ])

    print("\n[DATA]  Loading metadata ...")
    meta_df = parse_metadata(META_PATHS)
    print(f"  -> {len(meta_df)} dishes in metadata")

    print("\n[IMG]   Scanning images ...")
    dataset = Nutrition5kDataset(IMAGE_DIR, meta_df, transform)
    if len(dataset) == 0:
        print("ERROR: No images found. Check that images are in datasets/Nutrition5k_dataset/imagery/realsense_overhead/")
        return

    loader = DataLoader(dataset, batch_size=BATCH_SIZE, shuffle=True,
                        num_workers=0, pin_memory=(device.type == "cuda"))

    # Model
    model = FoodNutritionModel().to(device)
    optimizer = torch.optim.Adam(model.parameters(), lr=LR)
    scheduler = torch.optim.lr_scheduler.StepLR(optimizer, step_size=4, gamma=0.5)
    criterion = nn.MSELoss()

    os.makedirs("models", exist_ok=True)

    print(f"\n[TRAIN] Training for {NUM_EPOCHS} epochs ...\n")
    for epoch in range(1, NUM_EPOCHS + 1):
        model.train()
        epoch_loss = 0.0
        bar = tqdm(loader, desc=f"Epoch {epoch:02d}/{NUM_EPOCHS}", unit="batch")
        for imgs, targets in bar:
            imgs, targets = imgs.to(device), targets.to(device)
            optimizer.zero_grad()
            preds = model(imgs)
            loss = criterion(preds, targets)
            loss.backward()
            optimizer.step()
            epoch_loss += loss.item()
            bar.set_postfix(loss=f"{epoch_loss/(bar.n+1):.2f}")
        scheduler.step()
        ckpt = f"models/food_nutrition_epoch_{epoch:02d}.pth"
        torch.save(model.state_dict(), ckpt)
        print(f"  [OK]  Epoch {epoch:02d} done -- avg loss {epoch_loss/len(loader):.2f} -- saved {ckpt}")

    torch.save(model.state_dict(), MODEL_SAVE)
    print(f"\n[DONE] Training complete! Final model saved to: {MODEL_SAVE}\n")

if __name__ == "__main__":
    main()
