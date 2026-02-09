import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var videoRecordingChannel: VideoRecordingMethodChannel?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // ✅ 在 super 调用后再访问 rootViewController，避免 Flutter 弃用警告
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    
    // 🎥 注册视频录制 Method Channel
    // 使用 FlutterViewController 协议方法，避免直接访问 window.rootViewController
    setupVideoChannel()
    
    return result
  }
  
  /// 设置视频录制通道
  private func setupVideoChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      print("[AppDelegate] ⚠️ Failed to get FlutterViewController")
      return
    }
    
    let videoChannel = VideoRecordingMethodChannel()
    // ✅ 使用 as 而不是 as!，因为 FlutterViewController 已实现 FlutterTextureRegistry 协议
    videoChannel.setup(
      messenger: controller.binaryMessenger,
      textureRegistry: controller as FlutterTextureRegistry
    )
    self.videoRecordingChannel = videoChannel
    print("[AppDelegate] ✅ Video recording channel registered")
  }
}
