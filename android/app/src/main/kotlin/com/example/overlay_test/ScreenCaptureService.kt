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

/**
 * Keeps a MediaProjection session (screen recording) alive for as long as the
 * floating shortcut button is enabled. The latest frame is always held in memory,
 * so a screenshot can be taken instantly via [captureFrame] without asking the
 * user for permission again.
 */
class ScreenCaptureService : Service() {

    companion object {
        private const val TAG = "ScreenCaptureService"
        private const val NOTIFICATION_CHANNEL_ID = "ScreenCaptureChannel"
        private const val NOTIFICATION_ID = 101

        const val ACTION_START = "ACTION_START_SCREEN_CAPTURE"
        const val EXTRA_RESULT_CODE = "extra_result_code"
        const val EXTRA_DATA_INTENT = "extra_data_intent"
        const val EXTRA_CHANNEL_NAME = "extra_channel_name"

        // The running service, if any. The service lives in the same process as
        // MainActivity, so it can be called directly instead of through intents.
        @Volatile
        var instance: ScreenCaptureService? = null
            private set

        val isRunning: Boolean
            get() = instance?.mediaProjection != null
    }

    private var mediaProjection: MediaProjection? = null
    private var imageReader: ImageReader? = null
    private var virtualDisplay: android.hardware.display.VirtualDisplay? = null
    private lateinit var notificationManager: NotificationManager
    private var channelName: String = "com.example.overlay_test/helper"

    private var imageReaderHandlerThread: HandlerThread? = null
    private var imageReaderHandler: Handler? = null

    // Most recent frame produced by the virtual display. Guarded by imageLock.
    private val imageLock = Any()
    private var latestImage: Image? = null
    private var captureWidth = 0
    private var captureHeight = 0

    // Main thread handler to post Flutter MethodChannel calls
    private val mainHandler = Handler(Looper.getMainLooper())

    private val mediaProjectionCallback = object : MediaProjection.Callback() {
        override fun onStop() {
            // Called when the session is ended outside of our control,
            // e.g. the user stops sharing from the system UI.
            Log.e(TAG, "MediaProjection session stopped.")
            sendToFlutter("screenCaptureError", mapOf(
                "code" to "SESSION_STOPPED",
                "message" to "MediaProjection session stopped unexpectedly."
            ))
            stopScreenCapture()
            stopSelf()
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
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

        if (intent?.action == ACTION_START) {
            handleStartCapture(intent)
        } else {
            Log.w(TAG, "Unhandled intent action: ${intent?.action}. Stopping service.")
            stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun handleStartCapture(intent: Intent) {
        val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, 0)
        val data = intent.getParcelableExtra<Intent>(EXTRA_DATA_INTENT)
        channelName = intent.getStringExtra(EXTRA_CHANNEL_NAME) ?: channelName

        if (mediaProjection != null) {
            Log.d(TAG, "Screen capture session already running.")
            return
        }

        if (resultCode == 0 || data == null) {
            Log.e(TAG, "Invalid result code or data intent for MediaProjection. Stopping service.")
            sendToFlutter("screenCaptureError", mapOf(
                "code" to "INVALID_PARAMS",
                "message" to "Invalid parameters for starting capture service."
            ))
            stopSelf()
            return
        }

        try {
            val mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            mediaProjection = mediaProjectionManager.getMediaProjection(resultCode, data)

            if (mediaProjection == null) {
                Log.e(TAG, "Failed to get MediaProjection after permission granted. Stopping service.")
                sendToFlutter("screenCaptureError", mapOf(
                    "code" to "MEDIA_PROJECTION_NULL",
                    "message" to "Failed to acquire MediaProjection object."
                ))
                stopSelf()
                return
            }

            // Must be registered before creating the virtual display (required on Android 14+)
            mediaProjection?.registerCallback(mediaProjectionCallback, mainHandler)
            Log.d(TAG, "MediaProjection callback registered.")

            startRecording()
        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException while getting MediaProjection: ${e.message}. Stopping service.")
            sendToFlutter("screenCaptureError", mapOf(
                "code" to "SECURITY_EXCEPTION",
                "message" to "Security error getting MediaProjection: ${e.message}"
            ))
            stopScreenCapture()
            stopSelf()
        } catch (e: Exception) {
            Log.e(TAG, "General error getting MediaProjection: ${e.message}. Stopping service.", e)
            sendToFlutter("screenCaptureError", mapOf(
                "code" to "GENERAL_ERROR",
                "message" to "Failed to get MediaProjection: ${e.message}"
            ))
            stopScreenCapture()
            stopSelf()
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
            .setContentText("Tap the LinguaScreen shortcut button to capture your screen.")
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .build().also {
                Log.d(TAG, "Notification created.")
            }
    }

    private fun startRecording() {
        val (screenWidth, screenHeight, screenDensityDpi) = getScreenDimensions()

        if (screenWidth <= 0 || screenHeight <= 0) {
            Log.e(TAG, "Screen dimensions are invalid: ${screenWidth}x${screenHeight}")
            sendToFlutter("screenCaptureError", mapOf(
                "code" to "INVALID_DIMENSIONS",
                "message" to "Screen dimensions are zero or negative."
            ))
            stopScreenCapture()
            stopSelf()
            return
        }

        Log.d(TAG, "Screen dimensions: ${screenWidth}x${screenHeight} @ ${screenDensityDpi}dpi")
        captureWidth = screenWidth
        captureHeight = screenHeight

        // One image is held as the latest frame, and acquireLatestImage() needs two
        // more free buffers to drop stale frames, so maxImages must be at least 3.
        imageReader = ImageReader.newInstance(screenWidth, screenHeight, PixelFormat.RGBA_8888, 3).apply {
            setOnImageAvailableListener({ reader -> handleImageAvailable(reader) }, imageReaderHandler)
        }

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
        Log.d(TAG, "VirtualDisplay created. Screen recording started.")
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

    private fun handleImageAvailable(reader: ImageReader) {
        try {
            val image = reader.acquireLatestImage() ?: return
            synchronized(imageLock) {
                latestImage?.close()
                latestImage = image
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to acquire frame: ${e.message}")
        }
    }

    /**
     * Saves the most recent frame of the running recording session and reports
     * the file path back to Flutter via `screenCaptureSuccess`.
     */
    fun captureFrame() {
        val handler = imageReaderHandler
        if (handler == null) {
            sendToFlutter("screenCaptureError", mapOf(
                "code" to "NOT_RUNNING",
                "message" to "Screen capture session is not running."
            ))
            return
        }

        handler.post {
            try {
                val bitmap = synchronized(imageLock) {
                    latestImage?.let { convertImageToBitmap(it, captureWidth, captureHeight) }
                }

                if (bitmap == null) {
                    Log.e(TAG, "No frame available yet.")
                    sendToFlutter("screenCaptureError", mapOf(
                        "code" to "NO_FRAME",
                        "message" to "No screen frame is available yet."
                    ))
                    return@post
                }

                val filePath = saveBitmap(bitmap)
                bitmap.recycle()
                sendToFlutter("screenCaptureSuccess", filePath)
            } catch (e: Exception) {
                Log.e(TAG, "Error processing frame: ${e.message}", e)
                sendToFlutter("screenCaptureError", mapOf(
                    "code" to "CAPTURE_FAILED",
                    "message" to "Failed to capture image: ${e.message}"
                ))
            }
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
        // The same frame may be read more than once, so always start from the beginning.
        buffer.rewind()
        bitmap.copyPixelsFromBuffer(buffer)

        val cropped = Bitmap.createBitmap(bitmap, 0, 0, screenWidth, screenHeight)
        if (cropped != bitmap) bitmap.recycle()
        return cropped
    }

    fun stopScreenCapture() {
        Log.d(TAG, "Stopping screen capture...")
        virtualDisplay?.release()
        virtualDisplay = null
        synchronized(imageLock) {
            latestImage?.close()
            latestImage = null
        }
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

    // The engine is looked up on every call because the session can outlive the
    // activity (and its FlutterEngine) that started it.
    private fun sendToFlutter(method: String, arguments: Any?) {
        mainHandler.post {
            val flutterEngine = FlutterEngineCache.getInstance().get(MainActivity.ENGINE_ID)
            if (flutterEngine == null) {
                Log.w(TAG, "FlutterEngine not found in cache. Dropping '$method'.")
                return@post
            }
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
                .invokeMethod(method, arguments)
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
        if (instance == this) instance = null
        Log.d(TAG, "ScreenCaptureService destroyed. ImageReader Thread quit.")
    }
}
