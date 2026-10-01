from __future__ import annotations

"""Dataset utilities for Lumera's image-only anemia screening model.

The raw SEWA Rural dataset is intentionally NOT stored in this repository.
It is gated, non-commercial, and non-redistributable. Prepare a local manifest
with prepare_sewa.py after obtaining access.
"""

from dataclasses import dataclass
from pathlib import Path
from typing import Sequence

import pandas as pd
import torch
from PIL import Image
from torch.utils.data import Dataset
from torchvision import transforms


@dataclass(frozen=True)
class Sample:
    image_path: str
    participant_id: str
    haemoglobin: float
    risk: float


class LumeraImageDataset(Dataset):
    def __init__(self, samples: Sequence[Sample], train: bool = False, image_size: int = 224):
        self.samples = list(samples)
        if train:
            self.transform = transforms.Compose([
                transforms.Resize((image_size, image_size)),
                transforms.RandomHorizontalFlip(p=0.5),
                transforms.ColorJitter(brightness=0.12, contrast=0.10, saturation=0.08, hue=0.02),
                transforms.ToTensor(),
                transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
            ])
        else:
            self.transform = transforms.Compose([
                transforms.Resize((image_size, image_size)),
                transforms.ToTensor(),
                transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
            ])

    def __len__(self) -> int:
        return len(self.samples)

    def __getitem__(self, index: int):
        sample = self.samples[index]
        image = Image.open(sample.image_path).convert("RGB")
        return (
            self.transform(image),
            torch.tensor(sample.haemoglobin, dtype=torch.float32),
            torch.tensor(sample.risk, dtype=torch.float32),
        )


def load_manifest(path: str | Path) -> list[Sample]:
    frame = pd.read_csv(path)
    required = {"image_path", "participant_id", "haemoglobin_gdl", "risk"}
    missing = required - set(frame.columns)
    if missing:
        raise ValueError(f"Manifest is missing columns: {sorted(missing)}")

    samples: list[Sample] = []
    for row in frame.itertuples(index=False):
        image_path = Path(row.image_path)
        if not image_path.exists():
            continue
        samples.append(Sample(
            image_path=str(image_path),
            participant_id=str(row.participant_id),
            haemoglobin=float(row.haemoglobin_gdl),
            risk=float(row.risk),
        ))
    if not samples:
        raise ValueError("No usable image files were found in the manifest.")
    return samples
