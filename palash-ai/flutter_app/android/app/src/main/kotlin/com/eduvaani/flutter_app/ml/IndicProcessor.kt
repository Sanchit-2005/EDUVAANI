package com.eduvaani.flutter_app.ml

import android.util.Log

/**
 * Minimal IndicProcessor equivalent for IndicTrans2 on-device inference.
 *
 * Handles:
 * - Preprocessing: adds language tokens and normalizes input text
 * - Postprocessing: normalizes translated text
 */
class IndicProcessor {
    fun preprocessBatch(
        texts: List<String>,
        srcLang: String,
        tgtLang: String,
        visualize: Boolean = false
    ): List<String> {
        return texts.map { text ->
            val normalized = normalizeText(text)
            val result = "$srcLang $tgtLang $normalized"
            Log.d(TAG, "[ON_DEVICE] preprocess input='$text' src=$srcLang tgt=$tgtLang output='$result'")
            result
        }
    }

    fun postprocessBatch(texts: List<String>, lang: String): List<String> {
        return texts.map { text ->
            normalizeText(text)
        }
    }

    private fun normalizeText(text: String): String {
        // Minimal normalization for prototype:
        // - Trim whitespace
        // - Normalize spaces
        // - Keep the rest unchanged
        // The real IndicProcessor performs script-specific normalization,
        // but for this prototype we preserve the exact Unicode text.
        return text.trim()
            .replace(Regex("\\s+"), " ")
            .trim()
    }

    companion object {
        private const val TAG = "IndicProcessor"
    }
}
