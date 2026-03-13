# Local Model Training Guide

To achieve high accuracy without relying on an API key, you can train the local food model using your own data.

## 1. Prepare your Dataset
The project is set up to work best with the **Nutrition5k** or **Food-101** datasets.
- Ensure your images are in a folder (e.g., `data/images/`).
- Create a CSV file `data/nutrition_labels.csv` with columns: `image_path`, `food_class`, `calories`, `protein`, `carbs`, `fat`.

## 2. Model Architecture
The model uses **EfficientNet-B0** as a backbone. It is a "Multi-Task" model, meaning it simultaneously learns to:
1. **Recognize** the food type (Classification).
2. **Estimate** the nutrition/quantity (Regression).

## 3. How to Train
I have provided a script `backend/services/local_model.py`. You can extend this to run a training loop:

```python
# Example training loop snippet
optimizer = torch.optim.Adam(model.parameters(), lr=0.001)
criterion_class = nn.CrossEntropyLoss()
criterion_reg = nn.MSELoss()

for epoch in range(num_epochs):
    for images, labels, nutrition in dataloader:
        pred_class, pred_nut = model(images)
        loss = criterion_class(pred_class, labels) + criterion_reg(pred_nut, nutrition)
        # backprop...
```

## 4. Benefit of this Approach
- **Privacy**: No food images leave your device.
- **Cost**: No API fees.
- **Speed**: Recognition happens locally on your server/device.

## 5. Increasing Accuracy for "Quantity"
Local models struggle with quantity without depth information. For "Atmost accuracy" in quantity:
- Use a **reference object** (like a spoon or plate) in your training images so the model learns relative scale.
- The **Nutrition5k** dataset already includes mass information, which the model uses to learn these weights.
