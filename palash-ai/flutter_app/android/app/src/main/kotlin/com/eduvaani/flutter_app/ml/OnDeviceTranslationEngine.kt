package com.eduvaani.flutter_app.ml

import android.content.Context
import android.util.Log
import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import java.io.IOException
import java.nio.FloatBuffer
import java.nio.LongBuffer

/** On-device greedy IndicTrans2 translation using the export's native K/V cache API. */
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
            Log.i(TAG, "[ON_DEVICE] Already initialized")
            return true
        }

        return try {
            val modelsDir = context.filesDir.resolve(MODELS_DIRECTORY)
            modelsDir.mkdirs()
            for (asset in MODEL_ASSETS) {
                copyAsset(asset, modelsDir.resolve(asset.substringAfterLast('/')))
            }

            env = OrtEnvironment.getEnvironment()
            val options = OrtSession.SessionOptions().apply {
                setIntraOpNumThreads(2)
                addCPU(true)
            }
            encoderSession = env!!.createSession(modelsDir.resolve("encoder_model.onnx").absolutePath, options)
            decoderSession = env!!.createSession(modelsDir.resolve("decoder_model.onnx").absolutePath, options)
            decoderWithPastSession = env!!.createSession(
                modelsDir.resolve("decoder_with_past_model.onnx").absolutePath,
                options
            )

            // Log the actual packaged model contract on every fresh process start.
            logSessionInterface("encoder", encoderSession!!)
            logSessionInterface("decoder", decoderSession!!)
            logSessionInterface("decoder_with_past", decoderWithPastSession!!)
            validateDecoderCacheInterface()

            tokenizer = SentencePieceTokenizer(context).also { sentencePiece ->
                check(sentencePiece.loadModel("$MODELS_DIRECTORY/model.SRC")) {
                    "SentencePiece model.SRC failed to load"
                }
                sentencePiece.loadTargetModel("$MODELS_DIRECTORY/model.TGT")
                check(sentencePiece.loadVocab("$MODELS_DIRECTORY/dict.SRC.json")) {
                    "SentencePiece dict.SRC.json failed to load"
                }
                check(sentencePiece.loadTargetVocab("$MODELS_DIRECTORY/dict.TGT.json")) {
                    "SentencePiece dict.TGT.json failed to load"
                }
                Log.i(TAG, "[ON_DEVICE] tokenizer initialized pieces=${sentencePiece.pieceCount}")
            }
            processor = IndicProcessor()
            initialized = true
            Log.i(TAG, "[ON_DEVICE] initialization completed")
            true
        } catch (error: Exception) {
            Log.e(TAG, "[ON_DEVICE] INITIALIZATION FAILED: ${error.javaClass.simpleName}: ${error.message}", error)
            false
        }
    }

    @Synchronized
    fun translate(text: String, sourceLang: String, targetLang: String): String {
        if (!initialized && !initialize()) {
            throw IllegalStateException("Engine not initialized")
        }
        checkNotNull(tokenizer)
        checkNotNull(processor)
        checkNotNull(encoderSession)
        checkNotNull(decoderSession)
        checkNotNull(decoderWithPastSession)

        Log.i(TAG, "[ON_DEVICE] source language=$sourceLang target language=$targetLang")
        val preprocessed = processor!!.preprocessBatch(listOf(text), sourceLang, targetLang).first()
        val inputIds = tokenizer!!.encode(preprocessed)
        Log.i(TAG, "[ON_DEVICE] preprocessed input=$preprocessed")
        Log.i(TAG, "[ON_DEVICE] token IDs=$inputIds")
        if (inputIds.isEmpty()) return ""

        val encoderHidden = runEncoder(inputIds)
        val srcLen = encoderHidden.size / HIDDEN_SIZE
        require(srcLen > 0 && srcLen * HIDDEN_SIZE == encoderHidden.size) {
            "Unexpected encoder hidden-state size=${encoderHidden.size}"
        }
        Log.i(TAG, "[ON_DEVICE] encoder completed srcLen=$srcLen hiddenStatesLength=${encoderHidden.size}")

        // The model was validated with a single EOS (id 2) decoder seed. Both
        // language tags are already supplied to the encoder in [preprocessed].
        val eosId = tokenizer!!.eosId
        val generatedIds = ArrayList<Int>()
        var step = runFirstDecoderStep(eosId, encoderHidden, srcLen)
        try {
            if (MIN_NEW_TOKENS > 0) {
                suppressToken(step.logits, eosId)
            }
            var nextTokenId = argmax(step.logits)
            generatedIds += nextTokenId
            Log.i(TAG, "[ON_DEVICE] generation step=1 seed=[EOS] token=$nextTokenId")

            var generationStep = 1
            while (nextTokenId != eosId && generationStep < MAX_GENERATION_LENGTH) {
                val previousPast = step.past
                step = runDecoderWithPast(nextTokenId, previousPast, srcLen)
                previousPast.clear()
                applyRepetitionPenalty(step.logits, generatedIds, REPETITION_PENALTY)
                if (generationStep + 1 < MIN_NEW_TOKENS) {
                    suppressToken(step.logits, eosId)
                }
                nextTokenId = argmax(step.logits)
                generatedIds += nextTokenId
                generationStep += 1
                Log.i(TAG, "[ON_DEVICE] generation step=$generationStep token=$nextTokenId")
            }
            if (nextTokenId == eosId) {
                Log.i(TAG, "[ON_DEVICE] EOS reached at step=$generationStep")
            } else {
                Log.w(TAG, "[ON_DEVICE] generation stopped at maxLength=$MAX_GENERATION_LENGTH")
            }
        } finally {
            step.past.clear()
        }

        val contentIds = if (generatedIds.lastOrNull() == eosId) generatedIds.dropLast(1) else generatedIds
        Log.i(TAG, "[ON_DEVICE] final generated IDs=$generatedIds")
        Log.i(TAG, "[ON_DEVICE] content IDs (trailing EOS stripped)=$contentIds")
        return decodeAndPostprocess(contentIds, targetLang).also {
            Log.i(TAG, "[ON_DEVICE] final decoded translation=$it")
        }
    }

    private data class DecoderStep(val logits: FloatArray, val past: PastKeyValues)

    private data class PastKeyValues(
        val tensors: MutableMap<String, FloatArray>,
        val decoderLength: Int
    ) {
        fun clear() = tensors.clear()
    }

    private fun runEncoder(inputIds: List<Int>): FloatArray {
        val inputTensor = createLongTensor(
            LongArray(inputIds.size) { inputIds[it].toLong() },
            longArrayOf(1, inputIds.size.toLong())
        )
        val maskTensor = createLongTensor(LongArray(inputIds.size) { 1L }, longArrayOf(1, inputIds.size.toLong()))
        try {
            val results = encoderSession!!.run(mapOf("input_ids" to inputTensor, "attention_mask" to maskTensor))
            try {
                return flattenFloatTensor(resultValue(results, "last_hidden_state"))
            } finally {
                results.close()
            }
        } finally {
            inputTensor.close()
            maskTensor.close()
        }
    }

    /** First decoder call: [EOS] in, logits plus decoder and encoder K/V caches out. */
    private fun runFirstDecoderStep(seedTokenId: Int, encoderHidden: FloatArray, srcLen: Int): DecoderStep {
        val inputIds = createLongTensor(longArrayOf(seedTokenId.toLong()), longArrayOf(1, 1))
        val hiddenStates = OnnxTensor.createTensor(
            env!!,
            FloatBuffer.wrap(encoderHidden),
            longArrayOf(1, srcLen.toLong(), HIDDEN_SIZE.toLong())
        )
        val encoderMask = createLongTensor(LongArray(srcLen) { 1L }, longArrayOf(1, srcLen.toLong()))
        try {
            val results = decoderSession!!.run(
                mapOf(
                    "input_ids" to inputIds,
                    "encoder_hidden_states" to hiddenStates,
                    "encoder_attention_mask" to encoderMask
                )
            )
            try {
                val cache = mutableMapOf<String, FloatArray>()
                for (layer in 0 until DECODER_LAYERS) {
                    for (attention in ATTENTION_TYPES) {
                        for (component in CACHE_COMPONENTS) {
                            val outputName = "present.$layer.$attention.$component"
                            val inputName = "past_key_values.$layer.$attention.$component"
                            cache[inputName] = flattenFloatTensor(resultValue(results, outputName))
                        }
                    }
                }
                return DecoderStep(
                    logits = flattenFloatTensor(resultValue(results, "logits")),
                    past = PastKeyValues(cache, decoderLength = 1)
                )
            } finally {
                results.close()
            }
        } finally {
            inputIds.close()
            hiddenStates.close()
            encoderMask.close()
        }
    }

    /** Continuation decoder call: newest token plus prior K/V caches in. */
    private fun runDecoderWithPast(newestTokenId: Int, past: PastKeyValues, srcLen: Int): DecoderStep {
        val inputs = mutableMapOf<String, OnnxTensor>()
        inputs["input_ids"] = createLongTensor(longArrayOf(newestTokenId.toLong()), longArrayOf(1, 1))
        inputs["encoder_attention_mask"] = createLongTensor(
            LongArray(srcLen) { 1L },
            longArrayOf(1, srcLen.toLong())
        )
        try {
            for ((name, values) in past.tensors) {
                val sequenceLength = if (name.contains(".decoder.")) past.decoderLength else srcLen
                inputs[name] = OnnxTensor.createTensor(
                    env!!,
                    FloatBuffer.wrap(values),
                    longArrayOf(1, NUM_HEADS.toLong(), sequenceLength.toLong(), HEAD_SIZE.toLong())
                )
            }
            val results = decoderWithPastSession!!.run(inputs)
            try {
                // Continuation returns only self-attention K/V. Cross-attention
                // encoder K/V remains the exact first-step value, unchanged.
                val nextCache = past.tensors.toMutableMap()
                for (layer in 0 until DECODER_LAYERS) {
                    for (component in CACHE_COMPONENTS) {
                        val outputName = "present.$layer.decoder.$component"
                        val inputName = "past_key_values.$layer.decoder.$component"
                        nextCache[inputName] = flattenFloatTensor(resultValue(results, outputName))
                    }
                }
                return DecoderStep(
                    logits = flattenFloatTensor(resultValue(results, "logits")),
                    past = PastKeyValues(nextCache, past.decoderLength + 1)
                )
            } finally {
                results.close()
            }
        } finally {
            for (tensor in inputs.values) tensor.close()
        }
    }

    private fun createLongTensor(values: LongArray, shape: LongArray): OnnxTensor =
        OnnxTensor.createTensor(env!!, LongBuffer.wrap(values), shape)

    private fun resultValue(results: OrtSession.Result, name: String): Any {
        for (entry in results) {
            if (entry.key == name) return entry.value.value
        }
        throw IllegalStateException("Missing ONNX output: $name")
    }

    private fun flattenFloatTensor(value: Any?): FloatArray {
        val flattened = FloatArray(countFloatElements(value))
        copyFloatElements(value, flattened, 0)
        return flattened
    }

    private fun countFloatElements(value: Any?): Int = when (value) {
        is FloatArray -> value.size
        is Array<*> -> value.sumOf { countFloatElements(it) }
        else -> throw IllegalArgumentException("Unexpected tensor value type: ${value?.javaClass}")
    }

    private fun copyFloatElements(value: Any?, output: FloatArray, offset: Int): Int = when (value) {
        is FloatArray -> {
            value.copyInto(output, destinationOffset = offset)
            offset + value.size
        }
        is Array<*> -> {
            var nextOffset = offset
            for (item in value) nextOffset = copyFloatElements(item, output, nextOffset)
            nextOffset
        }
        else -> throw IllegalArgumentException("Unexpected tensor value type: ${value?.javaClass}")
    }

    private fun applyRepetitionPenalty(
        logits: FloatArray,
        generatedIds: Collection<Int>,
        penalty: Float
    ) {
        if (penalty == 1.0f) return
        for (id in generatedIds.toSet()) {
            if (id in logits.indices) {
                val logit = logits[id]
                logits[id] = if (logit < 0) logit * penalty else logit / penalty
            }
        }
    }

    private fun suppressToken(logits: FloatArray, tokenId: Int) {
        if (tokenId in logits.indices) {
            logits[tokenId] = Float.NEGATIVE_INFINITY
        }
    }

    private fun argmax(logits: FloatArray): Int {
        var index = 0
        for (i in 1 until logits.size) {
            if (logits[i] > logits[index]) index = i
        }
        return index
    }

    private fun decodeAndPostprocess(generatedIds: List<Int>, targetLang: String): String {
        tokenizer!!.switchToTargetMode()
        return try {
            val decoded = tokenizer!!.decode(generatedIds)
            processor!!.postprocessBatch(listOf(decoded), targetLang).firstOrNull() ?: decoded
        } finally {
            tokenizer!!.switchToSourceMode()
        }
    }

    private fun logSessionInterface(name: String, session: OrtSession) {
        Log.i(TAG, "[ON_DEVICE] $name inputs (${session.inputNames.size})=${session.inputNames.sorted()}")
        Log.i(TAG, "[ON_DEVICE] $name outputs (${session.outputNames.size})=${session.outputNames.sorted()}")
    }

    private fun validateDecoderCacheInterface() {
        val expectedFirstOutputs = mutableSetOf("logits")
        val expectedCachedInputs = mutableSetOf("input_ids", "encoder_attention_mask")
        for (layer in 0 until DECODER_LAYERS) {
            for (attention in ATTENTION_TYPES) {
                for (component in CACHE_COMPONENTS) {
                    expectedFirstOutputs += "present.$layer.$attention.$component"
                    expectedCachedInputs += "past_key_values.$layer.$attention.$component"
                }
            }
        }
        check(decoderSession!!.outputNames.containsAll(expectedFirstOutputs)) {
            "decoder_model.onnx does not expose the required present K/V outputs"
        }
        check(decoderWithPastSession!!.inputNames.containsAll(expectedCachedInputs)) {
            "decoder_with_past_model.onnx does not accept the required past K/V inputs"
        }
        check(decoderWithPastSession!!.outputNames.contains("logits")) {
            "decoder_with_past_model.onnx does not expose logits"
        }
    }

    @Throws(IOException::class)
    private fun copyAsset(assetPath: String, destination: java.io.File) {
        destination.parentFile?.mkdirs()
        context.assets.open(assetPath).use { input ->
            destination.outputStream().use { output -> input.copyTo(output) }
        }
    }

    companion object {
        private const val TAG = "OnDeviceTranslationEngine"
        private const val MODELS_DIRECTORY = "models/indictrans2/int8"
        private const val DECODER_LAYERS = 18
        private const val NUM_HEADS = 8
        private const val HEAD_SIZE = 64
        private const val HIDDEN_SIZE = 512
        private const val MAX_GENERATION_LENGTH = 256
        private const val REPETITION_PENALTY = 1.2f
        private const val MIN_NEW_TOKENS = 2
        private val ATTENTION_TYPES = listOf("decoder", "encoder")
        private val CACHE_COMPONENTS = listOf("key", "value")
        private val MODEL_ASSETS = listOf(
            "$MODELS_DIRECTORY/encoder_model.onnx",
            "$MODELS_DIRECTORY/decoder_model.onnx",
            "$MODELS_DIRECTORY/decoder_with_past_model.onnx",
            "$MODELS_DIRECTORY/model.SRC",
            "$MODELS_DIRECTORY/model.TGT",
            "$MODELS_DIRECTORY/dict.SRC.json",
            "$MODELS_DIRECTORY/dict.TGT.json"
        )
    }
}
