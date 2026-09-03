"""
PALASH-AI — IndicTrans2 Translator
===================================
Wraps the ai4bharat/indictrans2-indic-indic-dist-320M model for
Hindi ↔ Santali (Ol Chiki) translation.

The model is loaded ONCE at service startup and kept in memory.
All subsequent translation requests reuse the loaded model.

Language codes:
  Hindi   → hin_Deva
  Santali → sat_Olck

Supported pairs:
  hin_Deva → sat_Olck  (Hindi  → Santali)
  sat_Olck → hin_Deva  (Santali → Hindi)
"""

import logging
import torch
from transformers import AutoModelForSeq2SeqLM, AutoTokenizer

# IndicTransToolkit provides IndicProcessor for mandatory pre/post-processing.
# The top-level import works with indictranstoolkit>=1.1.1.
# If it fails, fall back to the sub-module path.
try:
    from IndicTransToolkit import IndicProcessor
except ImportError:
    from IndicTransToolkit.IndicTransToolkit import IndicProcessor

logger = logging.getLogger(__name__)

# ── Constants ─────────────────────────────────────────────────────────────────

MODEL_ID = "ai4bharat/indictrans2-indic-indic-dist-320M"

SUPPORTED_LANGUAGES = {"hin_Deva", "sat_Olck"}
SUPPORTED_PAIRS = {
    ("hin_Deva", "sat_Olck"),
    ("sat_Olck", "hin_Deva"),
}

# Generation hyper-parameters (conservative for prototype quality)
NUM_BEAMS = 5
MAX_INPUT_TOKENS = 256
MAX_OUTPUT_TOKENS = 256


# ── Translator class ──────────────────────────────────────────────────────────

class IndicTransTranslator:
    """
    Loads IndicTrans2 once and translates Hindi ↔ Santali on demand.

    Usage
    -----
    translator = IndicTransTranslator()
    result = translator.translate("नमस्ते", "hin_Deva", "sat_Olck")
    """

    def __init__(self) -> None:
        self._loaded = False
        self._device: str = "cuda" if torch.cuda.is_available() else "cpu"
        logger.info("Using device: %s", self._device)

        self._ip: IndicProcessor | None = None
        self._tokenizer: AutoTokenizer | None = None
        self._model: AutoModelForSeq2SeqLM | None = None

    # ── Public API ────────────────────────────────────────────────────────────

    def load(self) -> None:
        """
        Downloads (first run) and loads the IndicTrans2 model into memory.
        Called once at service startup — NOT per request.

        The Hugging Face cache stores the model after the first download
        so subsequent startups are fast.
        """
        if self._loaded:
            return

        logger.info("Loading IndicTrans2 model: %s", MODEL_ID)

        # IndicProcessor handles Indic-specific pre/post-processing
        self._ip = IndicProcessor(inference=True)

        # Tokenizer — trust_remote_code required by IndicTrans2
        self._tokenizer = AutoTokenizer.from_pretrained(
            MODEL_ID,
            trust_remote_code=True,
        )

        # Model — loaded in float32 for CPU compatibility; moved to device
        self._model = AutoModelForSeq2SeqLM.from_pretrained(
            MODEL_ID,
            trust_remote_code=True,
        ).to(self._device)

        # Evaluation mode: disables dropout, reduces memory, speeds inference
        self._model.eval()

        # transformers>=4.38 switched past_key_values to DynamicCache, but the
        # IndicTrans2 custom model code expects the legacy tuple-of-tuples format.
        # Setting return_legacy_cache on the generation config forces the old
        # format to be used for all generate() calls on this model instance.
        if hasattr(self._model.generation_config, "return_legacy_cache"):
            self._model.generation_config.return_legacy_cache = True

        self._loaded = True
        logger.info("IndicTrans2 model loaded successfully on %s", self._device)

    @property
    def is_loaded(self) -> bool:
        return self._loaded

    def translate(
        self,
        text: str,
        source_language: str,
        target_language: str,
    ) -> str:
        """
        Translate *text* from *source_language* to *target_language*.

        Parameters
        ----------
        text : str
            Input text (Hindi in Devanagari or Santali in Ol Chiki).
        source_language : str
            e.g. "hin_Deva" or "sat_Olck"
        target_language : str
            e.g. "sat_Olck" or "hin_Deva"

        Returns
        -------
        str
            Translated text.

        Raises
        ------
        RuntimeError
            If the model has not been loaded yet.
        ValueError
            If the language pair is unsupported or the input is empty.
        """
        if not self._loaded:
            raise RuntimeError("Model is not loaded. Call load() first.")

        text = text.strip()
        if not text:
            raise ValueError("Input text must not be empty.")

        if source_language not in SUPPORTED_LANGUAGES:
            raise ValueError(f"Unsupported source language: {source_language}")
        if target_language not in SUPPORTED_LANGUAGES:
            raise ValueError(f"Unsupported target language: {target_language}")
        if (source_language, target_language) not in SUPPORTED_PAIRS:
            raise ValueError(
                f"Unsupported language pair: {source_language} → {target_language}"
            )

        # Wrap in list — IndicProcessor expects a batch
        sentences = [text]

        # Step 1 — Indic-specific pre-processing (script normalisation, etc.)
        preprocessed = self._ip.preprocess_batch(
            sentences,
            src_lang=source_language,
            tgt_lang=target_language,
            visualize=False,
        )

        # Step 2 — Tokenise
        inputs = self._tokenizer(
            preprocessed,
            padding="longest",
            truncation=True,
            max_length=MAX_INPUT_TOKENS,
            return_tensors="pt",
        ).to(self._device)

        # Step 3 — Generate (no gradient tracking needed for inference)
        # transformers==4.37.x uses the legacy tuple-of-tuples past_key_values
        # format which the IndicTrans2 custom model code expects.
        with torch.inference_mode():
            output_ids = self._model.generate(
                **inputs,
                num_beams=NUM_BEAMS,
                num_return_sequences=1,
                max_length=MAX_OUTPUT_TOKENS,
            )

        # Step 4 — Decode token IDs back to text
        decoded = self._tokenizer.batch_decode(
            output_ids,
            skip_special_tokens=True,
            clean_up_tokenization_spaces=True,
        )

        # Step 5 — Indic-specific post-processing
        results = self._ip.postprocess_batch(decoded, lang=target_language)

        # Return the single translated sentence
        return results[0]


# ── Module-level singleton ────────────────────────────────────────────────────
# app.py imports this instance and calls .load() during startup.

translator = IndicTransTranslator()
