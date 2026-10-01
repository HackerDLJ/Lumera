from __future__ import annotations

"""Export a trained Lumera checkpoint to a Core ML .mlpackage."""

import argparse
from pathlib import Path

import coremltools as ct
import torch
from torch import nn

from model import LumeraModel


class CoreMLWrapper(nn.Module):
    def __init__(self, model: LumeraModel):
        super().__init__()
        self.model = model

    def forward(self, image):
        out = self.model(image)
        return out["hb"], out["risk_logit"]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--checkpoint", required=True)
    parser.add_argument("--output", default="artifacts/LumeraAnemia.mlpackage")
    args = parser.parse_args()

    checkpoint = torch.load(args.checkpoint, map_location="cpu", weights_only=False)
    model = LumeraModel()
    model.load_state_dict(checkpoint["state_dict"])
    model.eval()

    example = torch.rand(1, 3, 224, 224)
    traced = torch.jit.trace(CoreMLWrapper(model), example)

    mlmodel = ct.convert(
        traced,
        convert_to="mlprogram",
        inputs=[ct.ImageType(
            name="image",
            shape=example.shape,
            color_layout=ct.colorlayout.RGB,
            scale=1 / 255.0,
            bias=[-0.485 / 0.229, -0.456 / 0.224, -0.406 / 0.225],
        )],
        outputs=[
            ct.TensorType(name="haemoglobin_gdl"),
            ct.TensorType(name="risk_logit"),
        ],
        minimum_deployment_target=ct.target.iOS16,
    )

    mlmodel.author = "Lumera"
    mlmodel.short_description = "Research-only image model for anemia-risk screening and haemoglobin estimation."
    mlmodel.version = "0.1.0"
    mlmodel.save(args.output)
    print(f"Saved Core ML model: {Path(args.output).resolve()}")


if __name__ == "__main__":
    main()
