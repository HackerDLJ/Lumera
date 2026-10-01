# Lumera ML pipeline

Lumera's ML pipeline is designed for **research-only, non-invasive anemia screening** from smartphone images. The current target modality is the lower-eyelid conjunctiva, with the architecture retaining a dual head for haemoglobin regression and anemia-risk classification.

## Dataset

The primary training source for this pipeline is the **SEWA Rural Anemia Detection — Multi-Modal Clinical Dataset** (`sewa-rural-care/anemia-survey-data`). It contains smartphone images of conjunctiva, fingernails and tongue together with laboratory haemoglobin ground truth. The dataset is gated and licensed CC BY-NC 4.0 with additional non-redistribution and research-use restrictions. Do not commit the raw dataset to this repository.

Dataset page: https://huggingface.co/datasets/sewa-rural-care/anemia-survey-data

The repository intentionally contains only code and metadata-free documentation. You must request access and accept the dataset terms yourself.

## Setup

```bash
cd ml
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
huggingface-cli login
```

## Prepare a local manifest

After access is granted:

```bash
python prepare_sewa.py \
  --modality conjunctiva \
  --max-participants 1000 \
  --output ../data/lumera_sewa_conjunctiva.csv
```

Start with a small participant count while validating the pipeline. The full source dataset is large, so there is no reason to download everything before the code path is proven.

## Train

```bash
python train.py \
  --manifest ../data/lumera_sewa_conjunctiva.csv \
  --epochs 20 \
  --batch-size 32 \
  --output artifacts/lumera_mobilenet_v3_small.pt
```

The split is **participant-grouped**, not image-random. This prevents images from the same participant leaking into validation.

The training objective combines:

- haemoglobin regression with Smooth L1 loss
- anemia-risk classification with BCE-with-logits loss
- validation metrics: MAE, RMSE, F1 and ROC-AUC when both classes are present

## Export to Core ML

```bash
python export_coreml.py \
  --checkpoint artifacts/lumera_mobilenet_v3_small.pt \
  --output artifacts/LumeraAnemia.mlpackage
```

The exported model accepts a 224×224 RGB image and exposes:

- `haemoglobin_gdl`
- `risk_logit`

The preprocessing is ImageNet normalization after RGB conversion.

## Important validation rule

A successful training run does **not** mean Lumera is clinically validated. The source dataset itself warns that independent validation is required before clinical deployment. Lumera should therefore present the output as a screening/research estimate and recommend confirmatory CBC testing rather than claiming a diagnosis.

## Why this pipeline is different

The model is intentionally kept small enough for on-device inference while using a real clinical ground-truth target. The training code also treats participant identity as a grouping variable, which is essential for avoiding overly optimistic medical-image metrics.
