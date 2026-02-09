import Foundation
import CoreGraphics

/// 全局通用的布局配置，用于同步预览与导出的视觉位置
struct LayoutConfig: Sendable {
    var speedX: CGFloat
    var gX: CGFloat
    var cW: CGFloat
    var cY: CGFloat
    
    /// 默认布局
    static let `default` = LayoutConfig(speedX: 0, gX: 0, cW: 420, cY: 0)
}
