import AVFoundation
import Flutter
import UIKit
import Photos

/// 视频录制管理器
/// 
/// 实现：
/// - 10秒循环缓冲录制（无音频）
/// - 事件触发时保存前5秒视频
/// - 摄像头预览
class VideoRecordingManager: NSObject {
    // MARK: - Properties
    
    /// 摄像头会话
    private var captureSession: AVCaptureSession?
    
    /// 视频输出
    private var videoOutput: AVCaptureVideoDataOutput?
    
    /// 预览图层
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    /// 循环缓冲区（保存最近10秒的样本）
    private var sampleBuffer: [CMSampleBuffer] = []
    
    /// 缓冲区锁
    private let bufferLock = NSLock()
    
    /// 是否正在录制
    private var isRecording = false
    
    /// 缓冲时长（秒）
    private var bufferDuration: TimeInterval = 10.0
    
    /// 视频录制队列
    private let videoQueue = DispatchQueue(label: "com.puked.videoRecording")
    
    /// 纹理注册表（用于 Flutter Texture）
    private var textureRegistry: FlutterTextureRegistry?
    
    /// 纹理ID
    private var textureId: Int64?
    
    /// Flutter Texture 实例
    private var cameraTexture: CameraTexture?
    
    // MARK: - Initialization
    
    init(textureRegistry: FlutterTextureRegistry) {
        self.textureRegistry = textureRegistry
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// 初始化视频录制
    func initialize() -> Bool {
        // 创建捕获会话
        let session = AVCaptureSession()
        session.sessionPreset = .hd1920x1080
        
        // 配置摄像头输入
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            print("[VideoRecording] Failed to setup camera input")
            return false
        }
        
        session.addInput(input)
        
        // 配置视频输出
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: videoQueue)
        
        guard session.canAddOutput(output) else {
            print("[VideoRecording] Failed to add video output")
            return false
        }
        
        session.addOutput(output)
        
        // ✅ 设置视频连接方向为竖屏
        if let connection = output.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            // 如果是前置摄像头，需要镜像
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = false // 后置摄像头不镜像
            }
        }
        
        self.captureSession = session
        self.videoOutput = output
        
        // 创建预览图层
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        self.previewLayer = preview
        
        // ✅ 立即启动 session 用于预览（但不开启录制）
        videoQueue.async {
            session.startRunning()
            print("[VideoRecording] ✅ Camera session started for preview")
        }
        
        return true
    }
    
    /// 检查摄像头权限
    func checkCameraPermission() -> Bool {
        return AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }
    
    /// 请求摄像头权限
    func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            completion(granted)
        }
    }
    
    /// 开始循环录制
    func startRecording(bufferDuration: TimeInterval = 10.0) -> Bool {
        guard let session = captureSession else {
            print("[VideoRecording] Capture session not initialized")
            return false
        }
        
        self.bufferDuration = bufferDuration
        self.isRecording = true
        
        // 清空缓冲区
        bufferLock.lock()
        sampleBuffer.removeAll()
        bufferLock.unlock()
        
        // 启动会话
        videoQueue.async {
            session.startRunning()
        }
        
        print("[VideoRecording] Started recording with buffer duration: \(bufferDuration)s")
        return true
    }
    
    /// 停止循环录制
    func stopRecording() -> Bool {
        // ✅ 直接检查 captureSession 是否存在，无需赋值给未使用的变量
        guard captureSession != nil else {
            return false
        }
        
        self.isRecording = false
        
        // ⚠️ 重要：不要停止 session！这样会导致预览消失
        // 只需要设置 isRecording = false，captureOutput 会自动停止保存帧
        // videoQueue.async {
        //     session.stopRunning()  // ❌ 删除这行
        // }
        
        // 清空缓冲区
        bufferLock.lock()
        sampleBuffer.removeAll()
        bufferLock.unlock()
        
        print("[VideoRecording] ✅ Stopped recording, preview remains active")
        return true
    }
    
    /// 捕获事件视频（保存前N秒）
    func captureEventVideo(eventId: String, duration: TimeInterval) -> String? {
        guard isRecording else {
            print("[VideoRecording] Cannot capture: not recording")
            return nil
        }
        
        bufferLock.lock()
        let samples = Array(sampleBuffer.suffix(Int(duration * 60))) // 假设 60fps
        bufferLock.unlock()
        
        guard !samples.isEmpty else {
            print("[VideoRecording] ⚠️ Buffer is empty")
            return nil
        }
        
        print("[VideoRecording] 📹 Capturing \(samples.count) frames for event \(eventId)")
        
        // 生成临时文件路径
        let tempPath = FileManager.default.temporaryDirectory.appendingPathComponent("temp_\(eventId).mp4")
        
        // 异步保存视频到临时文件，然后保存到相册
        saveVideo(samples: samples, to: tempPath) { [weak self] success in
            if success {
                print("[VideoRecording] ✅ Video saved to temp: \(tempPath.path)")
                // 保存到相册
                self?.saveVideoToPhotoLibrary(tempPath) { savedPath in
                    if let path = savedPath {
                        print("[VideoRecording] ✅ Video saved to Photos: \(path)")
                    } else {
                        print("[VideoRecording] ⚠️ Failed to save to Photos, kept in temp")
                    }
                    // 清理临时文件
                    try? FileManager.default.removeItem(at: tempPath)
                }
            } else {
                print("[VideoRecording] ❌ Failed to save video")
            }
        }
        
        // 立即返回临时路径
        return tempPath.path
    }
    
    /// 获取预览纹理ID
    func getPreviewTextureId() -> Int64? {
        guard let registry = textureRegistry else {
            print("[VideoRecording] Texture registry not available")
            return nil
        }
        
        // 创建 CameraTexture 实例
        let texture = CameraTexture()
        self.cameraTexture = texture
        
        // 注册 Texture
        let id = registry.register(texture)
        self.textureId = id
        
        print("[VideoRecording] ✅ Texture created with ID: \(id)")
        return id
    }
    
    /// 释放资源
    func dispose() {
        // ✅ 处理 stopRecording 的返回值，记录日志以便调试
        let success = stopRecording()
        if !success {
            print("[VideoRecording] ⚠️ Failed to stop recording during disposal")
        }
        
        captureSession = nil
        videoOutput = nil
        previewLayer = nil
    }
    
    // MARK: - Private Methods
    
    /// 保存视频到文件
    private func saveVideo(samples: [CMSampleBuffer], to url: URL, completion: @escaping (Bool) -> Void) {
        // 删除旧文件
        try? FileManager.default.removeItem(at: url)
        
        guard let writer = try? AVAssetWriter(url: url, fileType: .mp4) else {
            completion(false)
            return
        }
        
        // 配置视频输入
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 1920,
            AVVideoHeightKey: 1080,
        ]
        
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false
        
        guard writer.canAdd(writerInput) else {
            completion(false)
            return
        }
        
        writer.add(writerInput)
        
        // 开始写入
        writer.startWriting()
        writer.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(samples[0]))
        
        // 异步写入样本
        let writeQueue = DispatchQueue(label: "com.puked.videoWriter")
        writeQueue.async {
            for sample in samples {
                while !writerInput.isReadyForMoreMediaData {
                    usleep(10000) // 等待10ms
                }
                writerInput.append(sample)
            }
            
            writerInput.markAsFinished()
            writer.finishWriting {
                completion(writer.status == .completed)
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension VideoRecordingManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // 🎥 始终更新 Flutter Texture 用于预览显示
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            cameraTexture?.updateBuffer(pixelBuffer)
            
            // 通知 Flutter 有新帧可用
            if let textureId = textureId, let registry = textureRegistry {
                DispatchQueue.main.async {
                    registry.textureFrameAvailable(textureId)
                }
            }
        }
        
        // ⚠️ 只有在录制状态时才保存帧到缓冲区
        guard isRecording else { return }
        
        // 保留样本到缓冲区（用于事件捕获）
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        // 添加新样本
        self.sampleBuffer.append(sampleBuffer)
        
        // 移除超过缓冲时长的旧样本
        let maxSamples = Int(bufferDuration * 60) // 假设 60fps
        if self.sampleBuffer.count > maxSamples {
            self.sampleBuffer.removeFirst(self.sampleBuffer.count - maxSamples)
        }
    }
}

// MARK: - Photo Library

extension VideoRecordingManager {
    /// 保存视频到相册
    func saveVideoToPhotoLibrary(_ videoURL: URL, completion: @escaping (String?) -> Void) {
        // 检查权限（iOS 14+ 使用新 API，iOS 13 使用旧 API）
        if #available(iOS 14, *) {
            let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
            
            if status == .authorized || status == .limited {
                performSave(videoURL: videoURL, completion: completion)
            } else if status == .notDetermined {
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                    if newStatus == .authorized || newStatus == .limited {
                        self.performSave(videoURL: videoURL, completion: completion)
                    } else {
                        print("[VideoRecording] ❌ Photo library access denied")
                        completion(nil)
                    }
                }
            } else {
                print("[VideoRecording] ❌ Photo library access denied")
                completion(nil)
            }
        } else {
            // iOS 13 兼容性代码
            let status = PHPhotoLibrary.authorizationStatus()
            
            if status == .authorized {
                performSave(videoURL: videoURL, completion: completion)
            } else if status == .notDetermined {
                PHPhotoLibrary.requestAuthorization { newStatus in
                    if newStatus == .authorized {
                        self.performSave(videoURL: videoURL, completion: completion)
                    } else {
                        print("[VideoRecording] ❌ Photo library access denied")
                        completion(nil)
                    }
                }
            } else {
                print("[VideoRecording] ❌ Photo library access denied")
                completion(nil)
            }
        }
    }
    
    private func performSave(videoURL: URL, completion: @escaping (String?) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .video, fileURL: videoURL, options: nil)
        }) { success, error in
            if success {
                print("[VideoRecording] ✅ Video saved to Photos")
                completion(videoURL.path)
            } else {
                print("[VideoRecording] ❌ Failed to save to Photos: \(error?.localizedDescription ?? "unknown error")")
                completion(nil)
            }
        }
    }
}

// MARK: - CameraTexture

/// Flutter Texture 实现，用于显示摄像头预览
class CameraTexture: NSObject, FlutterTexture {
    private var pixelBuffer: CVPixelBuffer?
    private let bufferLock = NSLock()
    
    /// Flutter 调用此方法获取最新的帧
    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        
        guard let buffer = pixelBuffer else {
            return nil
        }
        
        return Unmanaged.passRetained(buffer)
    }
    
    /// 更新缓冲区（从摄像头回调中调用）
    func updateBuffer(_ buffer: CVPixelBuffer) {
        bufferLock.lock()
        pixelBuffer = buffer
        bufferLock.unlock()
    }
}

