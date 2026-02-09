package com.osglab.puked

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.video.*
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.view.TextureRegistry
import java.io.File
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * 视频录制管理器
 * 
 * 实现：
 * - 10秒循环缓冲录制（无音频）
 * - 事件触发时保存前5秒视频
 * - 摄像头预览
 */
class VideoRecordingManager(
    private val activity: Activity,
    private val lifecycleOwner: LifecycleOwner,
    private val textureRegistry: TextureRegistry
) : MethodCallHandler {

    companion object {
        private const val TAG = "VideoRecordingManager"
        private const val CHANNEL_NAME = "com.puked/video_recording"
        private const val PERMISSION_REQUEST_CODE = 1001
    }
    
    private val context: Context get() = activity.applicationContext

    // CameraX 组件
    private var cameraProvider: ProcessCameraProvider? = null
    private var camera: Camera? = null
    private var preview: Preview? = null
    private var videoCapture: VideoCapture<Recorder>? = null
    
    // 录制相关
    private var isRecording = false
    private var recording: Recording? = null
    private val cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    
    // 预览纹理
    private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null
    
    // 循环缓冲区（保存最近的视频文件）
    private val videoBuffer = mutableListOf<File>()
    private var bufferDuration: Int = 10 // 秒
    
    /**
     * 设置 Method Channel
     */
    fun setupChannel(messenger: io.flutter.plugin.common.BinaryMessenger) {
        val channel = MethodChannel(messenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
        Log.d(TAG, "Method channel setup complete")
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> initialize(result)
            "checkCameraPermission" -> checkCameraPermission(result)
            "requestCameraPermission" -> requestCameraPermission(result)
            "startRecording" -> startRecording(call, result)
            "stopRecording" -> stopRecording(result)
            "captureEvent" -> captureEvent(call, result)
            "getPreviewTextureId" -> getPreviewTextureId(result)
            "dispose" -> dispose(result)
            else -> result.notImplemented()
        }
    }

    /**
     * 初始化视频录制
     */
    private fun initialize(result: Result) {
        try {
            val cameraProviderFuture = ProcessCameraProvider.getInstance(context)
            
            cameraProviderFuture.addListener({
                try {
                    cameraProvider = cameraProviderFuture.get()
                    
                    // 创建预览
                    preview = Preview.Builder().build()
                    
                    // 创建视频录制
                    val recorder = Recorder.Builder()
                        .setQualitySelector(QualitySelector.from(Quality.FHD))
                        .build()
                    videoCapture = VideoCapture.withOutput(recorder)
                    
                    result.success(true)
                    Log.d(TAG, "Initialized successfully")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to initialize", e)
                    result.error("INIT_FAILED", "Failed to initialize: ${e.message}", null)
                }
            }, ContextCompat.getMainExecutor(context))
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get camera provider", e)
            result.error("INIT_FAILED", "Failed to get camera provider: ${e.message}", null)
        }
    }

    /**
     * 检查摄像头权限
     */
    private fun checkCameraPermission(result: Result) {
        val hasPermission = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED
        
        result.success(hasPermission)
    }

    /**
     * 请求摄像头权限
     */
    private fun requestCameraPermission(result: Result) {
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) {
            result.success(true)
            return
        }
        
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(Manifest.permission.CAMERA),
            PERMISSION_REQUEST_CODE
        )
        
        // 直接返回 true 表示请求已发起。Flutter 端在 CameraPreviewWidget 中会有重试逻辑。
        result.success(true)
    }

    /**
     * 开始循环录制
     */
    private fun startRecording(call: MethodCall, result: Result) {
        try {
            bufferDuration = call.argument<Int>("bufferDuration") ?: 10
            
            val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA
            
            cameraProvider?.unbindAll()
            camera = cameraProvider?.bindToLifecycle(
                lifecycleOwner,
                cameraSelector,
                preview,
                videoCapture
            )
            
            isRecording = true
            result.success(true)
            
            // 开始循环录制（每2秒一个片段）
            startSegmentRecording()
            
            Log.d(TAG, "Started recording with buffer duration: ${bufferDuration}s")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start recording", e)
            result.error("START_FAILED", "Failed to start recording: ${e.message}", null)
        }
    }

    /**
     * 停止循环录制
     */
    private fun stopRecording(result: Result) {
        try {
            isRecording = false
            recording?.stop()
            recording = null
            
            // ⚠️ 重要：不要解绑摄像头！这样预览会消失
            // 只需要停止录制，保持预览继续运行
            // cameraProvider?.unbindAll()  // ❌ 删除这行
            
            // 重新绑定只有预览（没有视频录制）
            if (cameraProvider != null && preview != null) {
                try {
                    val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA
                    cameraProvider?.unbindAll()
                    camera = cameraProvider?.bindToLifecycle(
                        lifecycleOwner,
                        cameraSelector,
                        preview  // ✅ 只绑定预览，不绑定 videoCapture
                    )
                    Log.d(TAG, "✅ Camera rebound for preview only")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to rebind camera for preview", e)
                }
            }
            
            // 清理缓冲区
            videoBuffer.forEach { it.delete() }
            videoBuffer.clear()
            
            result.success(true)
            Log.d(TAG, "Stopped recording, preview remains active")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop recording", e)
            result.error("STOP_FAILED", "Failed to stop recording: ${e.message}", null)
        }
    }

    /**
     * 捕获事件视频（保存前N秒）
     */
    private fun captureEvent(call: MethodCall, result: Result) {
        try {
            val eventId = call.argument<String>("eventId") ?: return result.error(
                "INVALID_ARGUMENTS", "Missing eventId", null
            )
            val duration = call.argument<Int>("duration") ?: 5
            
            if (videoBuffer.isEmpty()) {
                Log.w(TAG, "⚠️ Video buffer is empty, cannot capture event")
                result.success(null)
                return
            }
            
            Log.d(TAG, "📹 Capturing event video: eventId=$eventId, duration=${duration}s, buffer size=${videoBuffer.size}")
            
            // 计算需要多少个片段（每个片段约2秒）
            val segmentsNeeded = (duration / 2.0).toInt().coerceAtLeast(1)
            val segments = videoBuffer.takeLast(segmentsNeeded.coerceAtMost(videoBuffer.size))
            
            Log.d(TAG, "📹 Using ${segments.size} segments for ${duration}s video")
            
            // 如果只有一个片段，直接复制
            if (segments.size == 1) {
                val outputFile = saveVideoToGallery(eventId, segments[0])
                if (outputFile != null) {
                    result.success(outputFile)
                    Log.d(TAG, "✅ Video saved (single segment): $outputFile")
                } else {
                    result.success(null)
                    Log.e(TAG, "❌ Failed to save video")
                }
                return
            }
            
            // 多个片段需要合并
            mergeVideos(eventId, segments) { outputPath ->
                if (outputPath != null) {
                    result.success(outputPath)
                    Log.d(TAG, "✅ Video merged and saved: $outputPath")
                } else {
                    result.success(null)
                    Log.e(TAG, "❌ Failed to merge videos")
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to capture event video", e)
            result.error("CAPTURE_FAILED", "Failed to capture: ${e.message}", null)
        }
    }

    /**
     * 获取预览纹理ID
     */
    private fun getPreviewTextureId(result: Result) {
        try {
            if (textureEntry == null) {
                textureEntry = textureRegistry.createSurfaceTexture()
                Log.d(TAG, "✅ Created SurfaceTexture: ${textureEntry?.id()}")
            }
            
            // 将预览绑定到纹理
            preview?.setSurfaceProvider { request ->
                val texture = textureEntry?.surfaceTexture()
                if (texture != null) {
                    texture.setDefaultBufferSize(
                        request.resolution.width,
                        request.resolution.height
                    )
                    val surface = android.view.Surface(texture)
                    request.provideSurface(surface, cameraExecutor) { 
                        Log.d(TAG, "✅ Preview surface provided")
                    }
                } else {
                    Log.e(TAG, "❌ SurfaceTexture is null")
                }
            }
            
            // 绑定摄像头（如果还没有绑定）
            if (camera == null && cameraProvider != null) {
                val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA
                try {
                    cameraProvider?.unbindAll()
                    camera = cameraProvider?.bindToLifecycle(
                        lifecycleOwner,
                        cameraSelector,
                        preview
                    )
                    Log.d(TAG, "✅ Camera bound for preview")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to bind camera for preview", e)
                }
            }
            
            val textureId = textureEntry?.id()
            Log.d(TAG, "✅ Returning texture ID: $textureId")
            result.success(textureId)
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to get texture ID", e)
            result.error("TEXTURE_FAILED", "Failed to get texture: ${e.message}", null)
        }
    }

    /**
     * 释放资源
     */
    private fun dispose(result: Result) {
        try {
            isRecording = false
            recording?.stop()
            cameraProvider?.unbindAll()
            cameraExecutor.shutdown()
            textureEntry?.release()
            
            videoBuffer.forEach { it.delete() }
            videoBuffer.clear()
            
            result.success(true)
            Log.d(TAG, "Resources disposed")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to dispose", e)
            result.error("DISPOSE_FAILED", "Failed to dispose: ${e.message}", null)
        }
    }

    /**
     * 开始录制一个视频片段（用于循环缓冲）
     */
    private fun startSegmentRecording() {
        if (!isRecording) return
        
        val videoFile = File(context.cacheDir, "segment_${System.currentTimeMillis()}.mp4")
        
        val outputOptions = FileOutputOptions.Builder(videoFile).build()
        
        recording = videoCapture?.output
            ?.prepareRecording(context, outputOptions)
            ?.start(cameraExecutor) { recordEvent ->
                when (recordEvent) {
                    is VideoRecordEvent.Finalize -> {
                        if (recordEvent.hasError()) {
                            Log.e(TAG, "Recording error: ${recordEvent.error}")
                        } else {
                            // 添加到缓冲区
                            videoBuffer.add(videoFile)
                            
                            // 移除超过缓冲时长的旧片段
                            val maxSegments = bufferDuration / 2 // 每2秒一个片段
                            if (videoBuffer.size > maxSegments) {
                                val oldFile = videoBuffer.removeAt(0)
                                oldFile.delete()
                            }
                            
                            Log.d(TAG, "Segment recorded: ${videoFile.name}")
                        }
                        
                        // 继续录制下一个片段
                        if (isRecording) {
                            startSegmentRecording()
                        }
                    }
                }
            }
        
        // 2秒后停止当前片段录制
        cameraExecutor.execute {
            Thread.sleep(2000)
            recording?.stop()
        }
    }
    
    /**
     * 保存视频到相册
     */
    private fun saveVideoToGallery(eventId: String, sourceFile: File): String? {
        return try {
            if (!sourceFile.exists()) {
                Log.e(TAG, "❌ Source file does not exist: ${sourceFile.absolutePath}")
                return null
            }
            
            val displayName = "Puked_Event_$eventId.mp4"
            val mimeType = "video/mp4"
            
            // Android 10+ 使用 MediaStore
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                val contentValues = android.content.ContentValues().apply {
                    put(android.provider.MediaStore.MediaColumns.DISPLAY_NAME, displayName)
                    put(android.provider.MediaStore.MediaColumns.MIME_TYPE, mimeType)
                    put(android.provider.MediaStore.MediaColumns.RELATIVE_PATH, "Movies/Puked")
                }
                
                val resolver = context.contentResolver
                val uri = resolver.insert(
                    android.provider.MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                    contentValues
                )
                
                if (uri != null) {
                    resolver.openOutputStream(uri)?.use { outputStream ->
                        sourceFile.inputStream().use { inputStream ->
                            inputStream.copyTo(outputStream)
                        }
                    }
                    
                    // ✅ 通知媒体扫描器刷新
                    android.media.MediaScannerConnection.scanFile(
                        context,
                        arrayOf(uri.toString()),
                        arrayOf(mimeType),
                        null
                    )
                    
                    Log.d(TAG, "✅ Video saved to gallery: $uri")
                    uri.toString()
                } else {
                    Log.e(TAG, "❌ Failed to create MediaStore URI")
                    null
                }
            } else {
                // Android 9 及以下，保存到 Movies 目录
                val moviesDir = android.os.Environment.getExternalStoragePublicDirectory(
                    android.os.Environment.DIRECTORY_MOVIES
                )
                val pukedDir = File(moviesDir, "Puked")
                if (!pukedDir.exists()) {
                    pukedDir.mkdirs()
                }
                
                val destFile = File(pukedDir, displayName)
                sourceFile.copyTo(destFile, overwrite = true)
                
                // 通知系统扫描新文件
                val mediaScanIntent = android.content.Intent(android.content.Intent.ACTION_MEDIA_SCANNER_SCAN_FILE)
                mediaScanIntent.data = android.net.Uri.fromFile(destFile)
                context.sendBroadcast(mediaScanIntent)
                
                Log.d(TAG, "✅ Video saved to: ${destFile.absolutePath}")
                destFile.absolutePath
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to save video to gallery", e)
            null
        }
    }
    
    /**
     * 合并多个视频片段
     */
    private fun mergeVideos(eventId: String, segments: List<File>, callback: (String?) -> Unit) {
        cameraExecutor.execute {
            try {
                // 创建临时输出文件
                val tempOutput = File(context.cacheDir, "merged_$eventId.mp4")
                if (tempOutput.exists()) {
                    tempOutput.delete()
                }
                
                val muxer = android.media.MediaMuxer(
                    tempOutput.absolutePath,
                    android.media.MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4
                )
                
                var videoTrackIndex = -1
                var started = false
                var totalDurationUs = 0L  // ✅ 累计时间偏移
                
                // 合并所有片段
                for ((index, segment) in segments.withIndex()) {
                    if (!segment.exists()) {
                        Log.w(TAG, "⚠️ Segment $index does not exist: ${segment.absolutePath}")
                        continue
                    }
                    
                    val extractor = android.media.MediaExtractor()
                    extractor.setDataSource(segment.absolutePath)
                    
                    // 找到视频轨道
                    for (i in 0 until extractor.trackCount) {
                        val format = extractor.getTrackFormat(i)
                        val mime = format.getString(android.media.MediaFormat.KEY_MIME) ?: continue
                        
                        if (mime.startsWith("video/")) {
                            extractor.selectTrack(i)
                            
                            if (videoTrackIndex == -1) {
                                // 只在第一次添加轨道
                                videoTrackIndex = muxer.addTrack(format)
                            }
                            
                            if (!started) {
                                muxer.start()
                                started = true
                            }
                            
                            // 复制数据
                            val buffer = java.nio.ByteBuffer.allocate(1024 * 1024) // 1MB buffer
                            val bufferInfo = android.media.MediaCodec.BufferInfo()
                            
                            var segmentDuration = 0L
                            
                            while (true) {
                                val sampleSize = extractor.readSampleData(buffer, 0)
                                if (sampleSize < 0) break
                                
                                bufferInfo.offset = 0
                                bufferInfo.size = sampleSize
                                // ✅ 关键修复：累加时间偏移，而不是使用原始时间戳
                                val sampleTime = extractor.sampleTime
                                bufferInfo.presentationTimeUs = totalDurationUs + sampleTime
                                bufferInfo.flags = extractor.sampleFlags
                                
                                // 记录最大时间戳
                                if (sampleTime > segmentDuration) {
                                    segmentDuration = sampleTime
                                }
                                
                                muxer.writeSampleData(videoTrackIndex, buffer, bufferInfo)
                                extractor.advance()
                            }
                            
                            // ✅ 更新总时长，加上这个片段的时长
                            totalDurationUs += segmentDuration
                            
                            Log.d(TAG, "✅ Merged segment $index (duration: ${segmentDuration / 1000}ms, total: ${totalDurationUs / 1000}ms)")
                            
                            break
                        }
                    }
                    
                    extractor.release()
                }
                
                if (started) {
                    muxer.stop()
                }
                muxer.release()
                
                Log.d(TAG, "📹 Total merged video duration: ${totalDurationUs / 1_000_000.0}s")
                
                // 保存到相册
                val galleryPath = saveVideoToGallery(eventId, tempOutput)
                
                // 清理临时文件
                tempOutput.delete()
                
                callback(galleryPath)
            } catch (e: Exception) {
                Log.e(TAG, "❌ Failed to merge videos", e)
                callback(null)
            }
        }
    }
}
