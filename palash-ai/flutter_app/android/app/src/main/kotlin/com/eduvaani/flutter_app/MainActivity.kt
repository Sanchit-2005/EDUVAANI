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
        
        Log.d("EDUVAANI_CHANNEL", "=== INITIALIZING TRANSLATION ENGINE ===")
        translationEngine = OnDeviceTranslationEngine(this)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "eduvaani/on_device_translation").setMethodCallHandler { call, result ->
            Log.d("EDUVAANI_CHANNEL", "=== METHOD CHANNEL ENTERED === method=${call.method}")
            
            when (call.method) {
                "translate" -> {
                    val text = call.argument<String>("text")
                    val sourceLang = call.argument<String>("source_lang")
                    val targetLang = call.argument<String>("target_lang")
                    
                    Log.d("EDUVAANI_CHANNEL", "Translation request: text='${text}', source='${sourceLang}', target='${targetLang}'")
                    
                    if (text == null || sourceLang == null || targetLang == null) {
                        Log.e("EDUVAANI_CHANNEL", "Missing required arguments")
                        result.error("INVALID_ARGS", "Missing required arguments", null)
                        return@setMethodCallHandler
                    }
                    
                    try {
                        Log.d("EDUVAANI_CHANNEL", "Checking engine initialization status...")
                        val initialized = translationEngine?.initialize() ?: false
                        Log.d("EDUVAANI_CHANNEL", "Engine initialized status: $initialized")
                        
                        if (!initialized) {
                            Log.e("EDUVAANI_CHANNEL", "=== ENGINE INITIALIZATION FAILED ===")
                            result.error("INIT_FAILED", "Failed to initialize on-device engine", null)
                            return@setMethodCallHandler
                        }
                        
                        Log.d("EDUVAANI_CHANNEL", "Calling translation engine...")
                        val translation = translationEngine?.translate(text, sourceLang, targetLang)
                        Log.d("EDUVAANI_CHANNEL", "Translation result: $translation")
                        
                        if (translation != null) {
                            result.success(mapOf(
                                "success" to true,
                                "translation" to translation
                            ))
                        } else {
                            Log.e("EDUVAANI_CHANNEL", "Translation returned null")
                            result.error("TRANSLATION_FAILED", "Translation returned null", null)
                        }
                    } catch (e: Exception) {
                        Log.e("EDUVAANI_CHANNEL", "=== NATIVE TRANSLATION FAILED ===", e)
                        result.error("TRANSLATION_ERROR", e.message, e.toString())
                    }
                }
                "initialize" -> {
                    Log.d("EDUVAANI_CHANNEL", "Initialize method called")
                    try {
                        val initialized = translationEngine?.initialize() ?: false
                        Log.d("EDUVAANI_CHANNEL", "Initialize result: $initialized")
                        result.success(initialized)
                    } catch (e: Exception) {
                        Log.e("EDUVAANI_CHANNEL", "=== INITIALIZE METHOD FAILED ===", e)
                        result.error("INIT_ERROR", e.message, e.toString())
                    }
                }
                "isAvailable" -> {
                    Log.d("EDUVAANI_CHANNEL", "isAvailable method called")
                    try {
                        val available = translationEngine?.initialize() ?: false
                        Log.d("EDUVAANI_CHANNEL", "isAvailable result: $available")
                        result.success(available)
                    } catch (e: Exception) {
                        Log.e("EDUVAANI_CHANNEL", "=== ISAVAILABLE METHOD FAILED ===", e)
                        result.error("CHECK_ERROR", e.message, e.toString())
                    }
                }
                else -> {
                    Log.w("EDUVAANI_CHANNEL", "Unknown method: ${call.method}")
                    result.notImplemented()
                }
            }
        }
    }

    companion object {
        private const val TAG = "MainActivity"
    }
}