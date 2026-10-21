package com.vaultx.vaultx

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.vaultx.vaultx/screen_security"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Default to secure: block screenshots and hide preview in recent apps switcher
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enable" -> {
                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(true)
                }
                "disable" -> {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(true)
                }
                "isSupported" -> {
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
