"""
Volume Estimation Service — Phase 3

Uses monocular depth estimation (Intel DPT-Large via HuggingFace transformers)
to compute approximate 3D volume of food from images + YOLO segmentation masks.

Pipeline:
  1. Run YOLO to get food bounding box / mask region
  2. Run DPT depth model on the image
  3. Extract depth values within the food mask
  4. Compute volume: sum(relative_depth * pixel_area) with calibration
  5. Return estimated_volume_cm3

The volume is then multiplied by food density (from food_density.csv) to get weight.
"""

import os
import math
import numpy as np
from typing import Optional, Tuple, Dict, Any

# Lazy-loaded models
_depth_pipeline = None
_depth_available = None


def _load_depth_model():
    """Lazy-load the DPT depth estimation model."""
    global _depth_pipeline, _depth_available
    if _depth_available is not None:
        return _depth_available

    try:
        from transformers import pipeline
        print("INFO: [Volume] Loading DPT depth estimation model...", flush=True)
        _depth_pipeline = pipeline(
            "depth-estimation",
            model="Intel/dpt-large",
            device=-1,  # CPU (use 0 for GPU)
        )
        _depth_available = True
        print("INFO: [Volume] DPT depth model loaded successfully.", flush=True)
    except Exception as e:
        print(f"WARNING: [Volume] Could not load depth model: {e}", flush=True)
        _depth_available = False

    return _depth_available


def estimate_volume_from_image(
    image_path: str,
    food_bbox: Optional[Tuple[int, int, int, int]] = None,
) -> Dict[str, Any]:
    """
    Estimate the volume of food in an image using depth estimation.

    Args:
        image_path: Path to the food image.
        food_bbox: Optional (x1, y1, x2, y2) bounding box from YOLO.
                   If None, uses the center 60% of the image as the food region.

    Returns:
        Dict with keys:
            - volume_cm3: estimated volume in cubic centimeters
            - depth_map_stats: dict with mean/std/min/max depth values
            - method: "dpt_depth" or "heuristic_fallback"
            - success: bool
    """
    if not _load_depth_model():
        return _heuristic_volume(food_bbox)

    try:
        from PIL import Image
        img = Image.open(image_path).convert("RGB")
        img_w, img_h = img.size

        # Run depth estimation
        result = _depth_pipeline(img)
        depth_map = np.array(result["depth"])  # HxW, relative depth values

        # Normalize depth to 0-1 range
        d_min, d_max = depth_map.min(), depth_map.max()
        if d_max - d_min > 0:
            depth_norm = (depth_map - d_min) / (d_max - d_min)
        else:
            depth_norm = np.zeros_like(depth_map)

        # Resize depth map to match image if needed
        dh, dw = depth_norm.shape
        if (dh, dw) != (img_h, img_w):
            import cv2
            depth_norm = cv2.resize(depth_norm, (img_w, img_h), interpolation=cv2.INTER_LINEAR)

        # Create food mask from bbox or center region
        mask = np.zeros((img_h, img_w), dtype=bool)
        if food_bbox:
            x1, y1, x2, y2 = food_bbox
            x1, y1 = max(0, x1), max(0, y1)
            x2, y2 = min(img_w, x2), min(img_h, y2)
            mask[y1:y2, x1:x2] = True
        else:
            # Use center 60% of image as food region
            cx, cy = img_w // 2, img_h // 2
            rx, ry = int(img_w * 0.3), int(img_h * 0.3)
            mask[cy - ry:cy + ry, cx - rx:cx + rx] = True

        # Extract food depth values
        food_depth = depth_norm[mask]
        if food_depth.size == 0:
            return _heuristic_volume(food_bbox)

        # --- Volume calculation ---
        # The depth map gives relative depth. We need to convert to real-world units.
        #
        # Calibration assumptions for a typical food photo:
        #   - Camera ~30cm above food (typical phone photo distance)
        #   - Food items are typically 2-10cm tall
        #   - Image covers roughly 25x25cm of table area
        #
        # Real-world pixel size (cm/pixel):
        ASSUMED_FOV_CM = 25.0  # ~25cm field of view width
        pixel_size_cm = ASSUMED_FOV_CM / img_w
        pixel_area_cm2 = pixel_size_cm ** 2

        # Convert relative depth to absolute height (cm)
        # Max food height assumption: 8cm for most dishes
        MAX_FOOD_HEIGHT_CM = 8.0

        # The depth map's food region: higher relative depth = closer to camera = taller food
        # We want the "height" of the food above the plate surface
        plate_depth = np.percentile(food_depth, 10)  # plate/table baseline
        food_height = np.clip(food_depth - plate_depth, 0, None)
        food_height_cm = food_height * MAX_FOOD_HEIGHT_CM

        # Volume = sum of (pixel_area * height) for all food pixels
        volume_cm3 = float(np.sum(food_height_cm * pixel_area_cm2))

        # Sanity clamp: food volume typically 30-2000 cm³
        volume_cm3 = max(30.0, min(2000.0, volume_cm3))

        return {
            "volume_cm3": round(volume_cm3, 1),
            "depth_map_stats": {
                "mean_depth": round(float(food_depth.mean()), 4),
                "std_depth": round(float(food_depth.std()), 4),
                "food_pixels": int(food_depth.size),
                "plate_baseline": round(float(plate_depth), 4),
            },
            "method": "dpt_depth",
            "success": True,
        }

    except Exception as e:
        print(f"WARNING: [Volume] Depth estimation failed: {e}", flush=True)
        return _heuristic_volume(food_bbox)


def estimate_volume_multi(
    image_paths: list,
    bboxes: Optional[list] = None,
) -> Dict[str, Any]:
    """
    Estimate volume from multiple images, averaging across views.
    More images from different angles → more robust volume estimate.
    """
    volumes = []
    all_stats = []

    for i, img_path in enumerate(image_paths):
        bbox = bboxes[i] if bboxes and i < len(bboxes) else None
        result = estimate_volume_from_image(img_path, bbox)
        if result["success"]:
            volumes.append(result["volume_cm3"])
            all_stats.append(result)

    if not volumes:
        return _heuristic_volume(None)

    # Use trimmed mean to reduce outlier impact
    if len(volumes) >= 3:
        volumes_sorted = sorted(volumes)
        # Drop highest and lowest
        trimmed = volumes_sorted[1:-1]
        avg_volume = sum(trimmed) / len(trimmed)
    else:
        avg_volume = sum(volumes) / len(volumes)

    return {
        "volume_cm3": round(avg_volume, 1),
        "depth_map_stats": {
            "individual_volumes": [round(v, 1) for v in volumes],
            "images_used": len(volumes),
            "std_across_views": round(float(np.std(volumes)), 1) if len(volumes) > 1 else 0.0,
        },
        "method": "dpt_depth_multi",
        "success": True,
    }


def _heuristic_volume(
    bbox: Optional[Tuple[int, int, int, int]] = None,
) -> Dict[str, Any]:
    """Fallback: estimate volume from bbox area assuming an average food height."""
    if bbox:
        x1, y1, x2, y2 = bbox
        w_px = x2 - x1
        h_px = y2 - y1
        # Rough: 1 pixel ≈ 0.05 cm for typical phone photo
        w_cm = w_px * 0.05
        h_cm = h_px * 0.05
        avg_height_cm = 3.0  # Assume ~3cm average food height
        volume = w_cm * h_cm * avg_height_cm
        volume = max(30.0, min(2000.0, volume))
    else:
        volume = 200.0  # Default 200cm³ ≈ 1 standard serving

    return {
        "volume_cm3": round(volume, 1),
        "depth_map_stats": {},
        "method": "heuristic_fallback",
        "success": False,
    }
