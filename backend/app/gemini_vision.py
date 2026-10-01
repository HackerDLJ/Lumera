from __future__ import annotations

import base64
import json
import os
from typing import Any

import httpx


class GeminiVisionError(RuntimeError):
    pass


class GeminiVisionService:
    """Gemini is used as a visual quality/region assistant, not as the anemia model."""

    def __init__(self) -> None:
        self.api_key = os.getenv("GEMINI_API_KEY", "").strip()
        self.model = os.getenv("GEMINI_VISION_MODEL", "gemini-3.8-flash").strip()
        self.timeout = float(os.getenv("GEMINI_TIMEOUT_SECONDS", "30"))

    @property
    def configured(self) -> bool:
        return bool(self.api_key)

    async def inspect_image(self, image_bytes: bytes, mime_type: str) -> dict[str, Any]:
        if not self.configured:
            raise GeminiVisionError("GEMINI_API_KEY is not configured.")

        if mime_type not in {"image/jpeg", "image/png", "image/webp", "image/heic", "image/heif"}:
            raise GeminiVisionError("Unsupported image type.")

        prompt = """
You are Lumera's image-quality and region-recognition assistant.

The image may be intended for research on smartphone-based conjunctiva screening.
Your job is ONLY to determine whether the image is suitable for a downstream
validated screening model. Do NOT diagnose anemia. Do NOT estimate haemoglobin.
Do NOT infer a person's medical condition from appearance.

Return ONLY valid JSON with this exact shape:
{
  "usable": true,
  "region": "conjunctiva|eye|face|unknown",
  "quality": "good|fair|poor",
  "issues": ["blur", "poor_lighting", "wrong_region", "obstruction", "low_resolution"],
  "explanation": "short explanation"
}

Rules:
- usable=true only when the intended eye/conjunctival region is clearly visible,
  reasonably sharp, adequately illuminated, and unobstructed.
- If the image is not an eye/conjunctiva image, use region=unknown and usable=false.
- Never output an anemia classification or haemoglobin value.
- Keep explanation under 30 words.
""".strip()

        payload = {
            "contents": [
                {
                    "parts": [
                        {"text": prompt},
                        {
                            "inline_data": {
                                "mime_type": mime_type,
                                "data": base64.b64encode(image_bytes).decode("ascii"),
                            }
                        },
                    ]
                }
            ],
            "generationConfig": {
                "temperature": 0,
                "responseMimeType": "application/json",
            },
        }

        url = f"https://generativelanguage.googleapis.com/v1beta/models/{self.model}:generateContent"
        headers = {"x-goog-api-key": self.api_key, "content-type": "application/json"}

        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.post(url, headers=headers, json=payload)
        except httpx.HTTPError as exc:
            raise GeminiVisionError(f"Gemini request failed: {exc}") from exc

        if response.status_code >= 400:
            raise GeminiVisionError(f"Gemini API returned HTTP {response.status_code}.")

        try:
            body = response.json()
            text = body["candidates"][0]["content"]["parts"][0]["text"]
            result = json.loads(text)
        except (KeyError, IndexError, TypeError, ValueError) as exc:
            raise GeminiVisionError("Gemini returned an invalid structured response.") from exc

        required = {"usable", "region", "quality", "issues", "explanation"}
        if not required.issubset(result):
            raise GeminiVisionError("Gemini response is missing required fields.")

        return {
            "usable": bool(result["usable"]),
            "region": str(result["region"]),
            "quality": str(result["quality"]),
            "issues": [str(item) for item in result["issues"]],
            "explanation": str(result["explanation"])[:300],
            "model": self.model,
        }
