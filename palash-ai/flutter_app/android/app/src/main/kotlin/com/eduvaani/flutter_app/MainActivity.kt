package com.eduvaani.flutter_app

import android.content.Context
import android.util.Log
import com.eduvaani.flutter_app.ml.OnDeviceTranslationEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var translationEngine: OnDeviceTranslationEngine? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        translationEngine = OnDeviceTranslationEngine(this)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "eduvaani/on_device_translation").setMethodCallHandler { call, result ->
            when (call.method) {
                "translate" -> {
                    val text = call.argument<String>("text")
                    val sourceLang = call.argument<String>("source_lang")
                    val targetLang = call.argument<String>("target_lang")
                    
                    if (text == null || sourceLang == null || targetLang == null) {
                        result.error("INVALID_ARGS", "Missing required arguments", null)
                        return@setMethodCallHandler
                    }
                    
                    try {
                        val initialized = translationEngine?.initialize() ?: false
                        if (!initialized) {
                            result.error("INIT_FAILED", "Failed to initialize on-device engine", null)
                            return@setMethodCallHandler
                        }
                        
                        val translation = translationEngine?.translate(text, sourceLang, targetLang)
                        if (translation != null) {
                            result.success(mapOf(
                                "success" to true,
                                "translation" to translation
                            ))
                        } else {
                            result.error("TRANSLATION_FAILED", "Translation returned null", null)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Translation failed", e)
                        result.error("TRANSLATION_ERROR", e.message, e.toString())
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    companion object {
        private const val TAG = "MainActivity"
    }
}
