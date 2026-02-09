import AVFoundation
import SwiftUI
import CoreGraphics
import CoreVideo
import CoreText
import AppKit
import CoreLocation

enum ExportQuality: String, CaseIterable, Identifiable {
    case normal = "普通"
    case high = "高"
    case lossless = "无损"
    
    var id: String { self.rawValue }
    
    var bitrate: Int {
        switch self {
        case .normal: return 16_000_000 // 翻倍至 16Mbps
        case .high: return 50_000_000   // 翻倍至 50Mbps
        case .lossless: return 160_000_000 // 翻倍至 160Mbps
        }
    }
    
    var quality: Float {
        switch self {
        case .normal: return 0.6
        case .high: return 1.0
        case .lossless: return 1.0
        }
    }
}

// 包装器
struct SendableBuffer: @unchecked Sendable { let buffer: CVPixelBuffer }
struct SendablePool: @unchecked Sendable { let pool: CVPixelBufferPool }
struct SendableImage: @unchecked Sendable { let image: CGImage }

@MainActor
final class VideoExportEngine: ObservableObject {
    @Published var isExporting = false
    @Published var progress: Double = 0
    @Published var estimatedTimeRemaining: String = ""
    
    private var exportStartTime: Date?

    func export(trip: TripData, outputURL: URL, layout: LayoutConfig, showEvents: Bool, quality: ExportQuality, range: ClosedRange<Double>? = nil) async -> Bool {
        isExporting = true
        progress = 0
        estimatedTimeRemaining = "计算中..."
        exportStartTime = Date()
        
        let fullStartTime = trip.trajectory.first?.ts ?? 0; let fullEndTime = trip.trajectory.last?.ts ?? 0
        let startTime = range?.lowerBound ?? fullStartTime
        let endTime = range?.upperBound ?? fullEndTime
        let totalDuration = endTime - startTime; let fps = 30; let totalFrames = Int(totalDuration * Double(fps))
        
        let interpolator = DataInterpolator(points: trip.trajectory)
        let precalculatedStates = (0...totalFrames).map { idx -> InterpolatedState in
            interpolator.state(at: startTime + Double(idx) / Double(fps)) ?? InterpolatedState(timestamp: 0, coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0), speed: 0, gForceLongitudinal: 0, gForceLateral: 0)
        }
        
        let gRange = interpolator.calculateGForceRange()
        
        let writer = try! AVAssetWriter(outputURL: outputURL, fileType: AVFileType.mov)
        
        // --- 2x 高清导出配置 (1200x800) ---
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevcWithAlpha,
            AVVideoWidthKey: 1200, // 2x
            AVVideoHeightKey: 800, // 2x
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: quality.bitrate,
                AVVideoMaxKeyFrameIntervalKey: quality == .lossless ? 1 : 30,
                AVVideoQualityKey: quality.quality,
                AVVideoExpectedSourceFrameRateKey: 30
            ]
        ]
        
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = false
        
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: 1200,
            kCVPixelBufferHeightKey as String: 800,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ])
        
        writer.add(input); writer.startWriting(); writer.startSession(atSourceTime: CMTime.zero)
        
        let wrappedLogo = trip.metadata.brandLogoName.flatMap { name in NSImage(named: name)?.cgImage(forProposedRect: nil, context: nil, hints: nil).map { SendableImage(image: $0) } }
        var eventIcons: [String: SendableImage] = [:]
        for type in EventType.allCases {
            if let name = type.iconName, let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                eventIcons[name] = SendableImage(image: img)
            }
        }
        let speedIcon = NSImage(systemSymbolName: "speedometer", accessibilityDescription: nil)?.cgImage(forProposedRect: nil, context: nil, hints: nil).map { SendableImage(image: $0) }
        let clockIcon = NSImage(systemSymbolName: "clock", accessibilityDescription: nil)?.cgImage(forProposedRect: nil, context: nil, hints: nil).map { SendableImage(image: $0) }
        
        let batchSize = 10; var frameIndex = 0
        while frameIndex <= totalFrames {
            while !input.isReadyForMoreMediaData { try? await Task.sleep(nanoseconds: 5_000_000) }
            let end = min(frameIndex + batchSize, totalFrames); let range = frameIndex...end
            guard let pool = adaptor.pixelBufferPool else { continue }
            let wrappedPool = SendablePool(pool: pool)
            
            let buffers = await withTaskGroup(of: (Int, SendableBuffer?).self) { group in
                for idx in range {
                    let state = idx < precalculatedStates.count ? precalculatedStates[idx] : nil
                    let currentTime = startTime + Double(idx) / Double(fps)
                    let history = Array(precalculatedStates[max(0, idx-3000)...idx])
                    
                    group.addTask(priority: .high) { [state, history, layout, wrappedPool, wrappedLogo, eventIcons, trip, speedIcon, clockIcon, gRange, showEvents] in
                        let mode = interpolator.mode
                        if let b = VideoExportEngine.renderFrameStatic(state: state, history: history, layout: layout, pool: wrappedPool.pool, currentTime: currentTime, logo: wrappedLogo?.image, eventIcons: eventIcons, events: trip.events, speedIcon: speedIcon?.image, clockIcon: clockIcon?.image, gRange: gRange, showEvents: showEvents, mode: mode) { return (idx, SendableBuffer(buffer: b)) }
                        return (idx, nil)
                    }
                }
                var results: [(Int, SendableBuffer)] = []; for await (idx, wrapped) in group { if let w = wrapped { results.append((idx, w)) } }
                return results.sorted { $0.0 < $1.0 }
            }
            
            for (idx, wrapped) in buffers {
                while !input.isReadyForMoreMediaData { try? await Task.sleep(nanoseconds: 2_000_000) }
                if writer.status == AVAssetWriter.Status.writing { adaptor.append(wrapped.buffer, withPresentationTime: CMTime(value: Int64(idx), timescale: Int32(fps))) }
            }
            frameIndex += buffers.count
            
            if frameIndex % 30 == 0 || frameIndex == totalFrames {
                let currentProgress = Double(frameIndex) / Double(totalFrames)
                self.progress = currentProgress
                if let startTime = exportStartTime {
                    let elapsed = Date().timeIntervalSince(startTime)
                    if currentProgress > 0.01 {
                        let totalEstimated = elapsed / currentProgress
                        let remaining = totalEstimated - elapsed
                        if remaining > 0 { self.estimatedTimeRemaining = String(format: "%02d:%02d", Int(remaining) / 60, Int(remaining) % 60) }
                    }
                }
            }
        }
        
        input.markAsFinished(); await writer.finishWriting(); self.isExporting = false; self.estimatedTimeRemaining = ""; return true
    }
    
    nonisolated private static func renderFrameStatic(state: InterpolatedState?, history: [InterpolatedState], layout: LayoutConfig, pool: CVPixelBufferPool?, currentTime: Double, logo: CGImage?, eventIcons: [String: SendableImage], events: [RecordedEvent], speedIcon: CGImage?, clockIcon: CGImage?, gRange: (min: Double, max: Double), showEvents: Bool, mode: DataInterpolator.FrequencyMode) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?; CVPixelBufferPoolCreatePixelBuffer(nil, pool!, &pixelBuffer)
        guard let buffer = pixelBuffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, []); defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        // 创建 1200x800 的画布
        let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: 1200, height: 800, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
        
        context.clear(CGRect(x: 0, y: 0, width: 1200, height: 800))
        context.interpolationQuality = .high
        context.setShouldAntialias(true)
        context.setAllowsAntialiasing(true)
        
        // --- 核心：通过缩放实现 2x 无损渲染，无需修改布局坐标 ---
        context.scaleBy(x: 2, y: 2)
        
        let centerX = 300.0; let centerY = 200.0 + layout.cY
        drawTelemetryCardStatic(context: context, state: state, currentTime: currentTime, x: centerX - layout.cW/2, y: centerY + 100, width: layout.cW, logo: logo, speedIcon: speedIcon, clockIcon: clockIcon)
        drawWaveSmoothSliding(context: context, history: history, currentTime: currentTime, x: centerX - layout.cW/2, y: centerY - 140, width: layout.cW, height: 200, eventIcons: eventIcons, events: events, gRange: gRange, showEvents: showEvents, mode: mode)
        drawLegendStatic(context: context, x: centerX - layout.cW/2, y: centerY - 160, width: layout.cW)
        
        return buffer
    }
    
    nonisolated private static func drawLegendStatic(context: CGContext, x: CGFloat, y: CGFloat, width: CGFloat) {
        let fontLegend = CTFontCreateWithName("Helvetica-Bold" as CFString, 8, nil)
        let colorX = NSColor(red: 0.2, green: 0.9, blue: 0.4, alpha: 1.0)
        let colorY = NSColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0)
        
        let startX = x + (width - 120) / 2
        
        context.setFillColor(colorX.cgColor); context.fillEllipse(in: CGRect(x: startX, y: y, width: 4, height: 4))
        drawTextStatic(context: context, text: "X-ACCEL", font: fontLegend, color: .gray, x: startX + 8, y: y - 2)
        
        context.setFillColor(colorY.cgColor); context.fillEllipse(in: CGRect(x: startX + 60, y: y, width: 4, height: 4))
        drawTextStatic(context: context, text: "Y-ACCEL", font: fontLegend, color: .gray, x: startX + 68, y: y - 2)
    }
    
    nonisolated private static func drawTelemetryCardStatic(context: CGContext, state: InterpolatedState?, currentTime: Double, x: CGFloat, y: CGFloat, width: CGFloat, logo: CGImage?, speedIcon: CGImage?, clockIcon: CGImage?) {
        let height: CGFloat = 60; let rect = CGRect(x: x, y: y, width: width, height: height)
        context.saveGState(); context.setFillColor(gray: 1.0, alpha: 0.08)
        context.addPath(CGPath(roundedRect: rect, cornerWidth: 12, cornerHeight: 12, transform: nil)); context.fillPath(); context.restoreGState()
        
        if let logo = logo {
            let boxSize: CGFloat = 30; let boxRect = CGRect(x: x + 12, y: y + 15, width: boxSize, height: boxSize)
            context.saveGState(); context.setFillColor(gray: 1.0, alpha: 0.1); context.addPath(CGPath(roundedRect: boxRect, cornerWidth: 8, cornerHeight: 8, transform: nil)); context.fillPath(); context.restoreGState()
            let logoSize: CGFloat = 18; let logoRect = CGRect(x: x + 12 + (boxSize - logoSize)/2, y: y + 15 + (boxSize - logoSize)/2, width: logoSize, height: logoSize)
            context.saveGState(); context.clip(to: logoRect, mask: logo); context.setFillColor(gray: 1.0, alpha: 1.0); context.fill(logoRect); context.restoreGState()
        }
        
        let textOffset: CGFloat = logo != nil ? 52 : 20; let baselineY = y + 22
        let fontMain = CTFontCreateWithName("Helvetica" as CFString, 18, nil); let fontSmall = CTFontCreateWithName("Helvetica-Bold" as CFString, 9, nil); let fontLabel = CTFontCreateWithName("Helvetica" as CFString, 9, nil)
        
        if let si = speedIcon {
            let sRect = CGRect(x: x + textOffset, y: baselineY - 2, width: 22, height: 22)
            context.saveGState(); context.clip(to: sRect, mask: si); context.setFillColor(NSColor.systemBlue.cgColor); context.fill(sRect); context.restoreGState()
        }
        drawTextStatic(context: context, text: String(format: " %.1f", state?.speedKmh ?? 0), font: fontMain, color: .systemBlue, x: x + textOffset + 20, y: baselineY)
        drawTextStatic(context: context, text: " KM/H", font: fontSmall, color: .gray, x: x + textOffset + 65, y: baselineY)
        
        let timeXOffset = textOffset + 140
        if let ci = clockIcon {
            let cRect = CGRect(x: x + timeXOffset, y: baselineY, width: 16, height: 16)
            context.saveGState(); context.clip(to: cRect, mask: ci); context.setFillColor(NSColor.gray.cgColor); context.fill(cRect); context.restoreGState()
        }
        let fullTs = formatTimestampStatic(currentTime)
        let attrTs = NSMutableAttributedString(string: String(fullTs.prefix(9)), attributes: [.font: fontMain, .foregroundColor: NSColor.white])
        attrTs.append(NSAttributedString(string: String(fullTs.suffix(4)), attributes: [.font: fontMain, .foregroundColor: NSColor.gray]))
        drawAttrTextStatic(context: context, attr: attrTs, x: x + timeXOffset + 20, y: baselineY)
        
        drawAccelStatic(context: context, label: "X轴加速度", value: state?.gForceLongitudinal ?? 0, color: NSColor(red: 0.2, green: 0.9, blue: 0.4, alpha: 1), x: x + width - 150, y: y + 15, fontLabel: fontLabel, fontValue: fontMain)
        drawAccelStatic(context: context, label: "Y轴加速度", value: state?.gForceLateral ?? 0, color: NSColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1), x: x + width - 70, y: y + 15, fontLabel: fontLabel, fontValue: fontMain)
    }
    
    nonisolated private static func drawTextStatic(context: CGContext, text: String, font: CTFont, color: NSColor, x: CGFloat, y: CGFloat) {
        let attr = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
        drawAttrTextStatic(context: context, attr: attr, x: x, y: y)
    }

    nonisolated private static func drawAttrTextStatic(context: CGContext, attr: NSAttributedString, x: CGFloat, y: CGFloat) {
        context.saveGState(); context.textMatrix = .identity; context.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(CTLineCreateWithAttributedString(attr), context); context.restoreGState()
    }

    nonisolated private static func drawAccelStatic(context: CGContext, label: String, value: Double, color: NSColor, x: CGFloat, y: CGFloat, fontLabel: CTFont, fontValue: CTFont) {
        drawTextStatic(context: context, text: label, font: fontLabel, color: color.withAlphaComponent(0.8), x: x, y: y + 20)
        drawTextStatic(context: context, text: String(format: "%.2f G", value), font: fontValue, color: color, x: x, y: y)
    }
    
    nonisolated private static func formatTimestampStatic(_ ts: Double) -> String {
        let date = Date(timeIntervalSince1970: ts); let formatter = DateFormatter(); formatter.dateFormat = "HH:mm:ss.SSS"; return formatter.string(from: date)
    }
    
    nonisolated private static func drawWaveSmoothSliding(context: CGContext, history: [InterpolatedState], currentTime: Double, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, eventIcons: [String: SendableImage], events: [RecordedEvent], gRange: (min: Double, max: Double), showEvents: Bool, mode: DataInterpolator.FrequencyMode) {
        context.saveGState(); context.translateBy(x: x, y: y)
        // 自适应视窗大小：高频 20秒，低频 100秒
        let window = mode == .highFreq ? 20.0 : 100.0
        let headX = width * 0.8; let pps = width / CGFloat(window)
        
        let minG = gRange.min; let maxG = gRange.max
        let mapG = { (g: Double) -> CGFloat in
            let normalized = (g - minG) / (maxG - minG)
            return CGFloat(max(0, min(1, normalized))) * height
        }
        
        // ... (绘制刻度逻辑保持不变)
        
        var ptsX: [CGPoint] = []; var ptsY: [CGPoint] = []
        // 自适应采样频率：高频模式下提升至 30Hz (0.033s)
        let stepSeconds = mode == .highFreq ? 0.033 : 0.1
        let pointsCount = Int(window / stepSeconds)
        
        for i in 0...pointsCount {
            let ts = currentTime - Double(i) * stepSeconds
            let px = headX - CGFloat(currentTime - ts) * pps
            if px < -20 { break }
            let frameOffset = Int(Double(i) * stepSeconds * 30.0)
            let historyIdx = history.count - 1 - frameOffset
            if historyIdx >= 0 {
                let s = history[historyIdx]
                ptsX.append(CGPoint(x: px, y: mapG(s.gForceLongitudinal)))
                ptsY.append(CGPoint(x: px, y: mapG(s.gForceLateral)))
            }
        }
        
        func strokeSmooth(pts: [CGPoint], color: CGColor, width: CGFloat, glow: Bool) {
            guard pts.count > 1 else { return }
            let path = CGMutablePath(); path.move(to: pts[0])
            
            // 采用三阶平滑绘制，彻底消除锐利转角
            for i in 0..<pts.count - 1 {
                let p1 = pts[i]
                let p2 = pts[i+1]
                let p0 = i > 0 ? pts[i-1] : p1
                let p3 = i < pts.count - 2 ? pts[i+2] : p2
                
                // 已修正 X/Y 混淆 Bug
                let cp1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
                let cp2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
                
                path.addCurve(to: p2, control1: cp1, control2: cp2)
            }
            
            context.saveGState()
            if glow { context.setShadow(offset: .zero, blur: 8, color: color) }
            context.setStrokeColor(color); context.setLineWidth(width); context.setLineCap(.round); context.setLineJoin(.round)
            context.addPath(path); context.strokePath(); context.restoreGState()
            if let latest = pts.first {
                context.saveGState()
                if glow { context.setShadow(offset: .zero, blur: 10, color: color) }
                context.setFillColor(NSColor.white.cgColor); context.fillEllipse(in: CGRect(x: latest.x - 4, y: latest.y - 4, width: 8, height: 8))
                context.setFillColor(color); context.fillEllipse(in: CGRect(x: latest.x - 3, y: latest.y - 3, width: 6, height: 6)); context.restoreGState()
            }
        }
        
        strokeSmooth(pts: ptsY, color: NSColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 0.3).cgColor, width: 2.5, glow: false)
        strokeSmooth(pts: ptsX, color: NSColor(red: 0.2, green: 0.9, blue: 0.4, alpha: 1).cgColor, width: 2.2, glow: true)
        
        if showEvents {
            for event in events {
                guard let ts = event.timestamp else { continue }
                let px = headX - CGFloat(currentTime - ts) * pps
                if px > 0 && px <= width, let iconName = event.eventType.iconName, let icon = eventIcons[iconName]?.image {
                    context.saveGState(); context.setShadow(offset: .zero, blur: 0, color: nil)
                    context.setStrokeColor(NSColor.gray.withAlphaComponent(0.3).cgColor); context.setLineWidth(1.0)
                    let dash: [CGFloat] = [4, 4]; context.setLineDash(phase: 0, lengths: dash)
                    context.move(to: CGPoint(x: px, y: 0)); context.addLine(to: CGPoint(x: px, y: height)); context.strokePath()
                    context.setLineDash(phase: 0, lengths: [])
                    let iconSize: CGFloat = 22; let bgRect = CGRect(x: px - iconSize/2, y: 25, width: iconSize, height: iconSize)
                    context.setFillColor(event.eventType.nsColor.cgColor); context.fillEllipse(in: bgRect)
                    context.setStrokeColor(NSColor.white.cgColor); context.setLineWidth(1.5); context.strokeEllipse(in: bgRect)
                    let drawSize: CGFloat = 12; let drawRect = CGRect(x: px - drawSize/2, y: 25 + (iconSize - drawSize)/2, width: drawSize, height: drawSize)
                    context.clip(to: drawRect, mask: icon); context.setFillColor(NSColor.white.cgColor); context.fill(drawRect); context.restoreGState()
                }
            }
        }
        context.restoreGState()
    }
}
