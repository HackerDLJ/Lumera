from __future__ import annotations
import torch
from torch import nn
from torchvision.models import mobilenet_v3_small, MobileNet_V3_Small_Weights

class LumeraModel(nn.Module):
    def __init__(self):
        super().__init__()
        backbone=mobilenet_v3_small(weights=MobileNet_V3_Small_Weights.DEFAULT)
        in_features=backbone.classifier[-1].in_features
        backbone.classifier=nn.Identity()
        self.backbone=backbone
        self.hb_head=nn.Sequential(nn.Linear(in_features,128),nn.ReLU(),nn.Dropout(0.2),nn.Linear(128,1))
        self.risk_head=nn.Linear(in_features,1)
    def forward(self,x):
        f=self.backbone(x)
        return {'hb':self.hb_head(f).squeeze(-1),'risk_logit':self.risk_head(f).squeeze(-1)}
