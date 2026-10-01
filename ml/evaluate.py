from __future__ import annotations
import numpy as np
from sklearn.metrics import mean_absolute_error, mean_squared_error, f1_score

def evaluate_regression(y_true,y_pred):
    return {'mae_g_dl':float(mean_absolute_error(y_true,y_pred)),'rmse_g_dl':float(np.sqrt(mean_squared_error(y_true,y_pred)))}

def evaluate_binary(y_true,probability):
    pred=(probability>=0.5).astype(int)
    return {'f1':float(f1_score(y_true,pred))}
