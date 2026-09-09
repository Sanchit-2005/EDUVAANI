package com.eduvaani.flutter_app

import android.content.Intent
import android.os.Bundle
import android.util.Log
import com.eduvaani.flutter_app.ml.OnDeviceTranslationEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class MainActivity : FlutterActivity() {
    private var translationEngine: OnDeviceTranslationEngine? = null

    // Background scope for all ONNX init and inference work.
    // SupervisorJob means one failing coroutine does not cancel others.
    private val engineScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleTranslationIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleTranslationIntent(intent)
    }

    private fun handleTranslationIntent(intent: Intent?) {
        val text = intent?.getStringExtra("text") ?: return
        val sourceLang = intent.getStringExtra("source_lang") ?: "hin_Deva"
        val targetLang = intent.getStringExtra("target_lang") ?: "sat_Olck"
        Log.i(TAG, "=== INTENT TRANSLATE TRIGGERED === text='$text' src='$sourceLang' tgt='$targetLang'")
        engineScope.launch {
            try {
                if (translationEngine == null) {
                    translationEngine = OnDeviceTranslationEngine(this@MainActivity)
                }
                val initOk = translationEngine?.initialize() ?: false
                if (!initOk) {
                    Log.e(TAG, "=== INTENT TRANSLATE FAILED: Engine init returned false ===")
                    return@launch
                }
                val result = translationEngine?.translate(text, sourceLang, targetLang)
                Log.i(TAG, "=== INTENT TRANSLATE SUCCESS === result='$result'")
            } catch (e: Exception) {
                Log.e(TAG, "=== INTENT TRANSLATE ERROR ===", e)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        Log.d(TAG, "=== INITIALIZING TRANSLATION ENGINE ===")
        translationEngine = OnDeviceTranslationEngine(this)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "eduvaani/on_device_translation"
        ).setMethodCallHandler { call, result ->
            Log.d(TAG, "=== METHOD CHANNEL ENTERED === method=${call.method}")

            when (call.method) {
                "translate" -> {
                    val text = call.argument<String>("text")
                    val sourceLang = call.argument<String>("source_lang")
                    val targetLang = call.argument<String>("target_lang")

                    Log.d(TAG, "translate: text='$text' src='$sourceLang' tgt='$targetLang'")

                    if (text == null || sourceLang == null || targetLang == null) {
                        result.error("INVALID_ARGS", "Missing required arguments", null)
                        return@setMethodCallHandler
                    }

                    // Run ALL model work on the IO dispatcher — never on the main thread.
                    engineScope.launch {
                        try {
                            val engine = translationEngine
                            if (engine == null) {
                                withContext(Dispatchers.Main) {
                                    result.error("NO_ENGINE", "Engine not created", null)
                                }
                                return@launch
                            }

                            // initialize() is idempotent; it returns immediately if already done.
                            val initialized = engine.initialize()
                            if (!initialized) {
                                Log.e(TAG, "Engine initialization failed")
                                withContext(Dispatchers.Main) {
                                    result.error("INIT_FAILED", "Failed to initialize on-device engine", null)
                                }
                                return@launch
                            }

                            val translation = engine.translate(text, sourceLang, targetLang)
                            Log.d(TAG, "translate result: $translation")

                            withContext(Dispatchers.Main) {
                                if (translation.isNotEmpty()) {
                                    result.success(
                                        mapOf("success" to true, "translation" to translation)
                                    )
                                } else {
                                    result.error("EMPTY_RESULT", "Translation returned empty string", null)
                                }
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "=== NATIVE TRANSLATION FAILED ===", e)
                            withContext(Dispatchers.Main) {
                                result.error("TRANSLATION_ERROR", e.message, e.toString())
                            }
                        }
                    }
                }

                "initialize" -> {
                    Log.d(TAG, "initialize method called")
                    engineScope.launch {
                        try {
                            val initialized = translationEngine?.initialize() ?: false
                            Log.d(TAG, "initialize result: $initialized")
                            withContext(Dispatchers.Main) {
                                result.success(initialized)
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "=== INITIALIZE METHOD FAILED ===", e)
                            withContext(Dispatchers.Main) {
                                result.error("INIT_ERROR", e.message, e.toString())
                            }
                        }
                    }
                }

                "isAvailable" -> {
                    Log.d(TAG, "isAvailable method called")
                    engineScope.launch {
                        try {
                            val available = translationEngine?.initialize() ?: false
                            Log.d(TAG, "isAvailable result: $available")
                            withContext(Dispatchers.Main) {
                                result.success(available)
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "=== ISAVAILABLE METHOD FAILED ===", e)
                            withContext(Dispatchers.Main) {
                                result.error("CHECK_ERROR", e.message, e.toString())
                            }
                        }
                    }
                }

                else -> {
                    Log.w(TAG, "Unknown method: ${call.method}")
                    result.notImplemented()
                }
            }
        }
    }

    override fun onDestroy() {
        engineScope.cancel()
        super.onDestroy()
    }

    companion object {
        private const val TAG = "MainActivity"
    }
}
