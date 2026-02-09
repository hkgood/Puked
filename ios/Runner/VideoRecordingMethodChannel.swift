import Flutter
import UIKit
import AVFoundation  // ✅ 添加 AVFoundation 以使用 AVCaptureDevice API

/// 视频录制 Method Channel 处理器
class VideoRecordingMethodChannel: NSObject {
    private let methodChannelName = "com.puked/video_recording"
    private var videoManager: VideoRecordingManager?
    private var channel: FlutterMethodChannel?
    
    func setup(messenger: FlutterBinaryMessenger, textureRegistry: FlutterTextureRegistry) {
        let channel = FlutterMethodChannel(name: methodChannelName, binaryMessenger: messenger)
        self.channel = channel
        
        channel.setMethodCallHandler { [weak self] (call, result) in
            self?.handle(call, result: result, textureRegistry: textureRegistry)
        }
        
        print("[VideoRecordingChannel] Method channel setup complete")
    }
    
    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult, textureRegistry: FlutterTextureRegistry) {
        switch call.method {
        case "initialize":
            handleInitialize(result: result, textureRegistry: textureRegistry)
            
        case "checkCameraPermission":
            handleCheckPermission(result: result)
            
        case "requestCameraPermission":
            handleRequestPermission(result: result)
            
        case "startRecording":
            handleStartRecording(call: call, result: result)
            
        case "stopRecording":
            handleStopRecording(result: result)
            
        case "captureEvent":
            handleCaptureEvent(call: call, result: result)
            
        case "getPreviewTextureId":
            handleGetTextureId(result: result)
            
        case "dispose":
            handleDispose(result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func handleInitialize(result: @escaping FlutterResult, textureRegistry: FlutterTextureRegistry) {
        let manager = VideoRecordingManager(textureRegistry: textureRegistry)
        let success = manager.initialize()
        
        if success {
            self.videoManager = manager
            result(true)
        } else {
            result(FlutterError(code: "INIT_FAILED", message: "Failed to initialize video recording", details: nil))
        }
    }
    
    /// ✅ 权限检查不需要依赖 videoManager，可以直接调用 AVCaptureDevice API
    private func handleCheckPermission(result: @escaping FlutterResult) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        result(status == .authorized)
    }
    
    /// ✅ 权限请求不需要依赖 videoManager，可以直接调用 AVCaptureDevice API
    private func handleRequestPermission(result: @escaping FlutterResult) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            // ⚠️ requestAccess 在后台线程回调，需要确保 Flutter 结果在主线程返回
            DispatchQueue.main.async {
                result(granted)
            }
        }
    }
    
    private func handleStartRecording(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let manager = videoManager else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Video manager not initialized", details: nil))
            return
        }
        
        let args = call.arguments as? [String: Any]
        let bufferDuration = args?["bufferDuration"] as? Double ?? 10.0
        
        let success = manager.startRecording(bufferDuration: bufferDuration)
        result(success)
    }
    
    private func handleStopRecording(result: @escaping FlutterResult) {
        guard let manager = videoManager else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Video manager not initialized", details: nil))
            return
        }
        
        let success = manager.stopRecording()
        result(success)
    }
    
    private func handleCaptureEvent(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let manager = videoManager else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Video manager not initialized", details: nil))
            return
        }
        
        guard let args = call.arguments as? [String: Any],
              let eventId = args["eventId"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing eventId", details: nil))
            return
        }
        
        let duration = args["duration"] as? Double ?? 5.0
        
        if let videoPath = manager.captureEventVideo(eventId: eventId, duration: duration) {
            result(videoPath)
        } else {
            result(nil)
        }
    }
    
    private func handleGetTextureId(result: @escaping FlutterResult) {
        guard let manager = videoManager else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Video manager not initialized", details: nil))
            return
        }
        
        result(manager.getPreviewTextureId())
    }
    
    private func handleDispose(result: @escaping FlutterResult) {
        videoManager?.dispose()
        videoManager = nil
        result(true)
    }
}
