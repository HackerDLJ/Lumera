"""
Train Lumera's RGB research baseline.

Input:
  data/Anemia.csv
Expected columns:
  %Red Pixel, %Green pixel, %Blue pixel, Anaemic

This is a research baseline only. It is NOT clinically validated.
"""
from pathlib import Path
import json
import pandas as pd
from sklearn.model_selection import StratifiedKFold, cross_validate
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.linear_model import LogisticRegression

ROOT = Path(__file__).resolve().parents[1]
CSV = ROOT / "data" / "Anemia.csv"
OUT = ROOT / "ml" / "lumera_rgb_model.json"

df = pd.read_csv(CSV)
features = ["%Red Pixel", "%Green pixel", "%Blue pixel"]
X = df[features].astype(float).values
y = (df["Anaemic"].str.lower() == "yes").astype(int).values

model = Pipeline([
    ("scaler", StandardScaler()),
    ("classifier", LogisticRegression(
        C=1.0,
        class_weight="balanced",
        max_iter=2000,
        random_state=42
    ))
])

cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
scores = cross_validate(
    model,
    X,
    y,
    cv=cv,
    scoring=["accuracy", "precision", "recall", "f1", "roc_auc"]
)

model.fit(X, y)

scaler = model.named_steps["scaler"]
classifier = model.named_steps["classifier"]

artifact = {
    "model_name": "Lumera RGB Research Baseline",
    "model_version": "0.1.0",
    "task": "binary_anemia_screening",
    "features": ["red_percent", "green_percent", "blue_percent"],
    "normalization": {
        "mean": scaler.mean_.tolist(),
        "std": scaler.scale_.tolist(),
    },
    "logistic_regression": {
        "coefficients": classifier.coef_[0].tolist(),
        "intercept": float(classifier.intercept_[0]),
        "positive_class": "possible_anemia",
    },
    "decision_threshold": 0.5,
    "training": {
        "samples": int(len(df)),
        "positive_samples": int(y.sum()),
        "negative_samples": int((1 - y).sum()),
        "class_weight": "balanced",
        "seed": 42,
    },
    "cross_validation_5fold": {
        "accuracy_mean": float(scores["test_accuracy"].mean()),
        "accuracy_std": float(scores["test_accuracy"].std()),
        "precision_mean": float(scores["test_precision"].mean()),
        "recall_mean": float(scores["test_recall"].mean()),
        "f1_mean": float(scores["test_f1"].mean()),
        "roc_auc_mean": float(scores["test_roc_auc"].mean()),
    },
    "provenance": {
        "source": "shivombansal/Anemia-Detection-using-conjunctiva-images",
        "source_file": "Anemia.csv",
        "note": "Research baseline from RGB percentage features; not clinically validated.",
    },
}

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(json.dumps(artifact, indent=2) + "\n")
print(json.dumps(artifact, indent=2))
