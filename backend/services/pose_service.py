import os
import json
import math
from typing import List, Dict, Any, Tuple

def validate_and_save_pose_data(pose_data: List[Dict[str, Any]], temp_dir: str, prefix: str) -> Tuple[bool, float]:
    """
    Validates pose data, computes diversity score, and saves to temp_uploads.
    Returns (is_valid, diversity_score).
    """
    if not pose_data or not isinstance(pose_data, list):
        return False, 0.0

    try:
        # Check basic structure
        for pose in pose_data:
            if "rotation_matrix" not in pose or len(pose["rotation_matrix"]) != 9:
                return False, 0.0
            if "pitch" not in pose or "roll" not in pose or "yaw" not in pose:
                return False, 0.0

        # Compute diversity score (similar to frontend logic)
        score = _compute_diversity(pose_data)

        # Save to file for Phase 3 (COLMAP/PixSfM)
        pose_path = os.path.join(temp_dir, f"{prefix}_poses.json")
        with open(pose_path, "w") as f:
            json.dump(pose_data, f, indent=2)
            
        print(f"INFO: [Pose Service] Saved pose data (score {score:.2f}) to {pose_path}", flush=True)
        return True, score

    except Exception as e:
        print(f"WARNING: [Pose Service] Failed to process pose data: {e}", flush=True)
        return False, 0.0

def _compute_diversity(poses: List[Dict[str, Any]]) -> float:
    if len(poses) < 2:
        return 0.0
    
    total_angle = 0.0
    for i in range(1, len(poses)):
        a = poses[i - 1]
        b = poses[i]
        dp = abs(b.get("pitch", 0) - a.get("pitch", 0))
        dr = abs(b.get("roll", 0) - a.get("roll", 0))
        dy = abs(b.get("yaw", 0) - a.get("yaw", 0))
        total_angle += math.sqrt(dp*dp + dr*dr + dy*dy)
        
    return min(1.0, max(0.0, total_angle / max(len(poses) - 1, 1)))
