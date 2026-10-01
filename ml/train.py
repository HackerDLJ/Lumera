from __future__ import annotations

"""Train Lumera's dual-head MobileNetV3 model.

The split is participant-grouped to prevent images from the same person from
appearing in both train and validation sets. This is critical for medical
image evaluation.
"""

import argparse
import json
import random
from pathlib import Path

import numpy as np
import torch
from sklearn.metrics import f1_score, mean_absolute_error, mean_squared_error, roc_auc_score
from sklearn.model_selection import GroupShuffleSplit
from torch import nn
from torch.utils.data import DataLoader

from dataset import LumeraImageDataset, load_manifest
from model import LumeraModel


def seed_everything(seed: int) -> None:
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(seed)


def split_samples(samples, seed: int):
    groups = np.array([s.participant_id for s in samples])
    indices = np.arange(len(samples))
    splitter = GroupShuffleSplit(n_splits=1, test_size=0.2, random_state=seed)
    train_idx, val_idx = next(splitter.split(indices, groups=groups))
    return [samples[i] for i in train_idx], [samples[i] for i in val_idx]


def run_epoch(model, loader, optimizer, device, hb_weight: float, risk_weight: float, train: bool):
    model.train(train)
    hb_loss_fn = nn.SmoothL1Loss()
    risk_loss_fn = nn.BCEWithLogitsLoss()
    total = 0.0
    count = 0
    for images, hb, risk in loader:
        images, hb, risk = images.to(device), hb.to(device), risk.to(device)
        with torch.set_grad_enabled(train):
            out = model(images)
            loss = hb_weight * hb_loss_fn(out["hb"], hb) + risk_weight * risk_loss_fn(out["risk_logit"], risk)
            if train:
                optimizer.zero_grad(set_to_none=True)
                loss.backward()
                nn.utils.clip_grad_norm_(model.parameters(), 2.0)
                optimizer.step()
        total += float(loss.item()) * images.size(0)
        count += images.size(0)
    return total / max(count, 1)


def evaluate(model, loader, device):
    model.eval()
    y_hb, p_hb, y_risk, p_risk = [], [], [], []
    with torch.no_grad():
        for images, hb, risk in loader:
            out = model(images.to(device))
            y_hb.extend(hb.numpy().tolist())
            p_hb.extend(out["hb"].cpu().numpy().tolist())
            y_risk.extend(risk.numpy().tolist())
            p_risk.extend(torch.sigmoid(out["risk_logit"]).cpu().numpy().tolist())

    risk_pred = (np.asarray(p_risk) >= 0.5).astype(int)
    metrics = {
        "mae_g_dl": float(mean_absolute_error(y_hb, p_hb)),
        "rmse_g_dl": float(np.sqrt(mean_squared_error(y_hb, p_hb))),
        "f1": float(f1_score(y_risk, risk_pred, zero_division=0)),
    }
    if len(set(y_risk)) == 2:
        metrics["roc_auc"] = float(roc_auc_score(y_risk, p_risk))
    else:
        metrics["roc_auc"] = None
    return metrics


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--output", default="artifacts/lumera_mobilenet_v3_small.pt")
    parser.add_argument("--epochs", type=int, default=20)
    parser.add_argument("--batch-size", type=int, default=32)
    parser.add_argument("--lr", type=float, default=3e-4)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--num-workers", type=int, default=4)
    args = parser.parse_args()

    seed_everything(args.seed)
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    samples = load_manifest(args.manifest)
    train_samples, val_samples = split_samples(samples, args.seed)

    train_ds = LumeraImageDataset(train_samples, train=True)
    val_ds = LumeraImageDataset(val_samples, train=False)
    train_loader = DataLoader(train_ds, batch_size=args.batch_size, shuffle=True, num_workers=args.num_workers, pin_memory=device.type == "cuda")
    val_loader = DataLoader(val_ds, batch_size=args.batch_size, shuffle=False, num_workers=args.num_workers, pin_memory=device.type == "cuda")

    model = LumeraModel().to(device)
    optimizer = torch.optim.AdamW(model.parameters(), lr=args.lr, weight_decay=1e-4)
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=args.epochs)

    best = float("inf")
    best_metrics = None
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)

    for epoch in range(1, args.epochs + 1):
        train_loss = run_epoch(model, train_loader, optimizer, device, 1.0, 0.75, True)
        metrics = evaluate(model, val_loader, device)
        scheduler.step()
        score = metrics["mae_g_dl"] + 0.5 * (1.0 - metrics["f1"])
        print(f"epoch={epoch:02d} train_loss={train_loss:.4f} metrics={metrics}")
        if score < best:
            best = score
            best_metrics = metrics
            torch.save({
                "state_dict": model.state_dict(),
                "model": "MobileNetV3-Small dual-head",
                "input_size": 224,
                "normalization": {
                    "mean": [0.485, 0.456, 0.406],
                    "std": [0.229, 0.224, 0.225],
                },
                "seed": args.seed,
                "validation_metrics": metrics,
            }, output)

    report = output.with_suffix(".json")
    report.write_text(json.dumps({
        "train_samples": len(train_samples),
        "validation_samples": len(val_samples),
        "best_validation_metrics": best_metrics,
        "device": str(device),
    }, indent=2))
    print(f"Saved checkpoint: {output}")
    print(f"Saved report: {report}")


if __name__ == "__main__":
    main()
