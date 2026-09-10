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
            val normalized = normalizePreprocess(text)
            val result = "$srcLang $tgtLang $normalized"
            Log.d(TAG, "[ON_DEVICE] preprocess input='$text' src=$srcLang tgt=$tgtLang output='$result'")
            result
        }
    }

    fun postprocessBatch(texts: List<String>, lang: String): List<String> {
        return texts.map { text ->
            normalizePostprocess(text)
        }
    }

    private fun normalizePreprocess(text: String): String {
        // Space out punctuation symbols like IndicProcessor does for IndicTrans2:
        val spaced = text
            .replace(Regex("([.,?!:;।॥᱾᱿\\-–—()])"), " $1 ")
            .replace(Regex("\\s+"), " ")
            .trim()
        return spaced
    }

    private fun normalizePostprocess(text: String): String {
        // Remove spaces before standard punctuation including Santali Ol Chiki:
        return text
            .replace(Regex("\\s+([.,?!:;।॥᱾᱿)\\]])"), "$1")
            .replace(Regex("([(\\[])\\s+"), "$1")
            .replace(Regex("\\s+"), " ")
            .trim()
    }

    companion object {
        private const val TAG = "IndicProcessor"
    }
}
