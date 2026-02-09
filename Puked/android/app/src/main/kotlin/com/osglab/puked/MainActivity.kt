package com.osglab.puked

import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity: AudioServiceActivity() {
    private var videoRecordingManager: VideoRecordingManager? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 🎥 注册视频录制 Method Channel
        videoRecordingManager = VideoRecordingManager(
            activity = this,
            lifecycleOwner = this,
            textureRegistry = flutterEngine.renderer
        )
        videoRecordingManager?.setupChannel(flutterEngine.dartExecutor.binaryMessenger)
        
        android.util.Log.d("MainActivity", "Video recording channel registered")
    }
    
    override fun onDestroy() {
        super.onDestroy()
        videoRecordingManager = null
    }
}
