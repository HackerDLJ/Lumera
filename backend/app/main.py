from fastapi import FastAPI, File, HTTPException, UploadFile
from dotenv import load_dotenv

from .gemini_vision import VisionServiceError, VisionService

load_dotenv("backend/.env")

app = FastAPI(title="Lumera API", version="0.2.0")
vision = VisionService()


@app.get("/health")
def health():
    return {"status": "ok", "project": "Lumera"}


@app.get("/api/v1/status")
def status():
    return {
        "model_loaded": False,
        "mode": "research",
        "vision_configured": vision.configured,
        "message": "The optional image-quality assistant is available when configured. The validated screening model remains separate.",
    }


@app.post("/api/v1/vision/inspect")
async def inspect_image(file: UploadFile = File(...)):
    """Check whether an uploaded image is suitable for Lumera's downstream model."""
    if not vision.configured:
        raise HTTPException(status_code=503, detail="Vision service is not configured on this deployment.")

    mime_type = file.content_type or ""
    image_bytes = await file.read()

    if not image_bytes:
        raise HTTPException(status_code=400, detail="The uploaded image is empty.")
    if len(image_bytes) > 20 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Image is too large. Use an image under 20 MB.")

    try:
        return await vision.inspect_image(image_bytes, mime_type)
    except VisionServiceError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
