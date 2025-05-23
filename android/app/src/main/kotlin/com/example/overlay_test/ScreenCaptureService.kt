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

    // Main thread handler to post Flutter MethodChannel calls
    private val mainHandler = Handler(Looper.getMainLooper())

    private val mediaProjectionCallback = object : MediaProjection.Callback() {
        override fun onStop() {
            Log.e(TAG, "MediaProjection session stopped.")
            // Post to main thread as methodChannel.invokeMethod must be on UI thread
            mainHandler.post {
                methodChannel?.invokeMethod("screenCaptureError", mapOf("code" to "SESSION_STOPPED", "message" to "MediaProjection session stopped unexpectedly."))
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
                ACTION_START -> {
                    val resultCode = it.getIntExtra(EXTRA_RESULT_CODE, 0)
                    val data = it.getParcelableExtra<Intent>(EXTRA_DATA_INTENT)

                    channelName = it.getStringExtra(EXTRA_CHANNEL_NAME) ?: "com.example.overlay_test/helper"

                    val flutterEngine = FlutterEngineCache.getInstance().get(MainActivity.ENGINE_ID)

                    if (flutterEngine != null) {
                        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
                        Log.d(TAG, "MethodChannel initialized for channel: $channelName")
                    } else {
                        Log.e(TAG, "FlutterEngine not found in cache. Cannot establish MethodChannel. Stopping service.")
                        stopSelf()
                        return START_NOT_STICKY
                    }

                    if (resultCode != 0 && data != null) {
                        try {
                            val mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
                            mediaProjection = mediaProjectionManager.getMediaProjection(resultCode, data)

                            if (mediaProjection != null) {
                                mediaProjection?.registerCallback(mediaProjectionCallback, null)
                                Log.d(TAG, "MediaProjection callback registered.")
                                
                                isCapturing = true
                                startScreenCaptureInternal()
                            } else {
                                Log.e(TAG, "Failed to get MediaProjection after permission granted. Stopping service.")
                                mainHandler.post {
                                    methodChannel?.invokeMethod("screenCaptureError", mapOf("code" to "MEDIA_PROJECTION_NULL", "message" to "Failed to acquire MediaProjection object."))
                                }
                                stopSelf()
                            }
                        } catch (e: SecurityException) {
                            Log.e(TAG, "SecurityException while getting MediaProjection: ${e.message}. Stopping service.")
                            mainHandler.post {
                                methodChannel?.invokeMethod("screenCaptureError", mapOf("code" to "SECURITY_EXCEPTION", "message" to "Security error getting MediaProjection: ${e.message}"))
                            }
                            stopSelf()
                        } catch (e: Exception) {
                            Log.e(TAG, "General error getting MediaProjection: ${e.message}. Stopping service.", e)
                            mainHandler.post {
                                methodChannel?.invokeMethod("screenCaptureError", mapOf("code" to "GENERAL_ERROR", "message" to "Failed to get MediaProjection: ${e.message}"))
                            }
                            stopSelf()
                        }
                    } else {
                        Log.e(TAG, "Invalid result code or data intent for MediaProjection. Stopping service.")
                        mainHandler.post {
                            methodChannel?.invokeMethod("screenCaptureError", mapOf("code" to "INVALID_PARAMS", "message" to "Invalid parameters for starting capture service."))
                        }
                        stopSelf()
                    }
                }
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
                methodChannel?.invokeMethod("screenCaptureError", mapOf("code" to "INTERNAL_ERROR", "message" to "MediaProjection not available during internal capture setup."))
            }
            stopSelf()
            return
        }

        val windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val screenWidth: Int
        val screenHeight: Int
        val screenDensityDpi: Int

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val windowMetrics = windowManager.currentWindowMetrics
            screenWidth = windowMetrics.bounds.width()
            screenHeight = windowMetrics.bounds.height()
            screenDensityDpi = resources.displayMetrics.densityDpi
        } else {
            @Suppress("DEPRECATION")
            val metrics = DisplayMetrics()
            windowManager.defaultDisplay.getMetrics(metrics)
            screenWidth = metrics.widthPixels
            screenHeight = metrics.heightPixels
            screenDensityDpi = metrics.densityDpi
        }

        if (screenWidth <= 0 || screenHeight <= 0) {
            Log.e(TAG, "Screen dimensions are invalid: ${screenWidth}x${screenHeight}")
            mainHandler.post {
                methodChannel?.invokeMethod("screenCaptureError", mapOf("code" to "INVALID_DIMENSIONS", "message" to "Screen dimensions are zero or negative."))
            }
            stopSelf()
            return
        }

        Log.d(TAG, "Screen dimensions: ${screenWidth}x${screenHeight} @ ${screenDensityDpi}dpi")

        try {
            imageReader = ImageReader.newInstance(screenWidth, screenHeight, PixelFormat.RGBA_8888, 1)

            imageReader?.setOnImageAvailableListener({ reader ->
                // Check if we're still capturing to avoid processing multiple images
                if (!isCapturing) {
                    Log.d(TAG, "Ignoring image callback - capture already completed")
                    return@setOnImageAvailableListener
                }
                
                var image: Image? = null
                var filePath: String? = null
                try {
                    image = reader.acquireLatestImage()
                    if (image != null) {
                        Log.d(TAG, "Image acquired successfully!")
                        
                        // Mark as no longer capturing to prevent processing additional images
                        isCapturing = false
                        
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

                        val actualBitmap = Bitmap.createBitmap(bitmap, 0, 0, screenWidth, screenHeight)

                        filePath = saveBitmap(actualBitmap)
                        actualBitmap.recycle()

                        // Post MethodChannel calls to the main thread
                        mainHandler.post {
                            methodChannel?.invokeMethod("screenCaptureSuccess", filePath)
                        }

                    } else {
                        Log.d(TAG, "Acquired image is null - this can happen with multiple callbacks")
                        // Don't treat this as an error since it's expected behavior
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error acquiring or processing image: ${e.message}", e)
                    isCapturing = false
                    mainHandler.post {
                        methodChannel?.invokeMethod("screenCaptureError", mapOf("code" to "CAPTURE_FAILED", "message" to "Failed to capture image: ${e.message}"))
                    }
                } finally {
                    image?.close()
                    // Only stop capture if we successfully processed an image or had an error
                    if (!isCapturing) {
                        stopScreenCapture()
                        stopSelf()
                    }
                }
            }, imageReaderHandler)

            // CRITICAL FIX: Don't close the imageReader immediately after setting the listener!
            // Remove these two lines that were causing the issue:
            // imageReader?.close()
            // imageReader = null

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
            Log.d(TAG, "VirtualDisplay created. Waiting for image on ImageReaderThread.")

        } catch (e: Exception) {
            Log.e(TAG, "Error setting up ImageReader or VirtualDisplay: ${e.message}", e)
            mainHandler.post {
                methodChannel?.invokeMethod("screenCaptureError", mapOf("code" to "SETUP_FAILED", "message" to "Failed to set up capture components: ${e.message}"))
            }
            stopSelf()
        }
    }

    private fun stopScreenCapture() {
        Log.d(TAG, "Stopping screen capture...")
        isCapturing = false
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