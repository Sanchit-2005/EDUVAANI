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
                        Log.d(TAG, "[ON_DEVICE] extracted ${dest.name} size=$size")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "[ON_DEVICE] INITIALIZATION FAILED: asset=$asset exception=${e.javaClass.simpleName}: ${e.message}", e)
                    throw e
                }
            }

            Log.d(TAG, "Creating ONNX sessions...")
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

            Log.d(TAG, "Initializing tokenizer...")
            Log.i(TAG, "[ON_DEVICE] tokenizer initialization started")
            val tokenizerObj = SentencePieceTokenizer(context)
            try {
                Log.d(TAG, "Loading model.SRC...")
                val modelOk = tokenizerObj.loadModel("models/indictrans2/int8/model.SRC")
                Log.d(TAG, "Loading model.TGT...")
                tokenizerObj.loadModel("models/indictrans2/int8/model.TGT") // Load target model too
                Log.d(TAG, "Loading dict.SRC.json...")
                val vocabOk = tokenizerObj.loadVocab("models/indictrans2/int8/dict.SRC.json")
                Log.d(TAG, "Loading dict.TGT.json...")
                val tgtVocabOk = tokenizerObj.loadTargetVocab("models/indictrans2/int8/dict.TGT.json")
                if (!modelOk) {
                    throw IllegalStateException("SentencePiece model.SRC failed to load")
                }
                if (!vocabOk) {
                    throw IllegalStateException("SentencePiece dict.SRC.json failed to load")
                }
                if (!tgtVocabOk) {
                    throw IllegalStateException("SentencePiece dict.TGT.json failed to load")
                }
                tokenizer = tokenizerObj
                Log.i(TAG, "[ON_DEVICE] tokenizer initialization completed pieces=${tokenizerObj.pieceCount}")
            } catch (e: Exception) {
                Log.e(TAG, "[ON_DEVICE] INITIALIZATION FAILED: tokenizer exception=${e.javaClass.simpleName}: ${e.message}", e)
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
            Log.e(TAG, "[ON_DEVICE] INITIALIZATION FAILED: exception=${e.javaClass.simpleName}: ${e.message}", e)
            Log.e(TAG, "=== COMPLETE INITIALIZATION FAILURE ===", e)
            false
        }
    }

    fun translate(text: String, sourceLang: String, targetLang: String): String {
        Log.d(TAG, "translate() called - initialized: $initialized")
        if (!initialized) {
            Log.w(TAG, "Engine not initialized, attempting initialization...")
            initialize()
        }

        if (encoderSession == null || decoderSession == null || decoderWithPastSession == null
            || tokenizer == null || processor == null) {
            Log.e(TAG, "Engine not fully initialized - some components are null")
            throw IllegalStateException("Engine not initialized")
        }

        Log.i(TAG, "[ON_DEVICE] source language=$sourceLang target language=$targetLang")

        val preprocessed = processor!!.preprocessBatch(listOf(text), sourceLang, targetLang)[0]
        Log.i(TAG, "[ON_DEVICE] preprocessed input=$preprocessed")

        val inputIds = tokenizer!!.encode(preprocessed)
        Log.i(TAG, "[ON_DEVICE] token IDs=$inputIds")

        if (inputIds.isEmpty()) {
            Log.w(TAG, "Empty token IDs, returning empty string")
            return ""
        }

        val bosId = tokenizer!!.bosId
        val eosId = tokenizer!!.eosId
        val maxLength = 256
        val repetitionPenalty = 1.2f

        Log.d(TAG, "Running encoder...")
        val encoderHidden = runEncoder(inputIds)
        Log.i(TAG, "[ON_DEVICE] encoder completed srcLen=${inputIds.size} hiddenStatesLength=${encoderHidden.size}")

        // Calculate the actual sequence length from the encoder output
        // For a tensor of shape [batch_size, seq_len, hidden_dim], the length would be batch_size * seq_len * hidden_dim
        // Since batch_size is 1 and hidden_dim is 512, then seq_len = encoderHidden.size / 512
        val actualSeqLen = encoderHidden.size / 512
        Log.d(TAG, "Calculated sequence length from encoder output: $actualSeqLen (based on ${encoderHidden.size} elements and 512 hidden dim)")

        Log.d(TAG, "Running first decoder step...")
        val firstLogits = runFirstDecoderStep(bosId, encoderHidden, actualSeqLen)

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

        Log.d(TAG, "Starting generation loop...")
        // For subsequent steps, we need to use the decoder_with_past model
        var past = createDummyPast(1, actualSeqLen)  // Use actual sequence length
        var attentionMaskLength = 2

        for (step in 1 until maxLength) {
            val stepResult = runDecoderWithPast(nextTokenId, attentionMaskLength, encoderHidden, actualSeqLen, past)  // Use actual sequence length
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
        val output = results[0].value
        Log.d(TAG, "Encoder output type: ${output.javaClass}")
        
        // Properly handle the multidimensional array structure
        val hiddenStates = when (output) {
            is Array<*> -> {
                if (output.isNotEmpty() && output[0] is FloatArray) {
                    // Handle Array<FloatArray> case
                    val floatArray = output[0] as FloatArray
                    Log.d(TAG, "Encoder output shape: [1, ${output.size}, ${floatArray.size}] - total elements: ${output.size * floatArray.size}")
                    // Calculate total size
                    var totalSize = 0
                    for (i in output.indices) {
                        val subArray = output[i] as FloatArray
                        totalSize += subArray.size
                    }
                    // Flatten the array: concatenate all FloatArrays in the outer array
                    val flattenedArray = FloatArray(totalSize)
                    var offset = 0
                    for (i in output.indices) {
                        val subArray = output[i] as FloatArray
                        System.arraycopy(subArray, 0, flattenedArray, offset, subArray.size)
                        offset += subArray.size
                    }
                    flattenedArray
                } else if (output.isNotEmpty() && output[0] is Array<*>) {
                    // Handle Array<Array<Float>> case
                    val nestedArray = output[0] as Array<*>
                    if (nestedArray.isNotEmpty() && nestedArray[0] is FloatArray) {
                        val innerArray = nestedArray[0] as FloatArray
                        Log.d(TAG, "Encoder output shape: [${nestedArray.size}, ${innerArray.size}] - total elements: ${nestedArray.size * innerArray.size}")
                        // Calculate total size
                        var totalSize = 0
                        for (i in nestedArray.indices) {
                            val subArray = nestedArray[i] as FloatArray
                            totalSize += subArray.size
                        }
                        // Flatten the nested array
                        val flattenedArray = FloatArray(totalSize)
                        var offset = 0
                        for (i in nestedArray.indices) {
                            val subArray = nestedArray[i] as FloatArray
                            System.arraycopy(subArray, 0, flattenedArray, offset, subArray.size)
                            offset += subArray.size
                        }
                        flattenedArray
                    } else {
                        throw IllegalArgumentException("Unexpected encoder output structure: ${output[0]?.javaClass}")
                    }
                } else {
                    throw IllegalArgumentException("Unexpected encoder output type: ${output.javaClass}")
                }
            }
            is FloatArray -> {
                Log.d(TAG, "Encoder output shape: [${output.size}]")
                output
            }
            else -> {
                throw IllegalArgumentException("Unexpected encoder output type: ${output.javaClass}")
            }
        }

        return hiddenStates
    }

    private fun runFirstDecoderStep(bosId: Int, encoderHidden: FloatArray, srcLen: Int): FloatArray {
        // Use the standard decoder model for the first step (without past states)
        val session = decoderSession ?: throw IllegalStateException("Decoder not initialized")

        val inputIdsBuffer = LongBuffer.wrap(longArrayOf(bosId.toLong()))
        val attentionMaskBuffer = LongBuffer.wrap(longArrayOf(1, 1))
        
        // Create the encoder hidden states tensor with the correct shape based on actual sequence length
        val encoderHiddenTensor = OnnxTensor.createTensor(env!!, FloatBuffer.wrap(encoderHidden), longArrayOf(1, srcLen.toLong(), 512))
        
        val encoderAttentionMaskBuffer = LongBuffer.wrap(LongArray(srcLen) { 1 })

        val inputIdsTensor = OnnxTensor.createTensor(env!!, inputIdsBuffer, longArrayOf(1, 1))
        val attentionMaskTensor = OnnxTensor.createTensor(env!!, attentionMaskBuffer, longArrayOf(1, 2))
        val encoderAttentionMaskTensor = OnnxTensor.createTensor(env!!, encoderAttentionMaskBuffer, longArrayOf(1, srcLen.toLong()))

        val inputs: Map<String, OnnxTensor> = mapOf(
            "input_ids" to inputIdsTensor,
            "attention_mask" to attentionMaskTensor,
            "encoder_hidden_states" to encoderHiddenTensor,
            "encoder_attention_mask" to encoderAttentionMaskTensor
        )

        val results = session.run(inputs)
        val output = results[0].value
        Log.d(TAG, "First decoder step output type: ${output.javaClass}")
        
        val logits = when (output) {
            is Array<*> -> {
                if (output.isNotEmpty() && output[0] is FloatArray) {
                    output[0] as FloatArray
                } else if (output.isNotEmpty() && output[0] is Array<*>) {
                    val nestedArray = output[0] as Array<*>
                    if (nestedArray.isNotEmpty() && nestedArray[0] is FloatArray) {
                        nestedArray[0] as FloatArray
                    } else {
                        throw IllegalArgumentException("Unexpected first decoder output structure: ${output[0]?.javaClass}")
                    }
                } else {
                    throw IllegalArgumentException("Unexpected first decoder output type: ${output.javaClass}")
                }
            }
            is FloatArray -> output
            else -> throw IllegalArgumentException("Unexpected first decoder output type: ${output.javaClass}")
        }

        return logits
    }

    private fun runDecoderWithPast(
        nextTokenId: Int,
        attentionMaskLength: Int,
        encoderHidden: FloatArray,
        srcLen: Int,  // Use actual sequence length instead of inputIds.size
        past: Map<String, OnnxTensor>
    ): Pair<FloatArray, Map<String, OnnxTensor>> {
        val session = decoderWithPastSession ?: throw IllegalStateException("Decoder not initialized")

        val inputIdsBuffer = LongBuffer.wrap(longArrayOf(nextTokenId.toLong()))
        val attentionMaskBuffer = LongBuffer.wrap(LongArray(attentionMaskLength) { 1 })
        
        // Create the encoder hidden states tensor with the correct shape based on actual sequence length
        val encoderHiddenTensor = OnnxTensor.createTensor(env!!, FloatBuffer.wrap(encoderHidden), longArrayOf(1, srcLen.toLong(), 512))
        
        val encoderAttentionMaskBuffer = LongBuffer.wrap(LongArray(srcLen) { 1 })

        val inputIdsTensor = OnnxTensor.createTensor(env!!, inputIdsBuffer, longArrayOf(1, 1))
        val attentionMaskTensor = OnnxTensor.createTensor(env!!, attentionMaskBuffer, longArrayOf(1, attentionMaskLength.toLong()))
        val encoderAttentionMaskTensor = OnnxTensor.createTensor(env!!, encoderAttentionMaskBuffer, longArrayOf(1, srcLen.toLong()))

        val inputs = mutableMapOf<String, OnnxTensor>()
        inputs["input_ids"] = inputIdsTensor
        inputs["attention_mask"] = attentionMaskTensor
        inputs["encoder_attention_mask"] = encoderAttentionMaskTensor
        inputs["encoder_hidden_states"] = encoderHiddenTensor
        inputs.putAll(past)

        val results = session.run(inputs)
        val output = results[0].value
        Log.d(TAG, "DecoderWithPast output type: ${output.javaClass}")
        
        val logits = when (output) {
            is Array<*> -> {
                if (output.isNotEmpty() && output[0] is FloatArray) {
                    output[0] as FloatArray
                } else if (output.isNotEmpty() && output[0] is Array<*>) {
                    val nestedArray = output[0] as Array<*>
                    if (nestedArray.isNotEmpty() && nestedArray[0] is FloatArray) {
                        nestedArray[0] as FloatArray
                    } else {
                        throw IllegalArgumentException("Unexpected decoderWithPast output structure: ${output[0]?.javaClass}")
                    }
                } else {
                    throw IllegalArgumentException("Unexpected decoderWithPast output type: ${output.javaClass}")
                }
            }
            is FloatArray -> output
            else -> throw IllegalArgumentException("Unexpected decoderWithPast output type: ${output.javaClass}")
        }

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