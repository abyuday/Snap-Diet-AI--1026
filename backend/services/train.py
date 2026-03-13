import torch
import torch.nn as nn
from torch.utils.data import DataLoader
from torchvision import transforms
from PIL import Image
import os
from tqdm import tqdm
from .local_model import FoodNutritionModel
from ..code.ViT.dataset_utils import Nutrition5kDataset

def train_local_model(
    data_dir: str = "datasets/Nutrition5k_dataset",
    num_epochs: int = 10,
    batch_size: int = 16,
    learning_rate: float = 0.001
):
    """
    Trains the local EfficientNet model on the Nutrition5k dataset.
    """
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"Starting training on {device}...")

    # 1. Setup Data Paths
    image_dir = os.path.join(data_dir, "imagery/realsense_overhead")
    dish_id_path = os.path.join(data_dir, "dish_ids/splits/rgb_train_ids.txt")
    metadata_paths = [
        os.path.join(data_dir, "metadata/dish_metadata_cafe1.csv"),
        os.path.join(data_dir, "metadata/dish_metadata_cafe2.csv")
    ]

    # 2. Setup Transformers
    # Note: We use standard ImageNet normalization for EfficientNet
    def transform_fn(image, return_tensors="pt"):
        t = transforms.Compose([
            transforms.Resize(256),
            transforms.CenterCrop(224),
            transforms.ToTensor(),
            transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
        ])
        return {"pixel_values": t(image)}

    # 3. Load Dataset
    print("Loading Nutrition5k dataset...")
    try:
        dataset = Nutrition5kDataset(
            dish_id_txt_path=dish_id_path,
            image_dir=image_dir,
            dish_metadata_paths=metadata_paths,
            transform_fn=transform_fn
        )
    except Exception as e:
        print(f"Error loading dataset: {e}")
        print("Please ensure the datasets/Nutrition5k_dataset directory exists with correct metadata.")
        return

    dataloader = DataLoader(dataset, batch_size=batch_size, shuffle=True)

    # 4. Initialize Model
    # For now, we assume 101 food classes (like Food-101), but this can be adjusted
    model = FoodNutritionModel(num_food_classes=101).to(device)
    
    optimizer = torch.optim.Adam(model.parameters(), lr=learning_rate)
    criterion_reg = nn.MSELoss() # Regression for nutrition values
    # For classification, we'd need a label mapping. For now we focus on accurate nutrition regression.

    # 5. Training Loop
    model.train()
    for epoch in range(num_epochs):
        progress_bar = tqdm(dataloader, desc=f"Epoch {epoch+1}/{num_epochs}")
        epoch_loss = 0
        
        for batch in progress_bar:
            images = batch['pixel_values'].squeeze(dim=1).to(device)
            
            # Nutrition targets: Calories, Protein, Carbs, Fat
            targets = torch.stack([
                torch.tensor([float(x) for x in batch['total_calories']]),
                torch.tensor([float(x) for x in batch['total_protein']]),
                torch.tensor([float(x) for x in batch['total_carb']]),
                torch.tensor([float(x) for x in batch['total_fat']])
            ], dim=1).to(device)

            optimizer.zero_grad()
            _, pred_nutrition = model(images)
            
            loss = criterion_reg(pred_nutrition, targets)
            loss.backward()
            optimizer.step()
            
            epoch_loss += loss.item()
            progress_bar.set_postfix({'loss': epoch_loss / (progress_bar.n + 1)})

        # Save checkpoint after each epoch
        os.makedirs("models", exist_ok=True)
        torch.save(model.state_dict(), f"models/food_nutrition_epoch_{epoch+1}.pth")
        print(f"Epoch {epoch+1} completed. Model saved.")

    # Save final model
    torch.save(model.state_dict(), "models/food_nutrition_final.pth")
    print("Training finished! Final model saved to models/food_nutrition_final.pth")

if __name__ == "__main__":
    train_local_model()
