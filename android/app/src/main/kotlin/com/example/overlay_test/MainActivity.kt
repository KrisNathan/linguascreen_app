package com.example.overlay_test

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall

class MainActivity: FlutterActivity() {

    private val CHANNEL = "com.example.overlay_test/helper"
    private lateinit var methodChannel: MethodChannel

    // Unique ID for caching the FlutterEngine
    companion object {
        const val ENGINE_ID = "my_flutter_engine_id"
    }

    private lateinit var mediaProjectionManager: MediaProjectionManager
    private val TAG = "MainActivity"

    private val SCREEN_CAPTURE_REQUEST_CODE = 1001

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Cache the FlutterEngine so it can be accessed by the ScreenCaptureService
        FlutterEngineCache.getInstance().put(ENGINE_ID, flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "bringAppToForeground" -> {
                    bringAppToForeground(call, result)
                }
                "handleSumMethod" -> { // Renamed method
                    handleSumMethod(call, result)
                }
                "startScreenCapture" -> {
                    // Request permission. The result will be handled in onActivityResult.
                    // The actual screenshot result will be sent back from the service via methodChannel.invokeMethod.
                    requestScreenCapturePermission()
                    result.success(null) // Acknowledge the request immediately
                }
                "stopScreenCapture" -> {
                    // Send an intent to the service to stop capture
                    val serviceIntent = Intent(this, ScreenCaptureService::class.java).apply {
                        action = ScreenCaptureService.ACTION_STOP
                    }
                    startService(serviceIntent) // Start the service (or send command to existing one)
                    result.success(true) // Acknowledge the stop request
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == SCREEN_CAPTURE_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK) {
                if (data != null) {
                    // Permission granted, start the foreground service and pass MediaProjection data
                    val serviceIntent = Intent(this, ScreenCaptureService::class.java).apply {
                        action = ScreenCaptureService.ACTION_START
                        putExtra(ScreenCaptureService.EXTRA_RESULT_CODE, resultCode)
                        putExtra(ScreenCaptureService.EXTRA_DATA_INTENT, data)
                        putExtra(ScreenCaptureService.EXTRA_CHANNEL_NAME, CHANNEL) // Pass channel name for service to use
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        // For Android Oreo (API 26) and above, must use startForegroundService
                        startForegroundService(serviceIntent)
                    } else {
                        startService(serviceIntent)
                    }
                    Log.d(TAG, "ScreenCaptureService started with MediaProjection data.")
                } else {
                    Log.e(TAG, "MediaProjection data is null after permission granted.")
                    // Inform Dart about the error if data is null
                    methodChannel.invokeMethod("screenCaptureError", mapOf("code" to "DATA_NULL", "message" to "MediaProjection data was null after permission granted."))
                }
            } else {
                Log.e(TAG, "User denied screen capture permission.")
                // Inform Dart about the permission denial
                methodChannel.invokeMethod("screenCaptureError", mapOf("code" to "PERMISSION_DENIED", "message" to "User denied screen capture permission."))
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val targetRoute = intent.getStringExtra("targetRoute")
        if (targetRoute != null) {
            methodChannel.invokeMethod("navigateToPage", targetRoute)
        }
    }

    private fun requestScreenCapturePermission() {
        val captureIntent = mediaProjectionManager.createScreenCaptureIntent()
        startActivityForResult(captureIntent, SCREEN_CAPTURE_REQUEST_CODE)
    }

    private fun bringAppToForeground(call: MethodCall, result: MethodChannel.Result) {
        val intent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_MAIN
            addCategory(Intent.CATEGORY_LAUNCHER)
            flags = Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(intent)
        result.success(true)
    }

    private fun handleSumMethod(call: MethodCall, result: MethodChannel.Result) {
        val a = call.argument<Int>("a")
        val b = call.argument<Int>("b")

        if (a != null && b != null) {
            val sumResult = a + b
            Log.d(TAG, "Calculated sum: $sumResult")
            result.success(sumResult)
        } else {
            result.error(
                "INVALID_ARGUMENTS",
                "One or both arguments ('a' or 'b') are null. Ensure they are sent as non-null integers.",
                null
            )
            Log.e(TAG, "Error: Missing arguments for sum method.")
        }
    }

    // No need to override onDestroy to destroy the FlutterEngine here,
    // as it's cached and managed by FlutterActivity's default lifecycle.
}