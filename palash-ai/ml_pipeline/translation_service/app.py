"""
PALASH-AI — FastAPI Translation Service
=========================================
Exposes the IndicTrans2 Hindi ↔ Santali model over HTTP.

Startup flow:
  uvicorn app:app --port 8000
    → lifespan event loads the model ONCE
    → service is ready to handle requests

Endpoints:
  GET  /health   → liveness + model-loaded status
  POST /translate → Hindi ↔ Santali translation

Environment variables:
  TRANSLATION_PORT  (default: 8000)  — port to bind
"""

import logging
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel, field_validator

# Support both `python app.py` (direct) and `python -m translation_service` (package).
try:
    from .translator import translator, MODEL_ID, SUPPORTED_PAIRS
except ImportError:
    from translator import translator, MODEL_ID, SUPPORTED_PAIRS

# ── Logging ───────────────────────────────────────────────────────────────────

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(name)s — %(message)s",
)
logger = logging.getLogger(__name__)


# ── Lifespan: load model once at startup ──────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load the IndicTrans2 model before the first request is served."""
    logger.info("Starting PALASH-AI translation service…")
    logger.info(
        "First startup will download the model (~1.3 GB). "
        "Subsequent startups reuse the Hugging Face cache."
    )
    try:
        translator.load()
    except Exception as exc:
        # Log but keep the server running so /health can report the failure
        logger.error("Model failed to load: %s", exc, exc_info=True)
    yield
    logger.info("Translation service shutting down.")


# ── FastAPI application ───────────────────────────────────────────────────────

app = FastAPI(
    title="PALASH-AI Translation Service",
    description="Hindi ↔ Santali (Ol Chiki) neural translation via IndicTrans2",
    version="1.0.0",
    lifespan=lifespan,
)


# ── Request / Response schemas ────────────────────────────────────────────────

ALLOWED_LANGUAGES = {"hin_Deva", "sat_Olck"}


class TranslateRequest(BaseModel):
    text: str
    source_language: str
    target_language: str

    @field_validator("text")
    @classmethod
    def text_must_not_be_empty(cls, v: str) -> str:
        if not v or not v.strip():
            raise ValueError("text must not be empty or whitespace-only")
        return v.strip()

    @field_validator("source_language", "target_language")
    @classmethod
    def language_must_be_supported(cls, v: str) -> str:
        if v not in ALLOWED_LANGUAGES:
            raise ValueError(
                f"Unsupported language '{v}'. Allowed: {sorted(ALLOWED_LANGUAGES)}"
            )
        return v


class TranslateResponse(BaseModel):
    success: bool
    input: str
    translation: str
    source_language: str
    target_language: str


# ── Endpoints ─────────────────────────────────────────────────────────────────

@app.get("/health")
async def health():
    """
    Liveness check.

    Returns model name and whether it has successfully loaded.
    Used by Node.js or monitoring tools.
    """
    return {
        "status": "ok",
        "model": MODEL_ID,
        "model_loaded": translator.is_loaded,
    }


@app.post("/translate", response_model=TranslateResponse)
async def translate(req: TranslateRequest):
    """
    Translate text between Hindi and Santali.

    Supported pairs:
      hin_Deva → sat_Olck  (Hindi  → Santali Ol Chiki)
      sat_Olck → hin_Deva  (Santali → Hindi Devanagari)
    """
    # Check the pair before hitting the model
    pair = (req.source_language, req.target_language)
    if pair not in SUPPORTED_PAIRS:
        raise HTTPException(
            status_code=422,
            detail={
                "success": False,
                "error": (
                    f"Unsupported language pair: "
                    f"{req.source_language} → {req.target_language}"
                ),
            },
        )

    if not translator.is_loaded:
        raise HTTPException(
            status_code=503,
            detail={"success": False, "error": "Model is not loaded yet."},
        )

    try:
        output = translator.translate(
            text=req.text,
            source_language=req.source_language,
            target_language=req.target_language,
        )
    except ValueError as exc:
        # Input validation errors (should be caught by Pydantic already,
        # but kept as defence-in-depth)
        raise HTTPException(status_code=422, detail={"success": False, "error": str(exc)})
    except Exception as exc:
        # Never expose internal stack traces to callers
        logger.error("Translation error: %s", exc, exc_info=True)
        raise HTTPException(
            status_code=500,
            detail={"success": False, "error": "Translation failed. Please try again."},
        )

    return TranslateResponse(
        success=True,
        input=req.text,
        translation=output,
        source_language=req.source_language,
        target_language=req.target_language,
    )


# ── Validation error handler (returns consistent JSON shape) ──────────────────

@app.exception_handler(422)
async def validation_exception_handler(request: Request, exc):
    # Pydantic validation errors come here
    return JSONResponse(
        status_code=422,
        content={"success": False, "error": str(exc)},
    )


# ── Entry point (python app.py) ───────────────────────────────────────────────

if __name__ == "__main__":
    import uvicorn

    port = int(os.environ.get("TRANSLATION_PORT", 8000))
    logger.info("Starting uvicorn on port %d", port)
    uvicorn.run(
        "app:app",
        host="0.0.0.0",
        port=port,
        reload=False,   # Do NOT use reload=True — it reloads the model on every change
        log_level="info",
    )
