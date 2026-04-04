from transformers import pipeline

print("Loading labels...")
classifier = pipeline("image-classification", model="dima806/indian_food_image_detection")
labels = list(classifier.model.config.id2label.values())
print("Found labels:", sorted(labels))
