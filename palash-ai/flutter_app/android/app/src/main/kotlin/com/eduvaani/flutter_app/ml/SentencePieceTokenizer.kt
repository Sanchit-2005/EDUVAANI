package com.eduvaani.flutter_app.ml

import android.content.Context
import android.util.Log
import org.json.JSONObject
import java.io.DataInputStream
import java.io.IOException
import java.nio.ByteBuffer
import java.nio.ByteOrder

class SentencePieceTokenizer(private val context: Context) {
    private val spmPieceToId = mutableMapOf<String, Int>()
    private val spmIdToPiece = mutableMapOf<Int, String>()
    private val spmScores = mutableMapOf<Int, Float>()
    private val trieRoot = TrieNode()

    private val srcVocabPieceToId = mutableMapOf<String, Int>()
    private val srcVocabIdToPiece = mutableMapOf<Int, String>()
    private val tgtVocabPieceToId = mutableMapOf<String, Int>()
    private val tgtVocabIdToPiece = mutableMapOf<Int, String>()

    private var activePieceToId = srcVocabPieceToId
    private var activeIdToPiece = srcVocabIdToPiece

    var unkId: Int = 3
    var bosId: Int = 0
    var eosId: Int = 2
    var padId: Int = 1
        private set

    val pieceCount get() = activePieceToId.size

    private var loaded = false

    fun loadModel(assetPath: String): Boolean {
        return try {
            loadModelProtobuf(assetPath)
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load SentencePiece model: $assetPath", e)
            false
        }
    }

    fun loadVocab(assetPath: String): Boolean {
        return try {
            context.assets.open(assetPath).use { input ->
                val json = JSONObject(input.readBytes().toString(Charsets.UTF_8))
                val keys = json.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    val id = json.getInt(key)
                    srcVocabPieceToId[key] = id
                    srcVocabIdToPiece[id] = key
                }
                unkId = srcVocabPieceToId["<unk>"] ?: unkId
                bosId = srcVocabPieceToId["<s>"] ?: bosId
                eosId = srcVocabPieceToId["</s>"] ?: eosId
                padId = srcVocabPieceToId["<pad>"] ?: padId
                true
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load vocab: $assetPath", e)
            false
        }
    }

    fun loadTargetVocab(assetPath: String): Boolean {
        return try {
            context.assets.open(assetPath).use { input ->
                val json = JSONObject(input.readBytes().toString(Charsets.UTF_8))
                val keys = json.keys()
                while (keys.hasNext()) {
                    val key = keys.next()
                    val id = json.getInt(key)
                    tgtVocabPieceToId[key] = id
                    tgtVocabIdToPiece[id] = key
                }
                true
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load target vocab: $assetPath", e)
            false
        }
    }

    fun switchToSourceMode() {
        activePieceToId = srcVocabPieceToId
        activeIdToPiece = srcVocabIdToPiece
        Log.d(TAG, "[SP] mode=SRC")
    }

    fun switchToTargetMode() {
        activePieceToId = tgtVocabPieceToId
        activeIdToPiece = tgtVocabIdToPiece
        Log.d(TAG, "[SP] mode=TGT")
    }

    fun encode(text: String): List<Int> {
        if (!loaded) throw IllegalStateException("Model not loaded")
        Log.d(TAG, "[SP] encode input='$text'")

        // Parse preprocessed text: "src_lang tgt_lang actual_text"
        val parts = text.split(" ", limit = 3)
        if (parts.size < 3) {
            Log.w(TAG, "[SP] preprocessed text does not contain language tags")
            return emptyList()
        }

        val srcLang = parts[0]
        val tgtLang = parts[1]
        val actualText = parts[2]
        Log.d(TAG, "[SP] src_lang=$srcLang tgt_lang=$tgtLang text='$actualText'")

        // Ensure source mode for encoding
        switchToSourceMode()

        // Viterbi tokenize the actual text
        val pieces = viterbiEncode(actualText)
        Log.d(TAG, "[SP] spm pieces=$pieces")

        // Map pieces to IDs using source vocabulary JSON
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
        if (!loaded) throw IllegalStateException("Model not loaded")
        val vocabulary = if (activeIdToPiece === tgtVocabIdToPiece) "TGT" else "SRC"
        Log.d(TAG, "[SP] decode vocabulary=$vocabulary input_ids=$ids")
        val pieces = ids.map { activeIdToPiece[it] ?: "<unk>" }
        val result = decodePieces(pieces)
        Log.d(TAG, "[SP] decoded text='$result'")
        return result
    }

    private fun viterbiEncode(text: String): List<String> {
        val normalized = text.replace(' ', '▁')
        val n = normalized.length
        if (n == 0) return emptyList()

        val dp = FloatArray(n + 1) { Float.NEGATIVE_INFINITY }
        val parent = Array(n + 1) { Pair(-1, -1) }
        dp[0] = 0f

        for (i in 0 until n) {
            if (dp[i] == Float.NEGATIVE_INFINITY) continue

            var node: TrieNode? = trieRoot
            var j = i
            while (node != null && j < n) {
                val char = normalized[j].toString()
                node = node.children[char]
                if (node != null) {
                    if (node.id != -1) {
                        val score = node.score
                        val newScore = dp[i] + score
                        val endPos = j + 1
                        if (newScore > dp[endPos]) {
                            dp[endPos] = newScore
                            parent[endPos] = Pair(i, node.id)
                        }
                    }
                    j++
                }
            }
        }

        if (dp[n] == Float.NEGATIVE_INFINITY) {
            Log.w(TAG, "[SP] no complete segmentation, falling back to UNK per char")
            return List(n) { "<unk>" }
        }

        val result = mutableListOf<String>()
        var pos = n
        while (pos > 0) {
            val (prev, pieceId) = parent[pos]
            result.add(spmIdToPiece[pieceId] ?: "<unk>")
            pos = prev
        }
        result.reverse()
        return result
    }

    private fun decodePieces(pieces: List<String>): String {
        val sb = StringBuilder()
        for (piece in pieces) {
            if (piece == "</s>" || piece == "<s>" || piece == "<pad>") continue
            if (piece.startsWith("▁")) {
                if (sb.isNotEmpty() && !sb.endsWith(" ")) {
                    sb.append(" ")
                }
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
    private fun loadModelProtobuf(assetPath: String) {
        context.assets.open(assetPath).use { input ->
            val data = input.readBytes()
            val buffer = ByteBuffer.wrap(data).order(ByteOrder.LITTLE_ENDIAN)

            while (buffer.hasRemaining()) {
                val tag = readVarint(buffer)
                val fieldNumber = (tag ushr 3).toInt()
                val wireType = (tag and 0x7).toInt()

                when (fieldNumber) {
                    1 -> { // repeated SentencePiece
                        val pieceData = readLengthDelimited(buffer)
                        val piece = parseSentencePiece(pieceData)
                        val id = spmPieceToId.size
                        spmPieceToId[piece.first] = id
                        spmIdToPiece[id] = piece.first
                        spmScores[id] = piece.second
                        addToTrie(piece.first, id, piece.second)
                    }
                    2 -> { // version
                        val version = readVarint(buffer).toInt()
                        Log.d(TAG, "Model version: $version")
                    }
                    5 -> { // unk_id
                        unkId = readVarint(buffer).toInt()
                    }
                    6 -> { // bos_id
                        bosId = readVarint(buffer).toInt()
                    }
                    7 -> { // eos_id
                        eosId = readVarint(buffer).toInt()
                    }
                    8 -> { // pad_id
                        padId = readVarint(buffer).toInt()
                    }
                    9 -> { // user_defined_symbols
                        val length = readVarint(buffer).toInt()
                        val bytes = ByteArray(length)
                        buffer.get(bytes)
                    }
                    10 -> { // normalization_rule_byte_escape
                        val length = readVarint(buffer).toInt()
                        val bytes = ByteArray(length)
                        buffer.get(bytes)
                    }
                    else -> skipField(buffer, wireType)
                }
            }

            loaded = true
            Log.d(TAG, "Loaded ${spmPieceToId.size} SentencePiece pieces; bos=$bosId eos=$eosId unk=$unkId pad=$padId")
        }
    }

    private fun parseSentencePiece(data: ByteArray): Pair<String, Float> {
        val buffer = ByteBuffer.wrap(data).order(ByteOrder.LITTLE_ENDIAN)
        var piece = ""
        var score = 0.0f

        while (buffer.hasRemaining()) {
            val tag = readVarint(buffer)
            val fieldNumber = (tag ushr 3).toInt()
            val wireType = (tag and 0x7).toInt()

            when (fieldNumber) {
                1 -> { // piece
                    val bytes = readLengthDelimited(buffer)
                    piece = String(bytes, Charsets.UTF_8)
                }
                2 -> { // score
                    score = buffer.float
                }
                3 -> { // type
                    readVarint(buffer)
                }
                else -> skipField(buffer, wireType)
            }
        }

        return Pair(piece, score)
    }

    private fun addToTrie(piece: String, id: Int, score: Float) {
        var node = trieRoot
        for (char in piece) {
            node = node.children.getOrPut(char.toString()) { TrieNode() }
        }
        node.id = id
        node.score = score
    }

    private fun readVarint(buffer: ByteBuffer): Long {
        var result = 0L
        var shift = 0
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
        val bytes = ByteArray(length)
        buffer.get(bytes)
        return bytes
    }

    private fun skipField(buffer: ByteBuffer, wireType: Int) {
        when (wireType) {
            0 -> readVarint(buffer)
            1 -> buffer.position(buffer.position() + 8)
            2 -> {
                val length = readVarint(buffer).toInt()
                buffer.position(buffer.position() + length)
            }
            5 -> buffer.position(buffer.position() + 4)
            else -> throw IOException("Unknown wire type: $wireType")
        }
    }

    private class TrieNode {
        val children = mutableMapOf<String, TrieNode>()
        var id: Int = -1
        var score: Float = 0f
    }

    companion object {
        private const val TAG = "SentencePieceTokenizer"
    }
}
