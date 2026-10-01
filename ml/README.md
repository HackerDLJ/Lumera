# Lumera ML

## RGB Research Baseline

This directory contains Lumera's first executable research model.

The baseline is a binary logistic-regression classifier trained on 104 labeled samples from the public `Anemia.csv` file in `shivombansal/Anemia-Detection-using-conjunctiva-images`.

Features:

- red pixel percentage
- green pixel percentage
- blue pixel percentage

The trained coefficients are stored in `lumera_rgb_model.json`.

### Validation

Five-fold stratified cross-validation on the available 104 samples produced:

- Accuracy: 77.8% ± 7.4%
- Precision: 56.0%
- Recall: 84.7%
- F1: 66.5%
- ROC-AUC: 88.2%

These numbers are **research-only** and should not be interpreted as clinical performance. The dataset is small and the features are aggregate color statistics.

## Re-training

Place the source CSV at `data/Anemia.csv`, then run:

```bash
python3 -m pip install pandas scikit-learn
python3 ml/train_color_model.py
```

The next Lumera ML phase should replace this RGB-only baseline with a patient-wise split conjunctiva image model trained against laboratory hemoglobin ground truth, then export a validated model to Core ML.
