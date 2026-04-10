import os
import uuid
import logging

try:
    from ultralytics import YOLO
    import cv2
except ImportError:
    YOLO = None

_yolo_model = None

def get_yolo_model():
    global _yolo_model
    if _yolo_model is None and YOLO is not None:
        try:
            # We use standard YOLOv8 nano which is fast and can detect basic food containers
            # (bowls, cups, dining table, etc.) helping the VLM localize separate components on a plate.
            _yolo_model = YOLO("yolov8n.pt") 
            print("INFO: Loaded YOLOv8n model for multi-item plate detection.", flush=True)
        except Exception as e:
            print(f"WARNING: Failed to load YOLO model: {e}", flush=True)
            _yolo_model = "UNAVAILABLE"
    
    if _yolo_model == "UNAVAILABLE" or YOLO is None:
        return None
    return _yolo_model

def detect_and_annotate(image_path: str) -> tuple[str, list]:
    """
    Runs YOLOv8 on the image to locate items (like bowls, cups, pizza, etc).
    Draws bounding boxes and returns the path to the annotated image 
    and a list of detected objects to help guide the VLM for multi-item plates.
    """
    model = get_yolo_model()
    if not model:
        return image_path, []
    
    try:
        results = model(image_path)
        if not results:
            return image_path, []
            
        result = results[0]
        
        # Save annotated image with bounding boxes
        annotated_img = result.plot()
        temp_dir = os.path.dirname(image_path)
        ext = os.path.splitext(image_path)[1]
        annotated_path = os.path.join(temp_dir, f"annotated_{uuid.uuid4().hex[:8]}{ext}")
        cv2.imwrite(annotated_path, annotated_img)
        
        # Extract detected classes
        detected_items = []
        for box in result.boxes:
            class_id = int(box.cls[0].item())
            class_name = model.names[class_id]
            # Filter to relevant food/dining objects
            food_related = ["bowl", "cup", "dining table", "pizza", "apple", "sandwich", "hot dog", "donut", "cake", "orange", "broccoli", "carrot", "spoon", "fork", "knife"]
            if class_name in food_related:
                 detected_items.append(class_name)
            
        return annotated_path, list(set(detected_items))
    except Exception as e:
        print(f"WARNING: YOLO detection failed: {e}", flush=True)
        return image_path, []
