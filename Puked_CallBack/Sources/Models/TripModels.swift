import Foundation
import CoreLocation
import SwiftUI
import AppKit

/// 整个行程的数据容器
struct TripData: Codable, Sendable {
    let version: String
    let tripId: String
    let metadata: TripMetadata
    let trajectory: [TrajectoryPoint]
    let events: [RecordedEvent]
    
    enum CodingKeys: String, CodingKey {
        case version
        case tripId = "trip_id"
        case metadata
        case trajectory
        case events
    }
}

/// 行程元数据
struct TripMetadata: Codable, Sendable {
    let startTime: String
    let endTime: String
    let carModel: String
    let appVersion: String?      // 可选字段，兼容旧版本数据
    let platform: String?         // 可选字段，兼容旧版本数据
    let algorithm: String?        // 可选字段，兼容旧版本数据
    let notes: String
    let eventCount: Int
    let trajectoryMeta: TrajectoryMeta?  // 可选字段，v2.5+ 新增
    
    enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case endTime = "end_time"
        case carModel = "car_model"
        case appVersion = "app_version"
        case platform
        case algorithm
        case notes
        case eventCount = "event_count"
        case trajectoryMeta = "trajectory_meta"
    }

    var brandLogoName: String? {
        let model = carModel.lowercased()
        let notesLower = notes.lowercased()
        
        if model.contains("xiaomi") || notesLower.contains("xiaomi") || model == "su7" { return "Xiaomi" }
        if model.contains("tesla") || notesLower.contains("tesla") || model.contains("model") { return "Tesla" }
        if model.contains("nio") || notesLower.contains("nio") || (model.starts(with: "e") && model.count == 3) || (model.starts(with: "s") && model.count == 3) { return "Nio" }
        if model.contains("xpeng") || notesLower.contains("xpeng") || model == "p7" || model == "p5" || model == "g6" || model == "g9" { return "Xpeng" }
        if model.contains("zeekr") || notesLower.contains("zeekr") || model == "001" || model == "007" || model == "009" { return "Zeekr" }
        if model.contains("liauto") || model.contains("li ") || (model.starts(with: "l") && model.count == 2) { return "LiAuto" }
        if model.contains("huawei") || model.contains("aiter") || model.contains("stella") || model.contains("问界") || model.contains("智界") { return "Huawei" }
        
        return nil
    }
}

/// 轨迹采集元信息（v2.5+ 上传 JSON 中携带）
struct TrajectoryMeta: Codable, Sendable {
    let originalCount: Int?   // 本地原始点数（iOS ~60fps / Android ~30fps）
    let uploadFps: Int?       // 上传时抽稀后的帧率（固定 6fps）
    let platform: String?

    enum CodingKeys: String, CodingKey {
        case originalCount = "original_count"
        case uploadFps = "upload_fps"
        case platform
    }
}

/// 轨迹点（支持 1Hz 稀疏点、6fps 上传点，或 30/60fps 本地导出点）
struct TrajectoryPoint: Codable, Identifiable, Sendable, Equatable {
    var id: Double { ts }
    let ts: Double
    let lat: Double
    let lng: Double
    let speed: Double
    let lowConf: Bool?
    
    // 高频传感器数据 (可选)。ax/ay/az 单位为 m/s²（与 Flutter 录制侧一致），不是 g。
    let ax: Double?
    let ay: Double?
    let az: Double?
    let gx: Double?
    let gy: Double?
    let gz: Double?
    
    enum CodingKeys: String, CodingKey {
        case ts
        case lat
        case lng
        case speed
        case lowConf = "low_conf"
        case ax, ay, az, gx, gy, gz
    }
    
    /// 标准重力加速度，用于 m/s² → g
    static let gravityMs2: Double = 9.80665
    
    /// 将轨迹加速度（m/s²）转为 g；缺测返回 nil
    var accelXInG: Double? { ax.map { $0 / Self.gravityMs2 } }
    var accelYInG: Double? { ay.map { $0 / Self.gravityMs2 } }
}

/// 负体验事件
struct RecordedEvent: Codable, Identifiable, Sendable {
    var id: String { uuid ?? id_backup ?? UUID().uuidString }
    let uuid: String? 
    let id_backup: String? 
    let timestamp: Double? // 修改为 Double，兼容 Unix 时间戳
    let type: String 
    let source: String?
    let speed: Double?
    let gForce: Double?
    let notes: String?
    let voiceText: String?
    let sensorData: [SensorPoint]?
    
    enum CodingKeys: String, CodingKey {
        case uuid
        case id_backup = "id"
        case timestamp
        case type
        case source
        case speed
        case gForce
        case notes
        case voiceText
        case sensorData
    }
    
    var eventType: EventType {
        EventType(rawValue: type) ?? .manual
    }
}

/// 嵌入在事件中的高频传感器点
struct SensorPoint: Codable, Sendable {
    let ax: Double?
    let ay: Double?
    let az: Double?
    let gx: Double?
    let gy: Double?
    let gz: Double?
    let mx: Double?
    let my: Double?
    let mz: Double?
    let offsetMs: Int?
}

/// 事件类型枚举
enum EventType: String, Codable, CaseIterable, Sendable {
    case rapidDeceleration = "rapidDeceleration"
    case rapidAcceleration = "rapidAcceleration"
    case jerk = "jerk"
    case bump = "bump"
    case wobble = "wobble"
    case manual = "manual"
    case proDisengagement = "proDisengagement"
    case proViolation = "proViolation"
    case proExperience = "proExperience"
    
    var displayName: String {
        switch self {
        case .rapidDeceleration: return "急刹车"
        case .rapidAcceleration: return "急加速"
        case .jerk: return "顿挫"
        case .bump: return "颠簸"
        case .wobble: return "摆动"
        case .manual: return "手动标记"
        case .proDisengagement: return "脱离"
        case .proViolation: return "违规"
        case .proExperience: return "体验"
        }
    }

    var iconName: String? {
        switch self {
        case .rapidDeceleration: return "arrow.down.circle.fill"      // 急刹：向下箭头
        case .rapidAcceleration: return "arrow.up.circle.fill"        // 急加速：向上箭头
        case .jerk: return "bolt.fill"                                // 顿挫：闪电
        case .bump: return "triangle.fill"                            // 颠簸：三角形警告
        case .wobble: return "arrow.left.and.right"                   // 摆动：左右箭头
        case .manual: return "hand.tap.fill"                          // 手动：点击手势
        default: return "exclamationmark.circle.fill"                 // 其他：感叹号
        }
    }

    var eventColor: Color {
        switch self {
        case .rapidDeceleration: return .red
        case .rapidAcceleration: return .green
        case .jerk: return .indigo
        case .bump: return .blue
        case .wobble: return .orange
        case .manual: return .gray
        default: return .gray
        }
    }

    var nsColor: NSColor {
        switch self {
        case .rapidDeceleration: return .systemRed
        case .rapidAcceleration: return .systemGreen
        case .jerk: return .systemIndigo
        case .bump: return .systemBlue
        case .wobble: return .systemOrange
        case .manual: return .systemGray
        default: return .systemGray
        }
    }
}
