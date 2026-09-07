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

    fun initialize(): Boolean {
        if (initialized) return true

        Log.i(TAG, "[ON_DEVICE] translate requested")
        Log.i(TAG, "[ON_DEVICE] initialize started")

        return try {
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
            for (asset in assets) {
                try {
                    Log.i(TAG, "[ON_DEVICE] opening asset: $asset")
                    context.assets.open(asset).use { input ->
                        val dest = modelsDir.resolve(asset.substringAfterLast('/'))
                        copyAssetIfNeeded(asset, dest)
                        val size = dest.length()
                        Log.i(TAG, "[ON_DEVICE] extracted ${dest.name} size=$size")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "[ON_DEVICE] INITIALIZATION FAILED: asset=$asset exception=${e.javaClass.simpleName}: ${e.message}")
                    throw e
                }
            }

            Log.i(TAG, "[ON_DEVICE] creating encoder session")
            val sessionOptions = OrtSession.SessionOptions()
            sessionOptions.setIntraOpNumThreads(2)
            sessionOptions.addCPU(true)
            encoderSession = env!!.createSession(modelsDir.resolve("encoder_model.onnx").absolutePath, sessionOptions)
            Log.i(TAG, "[ON_DEVICE] encoder session created")

            Log.i(TAG, "[ON_DEVICE] creating decoder session")
            decoderSession = env!!.createSession(modelsDir.resolve("decoder_model.onnx").absolutePath, sessionOptions)
            Log.i(TAG, "[ON_DEVICE] decoder session created")

            Log.i(TAG, "[ON_DEVICE] creating decoder_with_past session")
            decoderWithPastSession = env!!.createSession(modelsDir.resolve("decoder_with_past_model.onnx").absolutePath, sessionOptions)
            Log.i(TAG, "[ON_DEVICE] decoder_with_past session created")

            Log.i(TAG, "[ON_DEVICE] tokenizer initialization started")
            tokenizer = SentencePieceTokenizer(context).also { t ->
                val modelOk = t.loadModel("models/indictrans2/int8/model.SRC")
                val vocabOk = t.loadVocab("models/indictrans2/int8/dict.SRC.json")
                val tgtVocabOk = t.loadTargetVocab("models/indictrans2/int8/dict.TGT.json")
                Log.i(TAG, "[ON_DEVICE] tokenizer model loaded=$modelOk src vocab loaded=$vocabOk tgt vocab loaded=$tgtVocabOk pieces=${t.pieceCount}")
            }
            Log.i(TAG, "[ON_DEVICE] tokenizer initialization completed")

            Log.i(TAG, "[ON_DEVICE] processor initialization started")
            processor = IndicProcessor()
            Log.i(TAG, "[ON_DEVICE] processor initialization completed")

            initialized = true
            Log.i(TAG, "[ON_DEVICE] initialization completed")
            true
        } catch (e: Exception) {
            Log.e(TAG, "[ON_DEVICE] INITIALIZATION FAILED: exception=${e.javaClass.simpleName}: ${e.message}", e)
            false
        }
    }

    fun translate(text: String, sourceLang: String, targetLang: String): String {
        if (!initialized) {
            initialize()
        }

        if (encoderSession == null || decoderSession == null || decoderWithPastSession == null
            || tokenizer == null || processor == null) {
            throw IllegalStateException("Engine not initialized")
        }

        Log.i(TAG, "[ON_DEVICE] source language=$sourceLang target language=$targetLang")

        val preprocessed = processor!!.preprocessBatch(listOf(text), sourceLang, targetLang)[0]
        Log.i(TAG, "[ON_DEVICE] preprocessed input=$preprocessed")

        val inputIds = tokenizer!!.encode(preprocessed)
        Log.i(TAG, "[ON_DEVICE] token IDs=$inputIds")

        if (inputIds.isEmpty()) {
            return ""
        }

        val bosId = tokenizer!!.bosId
        val eosId = tokenizer!!.eosId
        val maxLength = 256
        val repetitionPenalty = 1.2f

        val encoderHidden = runEncoder(inputIds)
        Log.i(TAG, "[ON_DEVICE] encoder completed srcLen=${inputIds.size} hiddenLen=${encoderHidden.size}")

        val firstLogits = runFirstDecoderStep(bosId, encoderHidden, inputIds)

        val generatedIds = ArrayList<Int>()
        generatedIds.add(bosId)

        var logits = firstLogits
        var nextTokenId = argmax(logits)
        generatedIds.add(nextTokenId)
        Log.i(TAG, "[ON_DEVICE] decoder first step BOS=$bosId -> token=$nextTokenId")

        if (nextTokenId == eosId) {
            Log.i(TAG, "[ON_DEVICE] EOS reached after BOS")
            return decodeAndPostprocess(generatedIds, targetLang)
        }

        var past = createDummyPast(1, inputIds.size)
        var attentionMaskLength = 2

        for (step in 1 until maxLength) {
            val stepResult = runDecoderWithPast(nextTokenId, attentionMaskLength, encoderHidden, inputIds, past)
            logits = stepResult.first
            past = stepResult.second

            val uniqueGenerated = generatedIds.toSet()
            for (tokenId in uniqueGenerated) {
                applyRepetitionPenalty(logits, tokenId, repetitionPenalty)
            }

            nextTokenId = argmax(logits)
            generatedIds.add(nextTokenId)
            Log.i(TAG, "[ON_DEVICE] generation step=$step token=$nextTokenId")

            if (nextTokenId == eosId) {
                Log.i(TAG, "[ON_DEVICE] EOS reached at step=$step")
                break
            }

            attentionMaskLength++
        }

        Log.i(TAG, "[ON_DEVICE] final generated IDs=$generatedIds")
        val result = decodeAndPostprocess(generatedIds, targetLang)
        Log.i(TAG, "[ON_DEVICE] final decoded translation=$result")
        return result
    }

    private fun runEncoder(inputIds: List<Int>): FloatArray {
        val session = encoderSession ?: throw IllegalStateException("Encoder not initialized")

        val inputIdsBuffer = LongBuffer.wrap(LongArray(inputIds.size) { inputIds[it].toLong() })
        val attentionMaskBuffer = LongBuffer.wrap(LongArray(inputIds.size) { 1 })

        val inputIdsTensor = OnnxTensor.createTensor(env!!, inputIdsBuffer, longArrayOf(1, inputIds.size.toLong()))
        val attentionMaskTensor = OnnxTensor.createTensor(env!!, attentionMaskBuffer, longArrayOf(1, inputIds.size.toLong()))

        val inputs: Map<String, OnnxTensor> = mapOf(
            "input_ids" to inputIdsTensor,
            "attention_mask" to attentionMaskTensor
        )

        val results = session.run(inputs)
        val output = results[0].value as Array<*>
        val hiddenStates = output[0] as FloatArray

        return hiddenStates
    }

    private fun runFirstDecoderStep(bosId: Int, encoderHidden: FloatArray, inputIds: List<Int>): FloatArray {
        val session = decoderWithPastSession ?: throw IllegalStateException("Decoder not initialized")

        val srcLen = inputIds.size
        val past = createDummyPast(1, srcLen)

        val inputIdsBuffer = LongBuffer.wrap(longArrayOf(bosId.toLong()))
        val attentionMaskBuffer = LongBuffer.wrap(longArrayOf(1, 1))
        val encoderHiddenBuffer = FloatBuffer.wrap(encoderHidden)
        val encoderAttentionMaskBuffer = LongBuffer.wrap(LongArray(srcLen) { 1 })

        val inputIdsTensor = OnnxTensor.createTensor(env!!, inputIdsBuffer, longArrayOf(1, 1))
        val attentionMaskTensor = OnnxTensor.createTensor(env!!, attentionMaskBuffer, longArrayOf(1, 2))
        val encoderHiddenTensor = OnnxTensor.createTensor(env!!, encoderHiddenBuffer, longArrayOf(1, srcLen.toLong(), 512))
        val encoderAttentionMaskTensor = OnnxTensor.createTensor(env!!, encoderAttentionMaskBuffer, longArrayOf(1, srcLen.toLong()))

        val inputs = mutableMapOf<String, OnnxTensor>()
        inputs["input_ids"] = inputIdsTensor
        inputs["attention_mask"] = attentionMaskTensor
        inputs["encoder_attention_mask"] = encoderAttentionMaskTensor
        inputs["encoder_hidden_states"] = encoderHiddenTensor
        inputs.putAll(past)

        val results = session.run(inputs)
        val logits = (results[0].value as Array<*>)[0] as FloatArray

        return logits
    }

    private fun runDecoderWithPast(
        nextTokenId: Int,
        attentionMaskLength: Int,
        encoderHidden: FloatArray,
        inputIds: List<Int>,
        past: Map<String, OnnxTensor>
    ): Pair<FloatArray, Map<String, OnnxTensor>> {
        val session = decoderWithPastSession ?: throw IllegalStateException("Decoder not initialized")

        val srcLen = inputIds.size

        val inputIdsBuffer = LongBuffer.wrap(longArrayOf(nextTokenId.toLong()))
        val attentionMaskBuffer = LongBuffer.wrap(LongArray(attentionMaskLength) { 1 })
        val encoderHiddenBuffer = FloatBuffer.wrap(encoderHidden)
        val encoderAttentionMaskBuffer = LongBuffer.wrap(LongArray(srcLen) { 1 })

        val inputIdsTensor = OnnxTensor.createTensor(env!!, inputIdsBuffer, longArrayOf(1, 1))
        val attentionMaskTensor = OnnxTensor.createTensor(env!!, attentionMaskBuffer, longArrayOf(1, attentionMaskLength.toLong()))
        val encoderHiddenTensor = OnnxTensor.createTensor(env!!, encoderHiddenBuffer, longArrayOf(1, srcLen.toLong(), 512))
        val encoderAttentionMaskTensor = OnnxTensor.createTensor(env!!, encoderAttentionMaskBuffer, longArrayOf(1, srcLen.toLong()))

        val inputs = mutableMapOf<String, OnnxTensor>()
        inputs["input_ids"] = inputIdsTensor
        inputs["attention_mask"] = attentionMaskTensor
        inputs["encoder_attention_mask"] = encoderAttentionMaskTensor
        inputs["encoder_hidden_states"] = encoderHiddenTensor
        inputs.putAll(past)

        val results = session.run(inputs)
        val logits = (results[0].value as Array<*>)[0] as FloatArray

        val newPast = extractPresent(results)

        return Pair(logits, newPast)
    }

    private fun createDummyPast(pastLen: Int, srcLen: Int): Map<String, OnnxTensor> {
        val past = mutableMapOf<String, OnnxTensor>()
        val numLayers = 18
        val numHeads = 8
        val headDim = 64

        for (layer in 0 until numLayers) {
            val shape = longArrayOf(1, numHeads.toLong(), pastLen.toLong(), headDim.toLong())
            val crossShape = longArrayOf(1, numHeads.toLong(), srcLen.toLong(), headDim.toLong())

            val zeros = FloatArray((1 * numHeads * pastLen * headDim).coerceAtLeast(1))
            val crossZeros = FloatArray((1 * numHeads * srcLen * headDim).coerceAtLeast(1))

            past["past_${layer * 4}"] = OnnxTensor.createTensor(env!!, FloatBuffer.wrap(zeros), shape)
            past["past_${layer * 4 + 1}"] = OnnxTensor.createTensor(env!!, FloatBuffer.wrap(zeros), shape)
            past["past_${layer * 4 + 2}"] = OnnxTensor.createTensor(env!!, FloatBuffer.wrap(crossZeros), crossShape)
            past["past_${layer * 4 + 3}"] = OnnxTensor.createTensor(env!!, FloatBuffer.wrap(crossZeros), crossShape)
        }

        return past
    }

    private fun extractPresent(results: OrtSession.Result): Map<String, OnnxTensor> {
        val present = mutableMapOf<String, OnnxTensor>()
        for (i in 1 until results.count()) {
            val name = "present_${i - 1}"
            val tensor = results[i] as OnnxTensor
            val info = tensor.info
            val shape = info.shape
            val floatBuffer = tensor.floatBuffer
            val src = FloatArray(floatBuffer.remaining())
            floatBuffer.get(src)
            val copy = src.copyOf()
            present[name] = OnnxTensor.createTensor(env!!, FloatBuffer.wrap(copy), shape)
        }
        return present
    }

    private fun applyRepetitionPenalty(logits: FloatArray, tokenId: Int, penalty: Float) {
        if (penalty == 1.0f) return
        if (tokenId in logits.indices) {
            val logit = logits[tokenId]
            logits[tokenId] = if (logit < 0) logit * penalty else logit / penalty
        }
    }

    private fun argmax(logits: FloatArray): Int {
        var maxIndex = 0
        var maxValue = logits[0]
        for (i in 1 until logits.size) {
            if (logits[i] > maxValue) {
                maxValue = logits[i]
                maxIndex = i
            }
        }
        return maxIndex
    }

    private fun decodeAndPostprocess(generatedIds: List<Int>, targetLang: String): String {
        tokenizer?.switchToTargetMode()
        val decoded = tokenizer?.decode(generatedIds) ?: ""
        tokenizer?.switchToSourceMode()
        return processor?.postprocessBatch(listOf(decoded), targetLang)?.firstOrNull() ?: decoded
    }

    @Throws(IOException::class)
    private fun copyAssetIfNeeded(assetPath: String, destFile: java.io.File) {
        if (destFile.exists()) return

        destFile.parentFile?.mkdirs()
        context.assets.open(assetPath).use { input ->
            destFile.outputStream().use { output ->
                input.copyTo(output)
            }
        }
    }

    companion object {
        private const val TAG = "OnDeviceTranslationEngine"
    }
}
