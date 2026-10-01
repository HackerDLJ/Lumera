from __future__ import annotations

"""Prepare a local Lumera training manifest from the gated SEWA Rural dataset.

Usage after accepting the dataset terms and logging in to Hugging Face:
    python ml/prepare_sewa.py --output data/lumera_sewa_conjunctiva.csv --max-participants 1000

Raw clinical data must remain local and must not be committed to this repository.
"""

import argparse
import re
from pathlib import Path

import pandas as pd
from huggingface_hub import hf_hub_download, list_repo_files

REPO = "sewa-rural-care/anemia-survey-data"
MODALITY_MAP = {
    "conjunctiva": "Anemia_Conjunctiva",
    "fingernails_open": "Anemia_Fingernails_Open",
    "fingernails_closed": "Anemia_Fingernails_Closed",
    "tongue": "Anemia_Tongue",
}


def first_value(row: pd.Series, *names: str):
    for name in names:
        if name in row.index and pd.notna(row[name]):
            return row[name]
    return None


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default="data/lumera_sewa_conjunctiva.csv")
    parser.add_argument("--modality", choices=MODALITY_MAP, default="conjunctiva")
    parser.add_argument("--max-participants", type=int, default=0)
    args = parser.parse_args()

    modality = MODALITY_MAP[args.modality]
    files = list_repo_files(REPO, repo_type="dataset")
    metadata_files = sorted(
        f for f in files
        if f.startswith("participants/") and f.endswith("/metadata.parquet")
    )
    if args.max_participants:
        metadata_files = metadata_files[: args.max_participants]

    rows: list[dict] = []
    for metadata_remote in metadata_files:
        match = re.match(r"participants/([^/]+)/metadata\.parquet$", metadata_remote)
        if not match:
            continue
        participant_id = match.group(1)
        metadata_local = hf_hub_download(
            repo_id=REPO,
            repo_type="dataset",
            filename=metadata_remote,
        )
        frame = pd.read_parquet(metadata_local)
        if frame.empty:
            continue
        row = frame.iloc[0]

        hb = first_value(row, "haemoglobin_gdl", "Haemoglobin", "hemoglobin_gdl")
        label = first_value(row, "anemia_label", "hemoglobin_category")
        if hb is None:
            continue
        hb = float(hb)

        if label is not None:
            risk = 1.0 if str(label).strip().upper() in {"ANEMIC", "ANEMIA", "ANEMIA_LABEL"} else 0.0
        else:
            # Conservative fallback. The dataset's own derived label is preferred.
            gender = str(first_value(row, "gender", "sex") or "").strip().lower()
            threshold = 12.0 if gender.startswith("f") else 13.0
            risk = 1.0 if hb < threshold else 0.0

        image_name = f"Participant{participant_id}_{modality}_0_v2s1.jpeg"
        image_remote = f"participants/{participant_id}/Media/{modality}/{image_name}"
        try:
            image_local = hf_hub_download(
                repo_id=REPO,
                repo_type="dataset",
                filename=image_remote,
            )
        except Exception as exc:
            print(f"Skipping {participant_id}: image unavailable ({exc})")
            continue

        rows.append({
            "image_path": str(Path(image_local).resolve()),
            "participant_id": participant_id,
            "haemoglobin_gdl": hb,
            "risk": risk,
        })

    if not rows:
        raise RuntimeError("No samples were prepared. Check dataset access and modality.")

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    pd.DataFrame(rows).to_csv(output, index=False)
    print(f"Wrote {len(rows)} samples to {output}")
    print("Raw data remains outside the Git repository.")


if __name__ == "__main__":
    main()
