package com.eduvaani.flutter_app.ml

import android.content.Context
import android.util.Log
import org.json.JSONObject
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder

class SentencePieceTokenizer(private val context: Context) {

    // ── SRC SentencePiece data (used for encoding input text) ─────────────────
    private val srcSpmPieceToId = mutableMapOf<String, Int>()
    private val srcSpmIdToPiece = mutableMapOf<Int, String>()
    private val srcSpmScores    = mutableMapOf<String, Float>()

    // ── TGT SentencePiece data (used for decoding output tokens) ──────────────
    private val tgtSpmPieceToId = mutableMapOf<String, Int>()
    private val tgtSpmIdToPiece = mutableMapOf<Int, String>()
    private val tgtSpmScores    = mutableMapOf<String, Float>()

    // ── Fairseq vocab JSON maps ────────────────────────────────────────────────
    private val srcVocabPieceToId = mutableMapOf<String, Int>()
    private val srcVocabIdToPiece = mutableMapOf<Int, String>()
    private val tgtVocabPieceToId = mutableMapOf<String, Int>()
    private val tgtVocabIdToPiece = mutableMapOf<Int, String>()

    // Active decode vocabulary — switched before decode()
    private var activeIdToPiece = srcVocabIdToPiece

    var unkId:     Int = 3
    var bosId:     Int = 0
    var eosId:     Int = 2
    var padId:     Int = 1
        private set
    /** SRC-vocab ID of the target language tag (e.g. sat_Olck=29925).
     *  Set during loadVocab() from dict.SRC.json. Used as the forced BOS
     *  token to steer the decoder towards the target language. */
    var tgtLangId: Int = -1
        private set

    val pieceCount get() = srcSpmPieceToId.size

    private var srcLoaded = false
    private var tgtLoaded = false
    val loaded get() = srcLoaded   // encode() only needs SRC to be ready

    // ── Public load API ───────────────────────────────────────────────────────

    /** Load model.SRC — used for tokenising the *source* (input) text. */
    fun loadModel(assetPath: String): Boolean {
        return try {
            Log.d(TAG, "Loading SRC model from asset: $assetPath")
            loadModelProtobuf(
                assetPath        = assetPath,
                pieceToId        = srcSpmPieceToId,
                idToPiece        = srcSpmIdToPiece,
                scores           = srcSpmScores,
                isSrc            = true
            )
            srcLoaded = true
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load SRC SentencePiece model: $assetPath", e)
            false
        }
    }

    /** Load model.TGT — used for de-tokenising the *target* (output) tokens. */
    fun loadTargetModel(assetPath: String): Boolean {
        return try {
            Log.d(TAG, "Loading TGT model from asset: $assetPath")
            loadModelProtobuf(
                assetPath        = assetPath,
                pieceToId        = tgtSpmPieceToId,
                idToPiece        = tgtSpmIdToPiece,
                scores           = tgtSpmScores,
                isSrc            = false
            )
            tgtLoaded = true
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load TGT SentencePiece model: $assetPath", e)
            false
        }
    }

    fun loadVocab(assetPath: String): Boolean {
        return try {
            Log.d(TAG, "Loading SRC vocab from asset: $assetPath")
            context.assets.open(assetPath).use { input ->
                val json = JSONObject(input.readBytes().toString(Charsets.UTF_8))
                val keys = json.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    val id  = json.getInt(key)
                    srcVocabPieceToId[key] = id
                    srcVocabIdToPiece[id]  = key
                }
                unkId = srcVocabPieceToId["<unk>"] ?: unkId
                bosId = srcVocabPieceToId["<s>"]   ?: bosId
                eosId = srcVocabPieceToId["</s>"]  ?: eosId
                padId = srcVocabPieceToId["<pad>"] ?: padId
                true
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load SRC vocab: $assetPath", e)
            false
        }
    }

    fun loadTargetVocab(assetPath: String): Boolean {
        return try {
            Log.d(TAG, "Loading TGT vocab from asset: $assetPath")
            context.assets.open(assetPath).use { input ->
                val json = JSONObject(input.readBytes().toString(Charsets.UTF_8))
                val keys = json.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    val id  = json.getInt(key)
                    tgtVocabPieceToId[key] = id
                    tgtVocabIdToPiece[id]  = key
                }
                true
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load TGT vocab: $assetPath", e)
            false
        }
    }

    // ── Mode switching ────────────────────────────────────────────────────────

    fun switchToSourceMode() {
        activeIdToPiece = srcVocabIdToPiece
        Log.d(TAG, "[SP] mode=SRC")
    }

    fun switchToTargetMode() {
        activeIdToPiece = tgtVocabIdToPiece
        Log.d(TAG, "[SP] mode=TGT")
    }

    // ── Encode / Decode ───────────────────────────────────────────────────────

    fun encode(text: String): List<Int> {
        if (!srcLoaded) throw IllegalStateException("SRC model not loaded")
        Log.d(TAG, "[SP] encode input='$text'")

        // Preprocessed text format: "src_lang tgt_lang actual_text"
        val parts = text.split(" ", limit = 3)
        if (parts.size < 3) {
            Log.w(TAG, "[SP] preprocessed text does not contain language tags")
            return emptyList()
        }

        val srcLang    = parts[0]
        val tgtLang    = parts[1]
        val actualText = parts[2]
        Log.d(TAG, "[SP] src_lang=$srcLang tgt_lang=$tgtLang text='$actualText'")

        // Cache the SRC-vocab ID of the target language tag so the engine can
        // use it as the forced BOS when seeding the decoder.
        tgtLangId = srcVocabPieceToId[tgtLang] ?: unkId
        Log.d(TAG, "[SP] tgtLangId=$tgtLangId")

        // Tokenise using BPE merges matching the IndicTrans2 SentencePiece BPE model
        val pieces = bpeEncode(actualText, srcSpmScores)
        Log.d(TAG, "[SP] spm pieces=$pieces")

        // Map piece strings to IDs using the SRC fairseq vocab JSON
        val ids = mutableListOf<Int>()
        ids.add(srcVocabPieceToId[srcLang] ?: unkId)
        ids.add(srcVocabPieceToId[tgtLang] ?: unkId)
        for (piece in pieces) {
            ids.add(srcVocabPieceToId[piece] ?: unkId)
        }
        ids.add(eosId)

        Log.d(TAG, "[SP] output_ids=$ids")
        return ids
    }

    fun decode(ids: List<Int>): String {
        val vocabulary = if (activeIdToPiece === tgtVocabIdToPiece) "TGT" else "SRC"
        Log.d(TAG, "[SP] decode vocabulary=$vocabulary input_ids=$ids")
        val pieces = ids.map { activeIdToPiece[it] ?: "<unk>" }
        val result = decodePieces(pieces)
        Log.d(TAG, "[SP] decoded text='$result'")
        return result
    }

    private fun bpeSegmentWord(word: String, pieceToScore: Map<String, Float>): List<String> {
        val symbols = ArrayList<String>(word.length)
        for (c in word) {
            symbols.add(c.toString())
        }
        while (symbols.size > 1) {
            var bestPair: String? = null
            var bestScore = Float.NEGATIVE_INFINITY
            var bestIdx = -1
            for (i in 0 until symbols.size - 1) {
                val pair = symbols[i] + symbols[i + 1]
                val score = pieceToScore[pair]
                if (score != null && score > bestScore) {
                    bestScore = score
                    bestPair = pair
                    bestIdx = i
                }
            }
            if (bestIdx == -1 || bestPair == null) break
            symbols[bestIdx] = bestPair
            symbols.removeAt(bestIdx + 1)
        }
        return symbols
    }

    private fun bpeEncode(text: String, pieceToScore: Map<String, Float>): List<String> {
        val words = text.split(" ")
        val pieces = mutableListOf<String>()
        for (w in words) {
            if (w.isEmpty()) continue
            pieces.addAll(bpeSegmentWord("\u2581$w", pieceToScore))
        }
        return pieces
    }

    private fun decodePieces(pieces: List<String>): String {
        val sb = StringBuilder()
        for (piece in pieces) {
            if (piece == "</s>" || piece == "<s>" || piece == "<pad>") continue
            if (piece.startsWith("▁")) {
                if (sb.isNotEmpty() && !sb.endsWith(" ")) sb.append(" ")
                sb.append(piece.substring(1))
            } else if (piece == "<unk>") {
                sb.append("?")
            } else {
                sb.append(piece)
            }
        }
        return sb.toString().trim()
    }

    @Throws(IOException::class)
    private fun loadModelProtobuf(
        assetPath : String,
        pieceToId : MutableMap<String, Int>,
        idToPiece : MutableMap<Int, String>,
        scores    : MutableMap<String, Float>,
        isSrc     : Boolean
    ) {
        Log.d(TAG, "Starting to load protobuf model from: $assetPath")
        context.assets.open(assetPath).use { input ->
            val data   = input.readBytes()
            Log.d(TAG, "Loaded ${data.size} bytes from $assetPath")
            val buffer = ByteBuffer.wrap(data).order(ByteOrder.LITTLE_ENDIAN)

            var position = 0
            while (buffer.hasRemaining()) {
                position = buffer.position()
                try {
                    val tag         = readVarint(buffer)
                    val fieldNumber = (tag ushr 3).toInt()
                    val wireType    = (tag and 0x7).toInt()

                    when (fieldNumber) {
                        1 -> { // repeated SentencePiece
                            val pieceData = readLengthDelimited(buffer)
                            val piece     = parseSentencePiece(pieceData)
                            val id        = pieceToId.size
                            pieceToId[piece.first] = id
                            idToPiece[id]          = piece.first
                            scores[piece.first]    = piece.second
                        }
                        2 -> skipField(buffer, wireType)  // trainer_spec
                        3 -> skipField(buffer, wireType)  // normalizer_spec
                        5 -> {
                            val v = readVarint(buffer).toInt()
                            if (isSrc) unkId = v
                        }
                        6 -> {
                            val v = readVarint(buffer).toInt()
                            if (isSrc) bosId = v
                        }
                        7 -> {
                            val v = readVarint(buffer).toInt()
                            if (isSrc) eosId = v
                        }
                        8 -> {
                            val v = readVarint(buffer).toInt()
                            if (isSrc) padId = v
                        }
                        else -> skipField(buffer, wireType)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error processing protobuf field at position $position: ${e.message}", e)
                    throw e
                }
            }

            Log.d(TAG, "Loaded ${pieceToId.size} pieces from $assetPath; " +
                    "bos=$bosId eos=$eosId unk=$unkId pad=$padId")
        }
    }

    private fun parseSentencePiece(data: ByteArray): Pair<String, Float> {
        val buffer = ByteBuffer.wrap(data).order(ByteOrder.LITTLE_ENDIAN)
        var piece  = ""
        var score  = 0.0f

        while (buffer.hasRemaining()) {
            val tag         = readVarint(buffer)
            val fieldNumber = (tag ushr 3).toInt()
            val wireType    = (tag and 0x7).toInt()

            when (fieldNumber) {
                1 -> piece = String(readLengthDelimited(buffer), Charsets.UTF_8)
                2 -> score = buffer.float
                3 -> readVarint(buffer) // type — skip
                else -> skipField(buffer, wireType)
            }
        }

        return Pair(piece, score)
    }

    private fun readVarint(buffer: ByteBuffer): Long {
        var result = 0L
        var shift  = 0
        while (buffer.hasRemaining()) {
            val b = buffer.get().toLong() and 0xFF
            result = result or ((b and 0x7F) shl shift)
            if ((b and 0x80) == 0L) break
            shift += 7
        }
        return result
    }

    private fun readLengthDelimited(buffer: ByteBuffer): ByteArray {
        val length = readVarint(buffer).toInt()
        val bytes  = ByteArray(length)
        buffer.get(bytes)
        return bytes
    }

    private fun skipField(buffer: ByteBuffer, wireType: Int) {
        when (wireType) {
            0 -> readVarint(buffer)
            1 -> {
                if (buffer.remaining() >= 8) buffer.position(buffer.position() + 8)
                else buffer.position(buffer.limit())
            }
            2 -> {
                val length    = readVarint(buffer).toInt()
                val remaining = buffer.remaining()
                buffer.position(buffer.position() + length.coerceAtMost(remaining))
            }
            3 -> throw IOException("START_GROUP wire type is not supported")
            4 -> { /* END_GROUP — no-op */ }
            5 -> {
                if (buffer.remaining() >= 4) buffer.position(buffer.position() + 4)
                else buffer.position(buffer.limit())
            }
            else -> throw IOException("Unknown wire type: $wireType")
        }
    }

    companion object {
        private const val TAG = "SentencePieceTokenizer"
    }
}
