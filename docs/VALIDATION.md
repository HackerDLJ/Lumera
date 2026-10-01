# Validation Plan

Lumera must earn every performance number.

## Required evaluation

### Regression
- Mean Absolute Error (MAE)
- Root Mean Squared Error (RMSE)
- Prediction-interval calibration when implemented

### Classification
- Sensitivity
- Specificity
- Precision
- F1
- ROC-AUC where appropriate

### Reliability
- Patient-level train/validation/test separation
- Subgroup analysis when metadata permits
- Failure / rejection rate
- Inference latency
- Raw-image vs calibrated-image ablation

No images from the same patient may cross train and test partitions.
