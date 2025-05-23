package com.example.overlay_test

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall // Import MethodCall

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.overlay_test/helper"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
                call, result -> // result here is of type MethodChannel.Result implicitly
            if (call.method == "sum") {
                sum(call, result)
            } else { // It's good practice to handle unrecognised methods
                result.notImplemented()
            }
        }
    } // This brace closes configureFlutterEngine, no extra brace here

    // The sum function should be inside the MainActivity class
    private fun sum(call: MethodCall, result: MethodChannel.Result) { // Correct type for result
        val a = call.argument<Int>("a")
        val b = call.argument<Int>("b")

        if (a != null && b != null) { // Always check for nullability when using argument<T>()
            result.success<Int>(a + b)
        } else {
            result.error("INVALID_ARGUMENTS", "One or both arguments are null", null)
        }
    }
}