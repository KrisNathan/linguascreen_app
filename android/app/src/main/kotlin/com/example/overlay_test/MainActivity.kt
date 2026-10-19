package com.example.overlay_test

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionConfig
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

    // Result of a pending 'startScreenCapture' call, completed in onActivityResult.
    private var pendingStartResult: MethodChannel.Result? = null

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
                    // Starts the screen recording session used by the floating button.
                    // Resolves with true once permission is granted, false if denied.
                    if (ScreenCaptureService.isRunning) {
                        result.success(true)
                    } else {
                        pendingStartResult?.success(false)
                        pendingStartResult = result
                        requestScreenCapturePermission()
                    }
                }
                "captureScreenshot" -> {
                    // Grabs the latest frame of the running session.
                    // The file path is delivered through 'screenCaptureSuccess'.
                    val service = ScreenCaptureService.instance
                    if (service != null && ScreenCaptureService.isRunning) {
                        service.captureFrame()
                        result.success(null)
                    } else {
                        result.error("NOT_RUNNING", "Screen capture session is not running.", null)
                    }
                }
                "isScreenCaptureRunning" -> {
                    result.success(ScreenCaptureService.isRunning)
                }
                "stopScreenCapture" -> {
                    ScreenCaptureService.instance?.let {
                        it.stopScreenCapture()
                        it.stopSelf()
                    }
                    result.success(true)
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
            val pendingResult = pendingStartResult
            pendingStartResult = null

            if (resultCode == Activity.RESULT_OK && data != null) {
                val serviceIntent = Intent(this, ScreenCaptureService::class.java).apply {
                    action = ScreenCaptureService.ACTION_START
                    putExtra(ScreenCaptureService.EXTRA_RESULT_CODE, resultCode)
                    putExtra(ScreenCaptureService.EXTRA_DATA_INTENT, data)
                    putExtra(ScreenCaptureService.EXTRA_CHANNEL_NAME, CHANNEL)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(serviceIntent)
                } else {
                    startService(serviceIntent)
                }
                Log.d(TAG, "ScreenCaptureService started with MediaProjection data.")
                pendingResult?.success(true)
            } else if (resultCode == Activity.RESULT_OK) {
                Log.e(TAG, "MediaProjection data is null after permission granted.")
                pendingResult?.error("DATA_NULL", "MediaProjection data was null after permission granted.", null)
            } else {
                Log.e(TAG, "User denied screen capture permission.")
                pendingResult?.success(false)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // val targetRoute = intent.getStringExtra("targetRoute")
        // if (targetRoute != null) {
        //     methodChannel.invokeMethod("navigateToPage", targetRoute)
        // }
    }

    private fun requestScreenCapturePermission() {
        // Only allow recording the entire screen, since the shortcut can be used over any app.
        val captureIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            mediaProjectionManager.createScreenCaptureIntent(MediaProjectionConfig.createConfigForDefaultDisplay())
        } else {
            mediaProjectionManager.createScreenCaptureIntent()
        }
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
}