# Lumera Architecture

## Runtime pipeline

```text
Capture → quality gate → calibration → ROI extraction → model inference → uncertainty → clinical rules → result
```

## Training pipeline

```text
Paired images + laboratory Hb
        ↓
patient-level split
        ↓
calibration / preprocessing
        ↓
ROI
        ↓
training
        ↓
validation
        ↓
held-out test
        ↓
MAE / RMSE / severity metrics
```

## Safety boundary

The result layer must distinguish estimated haemoglobin, model uncertainty, image-quality failure, and clinical confirmation recommendation. These are separate concepts and should not be collapsed into one AI confidence number.
