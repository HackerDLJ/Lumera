from __future__ import annotations
import numpy as np

def gray_world_white_balance(image_bgr: np.ndarray) -> np.ndarray:
    image=image_bgr.astype(np.float32)+1e-6
    means=image.mean(axis=(0,1))
    scale=means.mean()/means
    return np.clip(image*scale,0,255).astype(np.uint8)

def calibrate_image(image_bgr: np.ndarray) -> np.ndarray:
    return gray_world_white_balance(image_bgr)
