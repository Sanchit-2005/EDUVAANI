package com.eduvaani.flutter_app.ml

import android.content.Context
import android.util.Log
import ai.onnxruntime.*
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.nio.LongBuffer

class OnDeviceTranslationEngine(private val context: Context) {

    private var env: OrtEnvironment? = null
    private var encoderSession: OrtSession? = null
    private var decoderSession: OrtSession? = null
    private var decoderWithPastSession: OrtSession? = null
    private var tokenizer: SentencePieceTokenizer? = null
    private var processor: IndicProcessor? = null

    private var initialized = false

    @Synchronized
    fun initialize(): Boolean {
        if (initialized) {
            Log.i(TAG, "[ON_DEVICE] Already initialized, returning true")
            return true
        }

        Log.i(TAG, "[ON_DEVICE] translate requested")
        Log.i(TAG, "[ON_DEVICE] initialize started")
        Log.d(TAG, "=== INITIALIZATION START ===")

        return try {
            Log.d(TAG, "Loading model assets...")

            Log.i(TAG, "[ON_DEVICE] ONNX environment creating")
            env = OrtEnvironment.getEnvironment()
            Log.i(TAG, "[ON_DEVICE] ONNX environment created")

            val modelsDir = context.filesDir.resolve("models/indictrans2/int8")
            modelsDir.mkdirs()

            Log.i(TAG, "[ON_DEVICE] models dir=${modelsDir.absolutePath}")

            val assets = listOf(
                "models/indictrans2/int8/encoder_model.onnx",
                "models/indictrans2/int8/decoder_model.onnx",
                "models/indictrans2/int8/decoder_with_past_model.onnx",
                "models/indictrans2/int8/model.SRC",
                "models/indictrans2/int8/model.TGT",
                "models/indictrans2/int8/dict.SRC.json",
                "models/indictrans2/int8/dict.TGT.json"
            )

            Log.d(TAG, "Loading model assets...")

            for (asset in assets) {
                try {
                    Log.d(TAG, "[ON_DEVICE] opening asset: $asset")

                    context.assets.open(asset).use { input ->
                        val dest = modelsDir.resolve(asset.substringAfterLast('/'))

                        copyAssetIfNeeded(asset, dest)

                        val size = dest.length()

                        Log.d(
                            TAG,
                            "[ON_DEVICE] extracted ${dest.name} size=$size"
                        )
                    }

                } catch (e: Exception) {
                    Log.e(
                        TAG,
                        "[ON_DEVICE] INITIALIZATION FAILED: asset=$asset exception=${e.javaClass.simpleName}: ${e.message}",
                        e
                    )

                    throw e
                }
            }

            Log.d(TAG, "Creating ONNX sessions...")

            Log.i(TAG, "[ON_DEVICE] creating encoder session")

            val sessionOptions = OrtSession.SessionOptions()
            sessionOptions.setIntraOpNumThreads(2)
            sessionOptions.addCPU(true)

            encoderSession = env!!.createSession(
                modelsDir.resolve("encoder_model.onnx").absolutePath,
                sessionOptions
            )

            Log.i(TAG, "[ON_DEVICE] encoder session created")

            Log.i(TAG, "[ON_DEVICE] creating decoder session")

            decoderSession = env!!.createSession(
                modelsDir.resolve("decoder_model.onnx").absolutePath,
                sessionOptions
            )

            Log.i(TAG, "[ON_DEVICE] decoder session created")

            Log.i(TAG, "[ON_DEVICE] creating decoder_with_past session")

            decoderWithPastSession = env!!.createSession(
                modelsDir.resolve("decoder_with_past_model.onnx").absolutePath,
                sessionOptions
            )

            Log.i(TAG, "[ON_DEVICE] decoder_with_past session created")

            val decoderWithPastInputNames =
                decoderWithPastSession!!.inputNames.toList().sorted()

            Log.i(
                TAG,
                "[ON_DEVICE] decoder_with_past expected inputs (${decoderWithPastInputNames.size})=$decoderWithPastInputNames"
            )

            Log.d(TAG, "Initializing tokenizer...")

            Log.i(TAG, "[ON_DEVICE] tokenizer initialization started")

            val tokenizerObj = SentencePieceTokenizer(context)

            try {
                Log.d(TAG, "Loading model.SRC...")

                val modelOk =
                    tokenizerObj.loadModel("models/indictrans2/int8/model.SRC")

                Log.d(TAG, "Loading model.TGT...")

                // Use loadTargetModel — NOT loadModel — so TGT pieces go into
                // the separate tgt trie/maps and do NOT overwrite the SRC ones.
                tokenizerObj.loadTargetModel(
                    "models/indictrans2/int8/model.TGT"
                )

                Log.d(TAG, "Loading dict.SRC.json...")

                val vocabOk =
                    tokenizerObj.loadVocab(
                        "models/indictrans2/int8/dict.SRC.json"
                    )

                Log.d(TAG, "Loading dict.TGT.json...")

                val tgtVocabOk =
                    tokenizerObj.loadTargetVocab(
                        "models/indictrans2/int8/dict.TGT.json"
                    )

                if (!modelOk) {
                    throw IllegalStateException(
                        "SentencePiece model.SRC failed to load"
                    )
                }

                if (!vocabOk) {
                    throw IllegalStateException(
                        "SentencePiece dict.SRC.json failed to load"
                    )
                }

                if (!tgtVocabOk) {
                    throw IllegalStateException(
                        "SentencePiece dict.TGT.json failed to load"
                    )
                }

                tokenizer = tokenizerObj

                Log.i(
                    TAG,
                    "[ON_DEVICE] tokenizer initialization completed pieces=${tokenizerObj.pieceCount}"
                )

            } catch (e: Exception) {

                Log.e(
                    TAG,
                    "[ON_DEVICE] INITIALIZATION FAILED: tokenizer exception=${e.javaClass.simpleName}: ${e.message}",
                    e
                )

                throw e
            }

            Log.d(TAG, "Initializing processor...")

            Log.i(TAG, "[ON_DEVICE] processor initialization started")

            processor = IndicProcessor()

            Log.i(TAG, "[ON_DEVICE] processor initialization completed")

            initialized = true

            Log.d(TAG, "=== INITIALIZATION SUCCESS ===")

            Log.i(TAG, "[ON_DEVICE] initialization completed")

            true

        } catch (e: Exception) {

            Log.e(
                TAG,
                "[ON_DEVICE] INITIALIZATION FAILED: exception=${e.javaClass.simpleName}: ${e.message}",
                e
            )

            Log.e(
                TAG,
                "=== COMPLETE INITIALIZATION FAILURE ===",
                e
            )

            false
        }
    }

    @Synchronized
    fun translate(
        text: String,
        sourceLang: String,
        targetLang: String
    ): String {

        Log.d(
            TAG,
            "translate() called - initialized: $initialized"
        )

        if (!initialized) {
            Log.w(
                TAG,
                "Engine not initialized, attempting initialization..."
            )

            initialize()
        }

        if (
            encoderSession == null ||
            decoderSession == null ||
            decoderWithPastSession == null ||
            tokenizer == null ||
            processor == null
        ) {

            Log.e(
                TAG,
                "Engine not fully initialized - some components are null"
            )

            throw IllegalStateException(
                "Engine not initialized"
            )
        }

        Log.i(
            TAG,
            "[ON_DEVICE] source language=$sourceLang target language=$targetLang"
        )

        val preprocessed =
            processor!!.preprocessBatch(
                listOf(text),
                sourceLang,
                targetLang
            )[0]

        Log.i(
            TAG,
            "[ON_DEVICE] preprocessed input=$preprocessed"
        )

        val inputIds =
            tokenizer!!.encode(preprocessed)

        Log.i(
            TAG,
            "[ON_DEVICE] token IDs=$inputIds"
        )

        if (inputIds.isEmpty()) {
            Log.w(
                TAG,
                "Empty token IDs, returning empty string"
            )

            return ""
        }

        val bosId = tokenizer!!.bosId
        val eosId = tokenizer!!.eosId

        val maxLength = 256
        val repetitionPenalty = 1.2f

        Log.d(TAG, "Running encoder...")

        val encoderHidden =
            runEncoder(inputIds)

        Log.i(
            TAG,
            "[ON_DEVICE] encoder completed srcLen=${inputIds.size} hiddenStatesLength=${encoderHidden.size}"
        )

        val actualSeqLen =
            encoderHidden.size / 512

        Log.d(
            TAG,
            "Calculated sequence length from encoder output: $actualSeqLen (based on ${encoderHidden.size} elements and 512 hidden dim)"
        )

        Log.d(
            TAG,
            "Running first decoder step..."
        )

        // IndicTrans2 uses a forced_bos_token_id equal to the target-language tag.
        // The decoder must see [BOS=0, tgt_lang_id] as its seed sequence; the
        // logits at position 1 (after tgt_lang_id) are the first real content
        // prediction.  Without this, the model predicts EOS immediately because
        // [BOS] alone gives no signal about which target language to generate.
        val forcedBosId = tokenizer!!.tgtLangId  // sat_Olck = 29925 in SRC vocab
        Log.i(TAG, "[ON_DEVICE] forced BOS tgt_lang_id=$forcedBosId")

        // seq is the FULL growing decoder input: [EOS, tgt_lang_id, tok1, tok2, ...].
        // decoder_with_past_model.onnx cannot be used here (see runDecoderStep
        // doc comment) — every step recomputes self- and cross-attention from
        // scratch over the whole sequence using decoder_model.onnx instead.
        val seq = mutableListOf(eosId, forcedBosId)

        val firstLogits =
            runDecoderStep(
                seq,
                encoderHidden,
                actualSeqLen
            )

        val generatedIds = ArrayList<Int>()
        // generatedIds tracks what the decoder has produced (excl. the BOS seed).
        // The forced tgt_lang_id is the first committed token.
        generatedIds.add(forcedBosId)

        var logits = firstLogits

        // min_new_tokens enforcement (HF-style): EOS cannot be the very first
        // generated token.  Some short inputs otherwise cause the model to
        // predict EOS immediately after the forced tgt_lang tag, yielding an
        // empty translation.  Mask EOS out of step 1's logits entirely.
        suppressToken(logits, eosId)

        var nextTokenId = argmax(logits)

        Log.i(
            TAG,
            "[ON_DEVICE] decoder step 1 [BOS,tgt_lang=$forcedBosId] -> token=$nextTokenId (EOS suppressed)"
        )

        generatedIds.add(nextTokenId)
        seq.add(nextTokenId)

        Log.d(
            TAG,
            "Starting generation loop..."
        )

        // min_new_tokens = 2: step 1 (above) and loop step=1 together produce
        // the first two real content tokens.  EOS is blocked for both so short
        // inputs (e.g. "नमस्ते") can't collapse to an empty translation.  From
        // loop step=2 onward, EOS selection is unrestricted so generation can
        // still terminate naturally.
        val minNewTokens = 2

        for (step in 1 until maxLength) {

            logits =
                runDecoderStep(
                    seq,
                    encoderHidden,
                    actualSeqLen
                )

            val uniqueGenerated =
                generatedIds.toSet()

            for (tokenId in uniqueGenerated) {
                applyRepetitionPenalty(
                    logits,
                    tokenId,
                    repetitionPenalty
                )
            }

            if (step < minNewTokens) {
                suppressToken(logits, eosId)
            }

            nextTokenId =
                argmax(logits)

            generatedIds.add(nextTokenId)

            Log.i(
                TAG,
                "[ON_DEVICE] generation step=$step token=$nextTokenId" +
                    (if (step < minNewTokens) " (EOS suppressed)" else "")
            )

            if (nextTokenId == eosId) {

                Log.i(
                    TAG,
                    "[ON_DEVICE] EOS reached at step=$step"
                )

                break
            }

            seq.add(nextTokenId)
        }

        Log.i(
            TAG,
            "[ON_DEVICE] final generated IDs=$generatedIds"
        )

        // generatedIds[0] is the forced tgt_lang_id control token (e.g.
        // sat_Olck=29925), not real content — it exists purely to seed the
        // decoder.  Decoding it directly produces visible tag residue (e.g.
        // "ग्रौ" prefixed onto the real Ol Chiki output), since that ID also
        // happens to map to a real piece in the TGT vocab.  Strip it, and
        // strip a trailing EOS if present, before decoding only the actual
        // generated content tokens.
        val contentIds =
            generatedIds
                .drop(1)
                .let { ids ->
                    if (ids.isNotEmpty() && ids.last() == eosId) {
                        ids.dropLast(1)
                    } else {
                        ids
                    }
                }

        Log.i(
            TAG,
            "[ON_DEVICE] content IDs (tgt_lang + EOS stripped)=$contentIds"
        )

        val result =
            decodeAndPostprocess(
                contentIds,
                targetLang
            )

        Log.i(
            TAG,
            "[ON_DEVICE] final decoded translation=$result"
        )

        return result
    }

    private fun runEncoder(
        inputIds: List<Int>
    ): FloatArray {

        val session =
            encoderSession
                ?: throw IllegalStateException(
                    "Encoder not initialized"
                )

        val inputIdsBuffer =
            LongBuffer.wrap(
                LongArray(inputIds.size) {
                    inputIds[it].toLong()
                }
            )

        val attentionMaskBuffer =
            LongBuffer.wrap(
                LongArray(inputIds.size) {
                    1
                }
            )

        val inputIdsTensor =
            OnnxTensor.createTensor(
                env!!,
                inputIdsBuffer,
                longArrayOf(
                    1,
                    inputIds.size.toLong()
                )
            )

        val attentionMaskTensor =
            OnnxTensor.createTensor(
                env!!,
                attentionMaskBuffer,
                longArrayOf(
                    1,
                    inputIds.size.toLong()
                )
            )

        val inputs: Map<String, OnnxTensor> =
            mapOf(
                "input_ids" to inputIdsTensor,
                "attention_mask" to attentionMaskTensor
            )

        val results =
            session.run(inputs)

        val output =
            results[0].value

        Log.d(
            TAG,
            "Encoder output type: ${output.javaClass}"
        )

        val hiddenStates =
            when (output) {

                is Array<*> -> {

                    if (
                        output.isNotEmpty() &&
                        output[0] is FloatArray
                    ) {

                        val floatArray =
                            output[0] as FloatArray

                        Log.d(
                            TAG,
                            "Encoder output shape: [1, ${output.size}, ${floatArray.size}] - total elements: ${output.size * floatArray.size}"
                        )

                        var totalSize = 0

                        for (i in output.indices) {

                            val subArray =
                                output[i] as FloatArray

                            totalSize +=
                                subArray.size
                        }

                        val flattenedArray =
                            FloatArray(totalSize)

                        var offset = 0

                        for (i in output.indices) {

                            val subArray =
                                output[i] as FloatArray

                            System.arraycopy(
                                subArray,
                                0,
                                flattenedArray,
                                offset,
                                subArray.size
                            )

                            offset +=
                                subArray.size
                        }

                        flattenedArray

                    } else if (
                        output.isNotEmpty() &&
                        output[0] is Array<*>
                    ) {

                        val nestedArray =
                            output[0] as Array<*>

                        if (
                            nestedArray.isNotEmpty() &&
                            nestedArray[0] is FloatArray
                        ) {

                            val innerArray =
                                nestedArray[0] as FloatArray

                            Log.d(
                                TAG,
                                "Encoder output shape: [${nestedArray.size}, ${innerArray.size}] - total elements: ${nestedArray.size * innerArray.size}"
                            )

                            var totalSize = 0

                            for (i in nestedArray.indices) {

                                val subArray =
                                    nestedArray[i] as FloatArray

                                totalSize +=
                                    subArray.size
                            }

                            val flattenedArray =
                                FloatArray(totalSize)

                            var offset = 0

                            for (i in nestedArray.indices) {

                                val subArray =
                                    nestedArray[i] as FloatArray

                                System.arraycopy(
                                    subArray,
                                    0,
                                    flattenedArray,
                                    offset,
                                    subArray.size
                                )

                                offset +=
                                    subArray.size
                            }

                            flattenedArray

                        } else {

                            throw IllegalArgumentException(
                                "Unexpected encoder output structure: ${output[0]?.javaClass}"
                            )
                        }

                    } else {

                        throw IllegalArgumentException(
                            "Unexpected encoder output type: ${output.javaClass}"
                        )
                    }
                }

                is FloatArray -> {

                    Log.d(
                        TAG,
                        "Encoder output shape: [${output.size}]"
                    )

                    output
                }

                else -> {

                    throw IllegalArgumentException(
                        "Unexpected encoder output type: ${output.javaClass}"
                    )
                }
            }

        return hiddenStates
    }

    /**
     * Run decoder_model (no KV cache) on the FULL sequence generated so far.
     *
     * IndicTrans2 is mBART-style: decoder_start_token_id = EOS (2), not BOS (0).
     * forced_bos_token_id = target-language tag (e.g. sat_Olck=29925 in SRC vocab).
     * seq[0]=EOS, seq[1]=forcedBosId, seq[2..]=previously generated tokens.
     *
     * ROOT-CAUSE NOTE (2026-09-09): decoder_with_past_model.onnx CANNOT be
     * bootstrapped on this export.  decoder_model.onnx has no present_*
     * outputs at all (verified via ONNX Runtime session introspection), so
     * there is no way to obtain real cross-attention K/V for the seed tokens
     * [EOS, tgt_lang_id].  Feeding decoder_with_past an all-zero past
     * (self-attn AND cross-attn slots) reproduces, deterministically and
     * independent of this Kotlin code, the exact
     * "/decoder/layers.0/self_attn/Reshape_7 ... input {1,8,1,3} requested
     * {8,1,1}" crash — confirmed by running the identical feed dict directly
     * against decoder_with_past_model.onnx in Python/onnxruntime outside the
     * app. Setting attention_mask length to match the true (empty) cache
     * avoids that crash but then fails on
     * "/decoder/layers.0/encoder_attn/Reshape_4 ... dimension value zero",
     * because the cross-attention past slots are never populated. There is
     * no supported way to seed decoder_with_past correctly with only the
     * assets shipped in this build.
     *
     * The only path that is both correct and crash-free with these exact
     * ONNX files is to always call decoder_model with the full growing
     * sequence (self- and cross-attention recomputed from scratch every
     * step) and read logits at the last position.  This is O(n) work per
     * step instead of O(1), but for translation-length outputs (<=256
     * tokens) it is fast enough and was verified end-to-end in Python for
     * both a short input ("नमस्ते") and a longer one without any
     * OrtException.
     *
     * input_ids shape:      [1, seq.size]
     * attention_mask shape: [1, seq.size]   — all positions attended
     * Returns: logits[0, seq.size-1, :] — vocab-size FloatArray at the last position.
     */
    private fun runDecoderStep(
        seq: List<Int>,
        encoderHidden: FloatArray,
        srcLen: Int
    ): FloatArray {

        val session = decoderSession
            ?: throw IllegalStateException("Decoder not initialized")

        val len = seq.size

        val inputIdsBuffer = LongBuffer.wrap(LongArray(len) { seq[it].toLong() })
        val attentionMaskBuffer = LongBuffer.wrap(LongArray(len) { 1L })

        val inputIdsTensor = OnnxTensor.createTensor(
            env!!, inputIdsBuffer, longArrayOf(1, len.toLong())
        )
        val attentionMaskTensor = OnnxTensor.createTensor(
            env!!, attentionMaskBuffer, longArrayOf(1, len.toLong())
        )
        val encoderHiddenTensor = OnnxTensor.createTensor(
            env!!, FloatBuffer.wrap(encoderHidden), longArrayOf(1, srcLen.toLong(), 512)
        )
        val encoderAttentionMaskTensor = OnnxTensor.createTensor(
            env!!, LongBuffer.wrap(LongArray(srcLen) { 1 }), longArrayOf(1, srcLen.toLong())
        )

        val results = session.run(mapOf(
            "input_ids"              to inputIdsTensor,
            "attention_mask"         to attentionMaskTensor,
            "encoder_hidden_states"  to encoderHiddenTensor,
            "encoder_attention_mask" to encoderAttentionMaskTensor
        ))

        // output shape is [1, tgt_len=len, vocab_size] — extract last position.
        val output = results[0].value
        Log.d(TAG, "Decoder step (len=$len) output type: ${output.javaClass}")

        val logits = when (output) {
            is Array<*> -> when {
                output.isNotEmpty() && output[0] is Array<*> -> {
                    // shape [batch=1][tgt_len][vocab] — take last tgt position
                    val batch0 = output[0] as Array<*>
                    batch0[batch0.size - 1] as? FloatArray
                        ?: throw IllegalArgumentException("Unexpected nested array element type")
                }
                output.isNotEmpty() && output[0] is FloatArray ->
                    // shape [tgt_len][vocab] — take last
                    output[output.size - 1] as FloatArray
                else ->
                    throw IllegalArgumentException("Unexpected decoder output type: ${output.javaClass}")
            }
            is FloatArray -> output
            else -> throw IllegalArgumentException("Unexpected decoder output type: ${output.javaClass}")
        }

        return logits
    }

    // runDecoderWithPast / createDummyPast / extractPresent were removed.
    // decoder_with_past_model.onnx cannot be bootstrapped with this asset
    // set: decoder_model.onnx exports no present_* KV tensors, so the
    // cross-attention past slots for the seed tokens [EOS, tgt_lang_id] can
    // never be populated with real values.  Feeding it an all-zero past
    // (self- and cross-attention) reproducibly crashes ONNX Runtime with a
    // Reshape error, independent of any Kotlin-side bug — confirmed by
    // replaying the identical feed dict directly in Python. See the
    // runDecoderStep() doc comment above for details.  decoderWithPastSession
    // is still created at init (harmless) but is no longer called.

    private fun applyRepetitionPenalty(
        logits: FloatArray,
        tokenId: Int,
        penalty: Float
    ) {

        if (penalty == 1.0f) {
            return
        }

        if (tokenId in logits.indices) {

            val logit =
                logits[tokenId]

            logits[tokenId] =
                if (logit < 0) {
                    logit * penalty
                } else {
                    logit / penalty
                }
        }
    }

    /**
     * Mask a single vocab index out of the logits in-place by setting it to
     * negative infinity, guaranteeing argmax() will never select it.  Used to
     * enforce a minimum-new-tokens constraint by blocking EOS on the earliest
     * generation steps (mirrors HF's min_new_tokens logits processor).
     */
    private fun suppressToken(
        logits: FloatArray,
        tokenId: Int
    ) {

        if (tokenId in logits.indices) {
            logits[tokenId] = Float.NEGATIVE_INFINITY
        }
    }

    private fun argmax(
        logits: FloatArray
    ): Int {

        var maxIndex = 0

        var maxValue =
            logits[0]

        for (i in 1 until logits.size) {

            if (logits[i] > maxValue) {

                maxValue =
                    logits[i]

                maxIndex =
                    i
            }
        }

        return maxIndex
    }

    private fun decodeAndPostprocess(
        generatedIds: List<Int>,
        targetLang: String
    ): String {

        tokenizer?.switchToTargetMode()

        val decoded =
            tokenizer?.decode(generatedIds)
                ?: ""

        tokenizer?.switchToSourceMode()

        return processor
            ?.postprocessBatch(
                listOf(decoded),
                targetLang
            )
            ?.firstOrNull()
            ?: decoded
    }

    @Throws(IOException::class)
    private fun copyAssetIfNeeded(
        assetPath: String,
        destFile: java.io.File
    ) {

        if (destFile.exists()) {
            return
        }

        destFile.parentFile?.mkdirs()

        context.assets
            .open(assetPath)
            .use { input ->

                destFile
                    .outputStream()
                    .use { output ->

                        input.copyTo(output)
                    }
            }
    }

    companion object {
        private const val TAG =
            "OnDeviceTranslationEngine"
    }
}