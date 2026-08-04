import Foundation
import CoreLocation

/// 负责将稀疏数据插值为平滑流的引擎
final class DataInterpolator: Sendable {
    private let points: [TrajectoryPoint]
    private let startTime: Double
    private let endTime: Double
    private let calculatedG: [Double: (gx: Double, gy: Double)]
    // 预计算并缓存全程 G 值范围，避免每帧回放时重复 O(n) 扫描导致抖动
    let gForceRange: (min: Double, max: Double)
    
    enum FrequencyMode {
        case sparse    // 1Hz 左右，需要强补帧
        case highFreq  // 4Hz 及以上（含 6fps 上传数据、30fps、60fps），忠实还原
    }
    let mode: FrequencyMode
    
    init(points: [TrajectoryPoint]) {
        let sortedPoints = points.sorted { $0.ts < $1.ts }
        self.points = sortedPoints
        self.startTime = sortedPoints.first?.ts ?? 0
        self.endTime = sortedPoints.last?.ts ?? 0
        
        if sortedPoints.count > 1 {
            let avgInterval = (endTime - startTime) / Double(sortedPoints.count - 1)
            self.mode = avgInterval < 0.25 ? .highFreq : .sparse
            self.calculatedG = DataInterpolator.precalculateGValues(points: sortedPoints)
            self.gForceRange = DataInterpolator.calculateGForceRangeStatic(points: sortedPoints)
        } else {
            self.mode = .sparse
            self.calculatedG = [:]
            self.gForceRange = (-0.5, 0.5)
        }
    }
    
    private static func precalculateGValues(points: [TrajectoryPoint]) -> [Double: (gx: Double, gy: Double)] {
        var results: [Double: (gx: Double, gy: Double)] = [:]
        guard points.count >= 2 else { return [:] }
        let g0 = TrajectoryPoint.gravityMs2
        
        for i in 0..<points.count {
            let p = points[i]
            // 轨迹 ax/ay 为 m/s²，统一换算为 g 再进入显示/导出链路
            var gx = p.accelXInG ?? 0
            var gy = p.accelYInG ?? 0
            
            // 如果缺失加速度且是稀疏模式，使用中心差分法直接估算 g
            if p.ax == nil || p.ay == nil {
                let prevIdx = max(0, i - 1)
                let nextIdx = min(points.count - 1, i + 1)
                let prev = points[prevIdx]
                let next = points[nextIdx]
                let dt = next.ts - prev.ts
                
                if dt > 0 {
                    if p.ax == nil {
                        gx = ((next.speed - prev.speed) / dt) / g0
                    }
                    if p.ay == nil {
                        let hPrev = (i == 0) ? calculateHeadingStatic(from: points[0], to: points[1]) : calculateHeadingStatic(from: points[i-1], to: points[i])
                        let hNext = (i == points.count - 1) ? calculateHeadingStatic(from: points[i-1], to: points[i]) : calculateHeadingStatic(from: points[i], to: points[i+1])
                        
                        var dH = hNext - hPrev
                        if dH > 180 { dH -= 360 }
                        if dH < -180 { dH += 360 }
                        
                        let dtInner = (i == 0 || i == points.count - 1) ? (next.ts - prev.ts) : (points[i+1].ts - points[i-1].ts)
                        let omega = dtInner > 0 ? (dH * .pi / 180.0) / dtInner : 0
                        gy = (p.speed * omega) / g0
                    }
                } else if points.count >= 2 {
                    // 如果 dt 为 0（极其罕见），尝试使用相邻段的加速度
                    if i == 0 {
                        let dts = points[1].ts - points[0].ts
                        if dts > 0 { gx = ((points[1].speed - points[0].speed) / dts) / g0 }
                    }
                }
            }
            results[p.ts] = (gx, gy)
        }
        return results
    }
    
    private static func calculateHeadingStatic(from: TrajectoryPoint, to: TrajectoryPoint) -> Double {
        let lat1 = from.lat * Double.pi / 180; let lon1 = from.lng * Double.pi / 180
        let lat2 = to.lat * Double.pi / 180; let lon2 = to.lng * Double.pi / 180
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return atan2(y, x) * 180 / Double.pi
    }
    
    func state(at timestamp: Double) -> InterpolatedState? {
        guard timestamp >= startTime, timestamp <= endTime else { return nil }
        
        // 二分搜索，O(log n)，替代 firstIndex(where:) 的 O(n) 线性扫描
        var lo = 0; var hi = points.count - 1
        while lo < hi {
            let mid = (lo + hi) / 2
            if points[mid].ts < timestamp { lo = mid + 1 } else { hi = mid }
        }
        let index = lo
        if index == 0 { return makeState(from: points[0]) }
        
        let p1 = points[index - 1]
        let p2 = points[index]
        
        let t = (timestamp - p1.ts) / (p2.ts - p1.ts)
        
        // 1. 基础物理量插值 (使用平滑步进)
        let lat = p1.lat + (p2.lat - p1.lat) * t
        let lng = p1.lng + (p2.lng - p1.lng) * t
        let smoothT = t * t * (3 - 2 * t)
        let speed = p1.speed + (p2.speed - p1.speed) * smoothT
        
        // 2. G 值插值 (使用预计算点 + 线性插值)
        let g1 = calculatedG[p1.ts] ?? (gx: 0, gy: 0)
        let g2 = calculatedG[p2.ts] ?? (gx: 0, gy: 0)
        
        let gX = g1.gx + (g2.gx - g1.gx) * t
        let gY = g1.gy + (g2.gy - g1.gy) * t
        
        return InterpolatedState(
            timestamp: timestamp,
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
            speed: speed,
            gForceLongitudinal: gX,
            gForceLateral: gY
        )
    }
    
    private func makeState(from point: TrajectoryPoint) -> InterpolatedState {
        return InterpolatedState(
            timestamp: point.ts,
            coordinate: CLLocationCoordinate2D(latitude: point.lat, longitude: point.lng),
            speed: point.speed,
            gForceLongitudinal: point.accelXInG ?? 0,
            gForceLateral: point.accelYInG ?? 0
        )
    }
    
    func calculateGForceRange() -> (min: Double, max: Double) {
        // 直接返回初始化时预计算的缓存值，避免每帧 O(n) 扫描
        return gForceRange
    }
    
    private static func calculateGForceRangeStatic(points: [TrajectoryPoint]) -> (min: Double, max: Double) {
        var minG = 0.0
        var maxG = 0.0
        
        // 直接遍历原始数据点（先 m/s²→g），不采样，确保不漏掉任何峰值
        for point in points {
            if let gx = point.accelXInG {
                minG = min(minG, gx)
                maxG = max(maxG, gx)
            }
            if let gy = point.accelYInG {
                minG = min(minG, gy)
                maxG = max(maxG, gy)
            }
        }
        
        if minG == 0.0 && maxG == 0.0 {
            return (-0.5, 0.5)
        }
        
        // 量程至少覆盖 ±0.5g，避免低动态行程波形被过度放大
        let pad = 0.5
        return (min(minG, -pad), max(maxG, pad))
    }
}

struct InterpolatedState: Sendable {
    let timestamp: Double; let coordinate: CLLocationCoordinate2D; let speed: Double 
    let gForceLongitudinal: Double; let gForceLateral: Double
    var speedKmh: Double { speed * 3.6 }
}
