package com.example.overlay_test

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.media.Image
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Looper
import android.util.DisplayMetrics
import android.util.Log
import android.view.WindowManager
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import kotlinx.coroutines.*

import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.FlutterEngine

class ScreenCaptureService : Service() {

    companion object {
        private const val TAG = "ScreenCaptureService"
        private const val NOTIFICATION_CHANNEL_ID = "ScreenCaptureChannel"
        private const val NOTIFICATION_ID = 101

        const val ACTION_START = "ACTION_START_SCREEN_CAPTURE"
        const val ACTION_STOP = "ACTION_STOP_SCREEN_CAPTURE"
        const val EXTRA_RESULT_CODE = "extra_result_code"
        const val EXTRA_DATA_INTENT = "extra_data_intent"
        const val EXTRA_CHANNEL_NAME = "extra_channel_name"
        
        // Delay constants for permission dialog handling
        private const val CAPTURE_DELAY_MS = 1500L // Wait for permission dialog to dismiss
        private const val MAX_CAPTURE_ATTEMPTS = 3
        private const val ATTEMPT_INTERVAL_MS = 500L
    }

    private var mediaProjection: MediaProjection? = null
    private var imageReader: ImageReader? = null
    private var virtualDisplay: android.hardware.display.VirtualDisplay? = null
    private lateinit var notificationManager: NotificationManager
    private var methodChannel: MethodChannel? = null
    private lateinit var channelName: String

    private var imageReaderHandlerThread: HandlerThread? = null
    private var imageReaderHandler: Handler? = null
    private var isCapturing = false
    private var captureAttempts = 0
    
    // Coroutine scope for managing delays and retries
    private val serviceScope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    // Main thread handler to post Flutter MethodChannel calls
    private val mainHandler = Handler(Looper.getMainLooper())

    private val mediaProjectionCallback = object : MediaProjection.Callback() {
        override fun onStop() {
            Log.e(TAG, "MediaProjection session stopped.")
            mainHandler.post {
                methodChannel?.invokeMethod("screenCaptureError", mapOf(
                    "code" to "SESSION_STOPPED", 
                    "message" to "MediaProjection session stopped unexpectedly."
                ))
            }
            stopScreenCapture()
            stopSelf()
        }
    }

    override fun onCreate() {
        super.onCreate()
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createNotificationChannel()
        Log.d(TAG, "ScreenCaptureService onCreate.")

        imageReaderHandlerThread = HandlerThread("ImageReaderThread").apply { start() }
        imageReaderHandler = Handler(imageReaderHandlerThread!!.looper)
        Log.d(TAG, "ImageReader HandlerThread started.")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "ScreenCaptureService onStartCommand: ${intent?.action}")

        startForeground(NOTIFICATION_ID, createNotification())
        Log.d(TAG, "Foreground service started with ID: $NOTIFICATION_ID")

        intent?.let {
            when (it.action) {
                ACTION_START -> handleStartCapture(it)
                ACTION_STOP -> {
                    Log.d(TAG, "Received stop action. Stopping service.")
                    stopScreenCapture()
                    stopSelf()
                }
                else -> {
                    Log.w(TAG, "Unhandled intent action: ${it.action}. Stopping service if no valid action.")
                    stopSelf()
                }
            }
        } ?: run {
            Log.w(TAG, "Service started with null intent. Stopping service.")
            stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun handleStartCapture(intent: Intent) {
        val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, 0)
        val data = intent.getParcelableExtra<Intent>(EXTRA_DATA_INTENT)
        channelName = intent.getStringExtra(EXTRA_CHANNEL_NAME) ?: "com.example.overlay_test/helper"

        val flutterEngine = FlutterEngineCache.getInstance().get(MainActivity.ENGINE_ID)

        if (flutterEngine != null) {
            methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            Log.d(TAG, "MethodChannel initialized for channel: $channelName")
        } else {
            Log.e(TAG, "FlutterEngine not found in cache. Cannot establish MethodChannel. Stopping service.")
            stopSelf()
            return
        }

        if (resultCode != 0 && data != null) {
            try {
                val mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                mediaProjection = mediaProjectionManager.getMediaProjection(resultCode, data)

                if (mediaProjection != null) {
                    mediaProjection?.registerCallback(mediaProjectionCallback, null)
                    Log.d(TAG, "MediaProjection callback registered.")
                    
                    // Start capture with delay to allow permission dialog to dismiss
                    startDelayedCapture()
                } else {
                    Log.e(TAG, "Failed to get MediaProjection after permission granted. Stopping service.")
                    mainHandler.post {
                        methodChannel?.invokeMethod("screenCaptureError", mapOf(
                            "code" to "MEDIA_PROJECTION_NULL", 
                            "message" to "Failed to acquire MediaProjection object."
                        ))
                    }
                    stopSelf()
                }
            } catch (e: SecurityException) {
                Log.e(TAG, "SecurityException while getting MediaProjection: ${e.message}. Stopping service.")
                mainHandler.post {
                    methodChannel?.invokeMethod("screenCaptureError", mapOf(
                        "code" to "SECURITY_EXCEPTION", 
                        "message" to "Security error getting MediaProjection: ${e.message}"
                    ))
                }
                stopSelf()
            } catch (e: Exception) {
                Log.e(TAG, "General error getting MediaProjection: ${e.message}. Stopping service.", e)
                mainHandler.post {
                    methodChannel?.invokeMethod("screenCaptureError", mapOf(
                        "code" to "GENERAL_ERROR", 
                        "message" to "Failed to get MediaProjection: ${e.message}"
                    ))
                }
                stopSelf()
            }
        } else {
            Log.e(TAG, "Invalid result code or data intent for MediaProjection. Stopping service.")
            mainHandler.post {
                methodChannel?.invokeMethod("screenCaptureError", mapOf(
                    "code" to "INVALID_PARAMS", 
                    "message" to "Invalid parameters for starting capture service."
                ))
            }
            stopSelf()
        }
    }

    private fun startDelayedCapture() {
        Log.d(TAG, "Starting delayed capture to avoid permission dialog interference")
        
        serviceScope.launch {
            // Wait for permission dialog to dismiss
            delay(CAPTURE_DELAY_MS)
            
            if (mediaProjection != null) {
                isCapturing = true
                captureAttempts = 0
                startScreenCaptureInternal()
            } else {
                Log.e(TAG, "MediaProjection became null during delay")
                stopSelf()
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "Screen Capture Service",
                NotificationManager.IMPORTANCE_HIGH
            )
            notificationManager.createNotificationChannel(serviceChannel)
            Log.d(TAG, "Notification channel created.")
        }
    }

    private fun createNotification(): Notification {
        return Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Screen Capture Running")
            .setContentText("Your screen is currently being captured.")
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .build().also {
                Log.d(TAG, "Notification created.")
            }
    }

    private fun startScreenCaptureInternal() {
        if (mediaProjection == null) {
            Log.e(TAG, "MediaProjection is null. Cannot start capture internally.")
            mainHandler.post {
                methodChannel?.invokeMethod("screenCaptureError", mapOf(
                    "code" to "INTERNAL_ERROR", 
                    "message" to "MediaProjection not available during internal capture setup."
                ))
            }
            stopSelf()
            return
        }

        val (screenWidth, screenHeight, screenDensityDpi) = getScreenDimensions()

        if (screenWidth <= 0 || screenHeight <= 0) {
            Log.e(TAG, "Screen dimensions are invalid: ${screenWidth}x${screenHeight}")
            mainHandler.post {
                methodChannel?.invokeMethod("screenCaptureError", mapOf(
                    "code" to "INVALID_DIMENSIONS", 
                    "message" to "Screen dimensions are zero or negative."
                ))
            }
            stopSelf()
            return
        }

        Log.d(TAG, "Screen dimensions: ${screenWidth}x${screenHeight} @ ${screenDensityDpi}dpi")

        try {
            setupImageReader(screenWidth, screenHeight)
            createVirtualDisplay(screenWidth, screenHeight, screenDensityDpi)
            Log.d(TAG, "VirtualDisplay created. Waiting for image on ImageReaderThread.")

        } catch (e: Exception) {
            Log.e(TAG, "Error setting up ImageReader or VirtualDisplay: ${e.message}", e)
            mainHandler.post {
                methodChannel?.invokeMethod("screenCaptureError", mapOf(
                    "code" to "SETUP_FAILED", 
                    "message" to "Failed to set up capture components: ${e.message}"
                ))
            }
            stopSelf()
        }
    }

    private fun getScreenDimensions(): Triple<Int, Int, Int> {
        val windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val windowMetrics = windowManager.currentWindowMetrics
            Triple(
                windowMetrics.bounds.width(),
                windowMetrics.bounds.height(),
                resources.displayMetrics.densityDpi
            )
        } else {
            @Suppress("DEPRECATION")
            val metrics = DisplayMetrics()
            windowManager.defaultDisplay.getMetrics(metrics)
            Triple(metrics.widthPixels, metrics.heightPixels, metrics.densityDpi)
        }
    }

    private fun setupImageReader(screenWidth: Int, screenHeight: Int) {
        imageReader = ImageReader.newInstance(screenWidth, screenHeight, PixelFormat.RGBA_8888, 1)

        imageReader?.setOnImageAvailableListener({ reader ->
            handleImageAvailable(reader, screenWidth, screenHeight)
        }, imageReaderHandler)
    }

    private fun handleImageAvailable(reader: ImageReader, screenWidth: Int, screenHeight: Int) {
        if (!isCapturing) {
            Log.d(TAG, "Ignoring image callback - capture already completed")
            return
        }
        
        var image: Image? = null
        try {
            image = reader.acquireLatestImage()
            if (image != null) {
                Log.d(TAG, "Image acquired successfully! Attempt: ${captureAttempts + 1}")
                
                val bitmap = convertImageToBitmap(image, screenWidth, screenHeight)
                
                // Check if this looks like a valid capture (not just permission dialog)
                if (isValidCapture(bitmap)) {
                    isCapturing = false
                    val filePath = saveBitmap(bitmap)
                    
                    mainHandler.post {
                        methodChannel?.invokeMethod("screenCaptureSuccess", filePath)
                    }
                    
                    bitmap.recycle()
                    stopScreenCapture()
                    stopSelf()
                } else {
                    // Retry if we haven't reached max attempts
                    captureAttempts++
                    if (captureAttempts < MAX_CAPTURE_ATTEMPTS) {
                        Log.d(TAG, "Capture may contain dialog overlay, retrying in ${ATTEMPT_INTERVAL_MS}ms")
                        bitmap.recycle()
                        
                        serviceScope.launch {
                            delay(ATTEMPT_INTERVAL_MS)
                            // The next image callback will be triggered automatically
                        }
                    } else {
                        Log.w(TAG, "Max capture attempts reached, proceeding with current image")
                        isCapturing = false
                        val filePath = saveBitmap(bitmap)
                        
                        mainHandler.post {
                            methodChannel?.invokeMethod("screenCaptureSuccess", filePath)
                        }
                        
                        bitmap.recycle()
                        stopScreenCapture()
                        stopSelf()
                    }
                }
            } else {
                Log.d(TAG, "Acquired image is null - this can happen with multiple callbacks")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error acquiring or processing image: ${e.message}", e)
            isCapturing = false
            mainHandler.post {
                methodChannel?.invokeMethod("screenCaptureError", mapOf(
                    "code" to "CAPTURE_FAILED", 
                    "message" to "Failed to capture image: ${e.message}"
                ))
            }
            stopScreenCapture()
            stopSelf()
        } finally {
            image?.close()
        }
    }

    private fun convertImageToBitmap(image: Image, screenWidth: Int, screenHeight: Int): Bitmap {
        val planes = image.planes
        val buffer: ByteBuffer = planes[0].buffer
        val pixelStride = planes[0].pixelStride
        val rowStride = planes[0].rowStride
        val rowPadding = rowStride - pixelStride * screenWidth

        val bitmap = Bitmap.createBitmap(
            screenWidth + rowPadding / pixelStride,
            screenHeight,
            Bitmap.Config.ARGB_8888
        )
        bitmap.copyPixelsFromBuffer(buffer)

        return Bitmap.createBitmap(bitmap, 0, 0, screenWidth, screenHeight)
    }

    private fun isValidCapture(bitmap: Bitmap): Boolean {
        // Simple heuristic to detect if the capture might contain permission dialog
        // This is a basic implementation - you might want to enhance this based on your needs
        
        // Check if the image is mostly uniform (which might indicate a dialog overlay)
        val sampleSize = 100
        val centerX = bitmap.width / 2
        val centerY = bitmap.height / 2
        
        var uniformPixels = 0
        val centerPixel = bitmap.getPixel(centerX, centerY)
        
        // Sample pixels around the center
        for (i in -sampleSize/2..sampleSize/2 step 10) {
            for (j in -sampleSize/2..sampleSize/2 step 10) {
                val x = (centerX + i).coerceIn(0, bitmap.width - 1)
                val y = (centerY + j).coerceIn(0, bitmap.height - 1)
                
                val pixel = bitmap.getPixel(x, y)
                val colorDiff = Math.abs(android.graphics.Color.red(pixel) - android.graphics.Color.red(centerPixel)) +
                              Math.abs(android.graphics.Color.green(pixel) - android.graphics.Color.green(centerPixel)) +
                              Math.abs(android.graphics.Color.blue(pixel) - android.graphics.Color.blue(centerPixel))
                
                if (colorDiff < 30) { // Threshold for "similar" colors
                    uniformPixels++
                }
            }
        }
        
        val totalSamples = (sampleSize / 10 + 1) * (sampleSize / 10 + 1)
        val uniformityRatio = uniformPixels.toFloat() / totalSamples
        
        // If more than 80% of sampled pixels are similar, it might be a dialog
        val isValid = uniformityRatio < 0.8
        
        Log.d(TAG, "Capture validation: uniformity ratio = $uniformityRatio, valid = $isValid")
        return isValid
    }

    private fun createVirtualDisplay(screenWidth: Int, screenHeight: Int, screenDensityDpi: Int) {
        virtualDisplay = mediaProjection?.createVirtualDisplay(
            "ScreenCapture",
            screenWidth,
            screenHeight,
            screenDensityDpi,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            imageReader?.surface,
            null,
            null
        )
    }

    private fun stopScreenCapture() {
        Log.d(TAG, "Stopping screen capture...")
        isCapturing = false
        serviceScope.cancel() // Cancel any pending coroutines
        virtualDisplay?.release()
        virtualDisplay = null
        imageReader?.close()
        imageReader = null
        mediaProjection?.unregisterCallback(mediaProjectionCallback)
        mediaProjection?.stop()
        mediaProjection = null
        Log.d(TAG, "Screen capture resources released.")
    }

    private fun saveBitmap(bitmap: Bitmap): String? {
        val filename = "screenshot_${System.currentTimeMillis()}.png"
        val directory = cacheDir
        val file = File(directory, filename)

        try {
            FileOutputStream(file).use { out ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                Log.d(TAG, "Screenshot saved to: ${file.absolutePath}")
                return file.absolutePath
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error saving bitmap: ${e.message}")
            return null
        }
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        stopScreenCapture()
        imageReaderHandlerThread?.quitSafely()
        imageReaderHandlerThread = null
        imageReaderHandler = null
        Log.d(TAG, "ScreenCaptureService destroyed. ImageReader Thread quit.")
    }
}