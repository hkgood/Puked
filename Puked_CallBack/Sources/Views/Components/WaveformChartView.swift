import SwiftUI

struct WaveformChartView: View {
    let trip: TripData?
    let interpolator: DataInterpolator?
    let currentTime: Double
    let showEvents: Bool
    
    private var windowSize: Double {
        interpolator?.mode == .highFreq ? 20.0 : 100.0
    }
    
    var body: some View {
        Canvas(
            renderer: { context, size in
                guard let interpolator = interpolator, trip != nil else { return }
                
                // 🎯 计算整个行程的最大G值（绝对值），向上取整，构建对称范围
                let globalRange = interpolator.calculateGForceRange()
                let maxAbsG = max(abs(globalRange.min), abs(globalRange.max))
                let ceiledMaxG = ceil(maxAbsG) // 向上取整
                
                // 以 0 为中心，对称范围
                let minG = -ceiledMaxG
                let maxG = ceiledMaxG
                
                let headX = size.width * 0.8
                let pixelsPerSecond = size.width / CGFloat(windowSize)
                
                // 30Hz 高精绘图步长
                let stepSeconds = interpolator.mode == .highFreq ? 0.033 : 0.1
                let pointsCount = Int(windowSize / stepSeconds)
                
                var pointsX: [CGPoint] = []
                var pointsY: [CGPoint] = []
                
                for i in 0...pointsCount {
                    let ts = currentTime - Double(i) * stepSeconds
                    let x = headX - CGFloat(currentTime - ts) * pixelsPerSecond
                    if x < -20 { break }
                    
                    if let state = interpolator.state(at: ts) {
                        pointsX.append(CGPoint(x: x, y: mapGValue(state.gForceLongitudinal, size: size, minG: minG, maxG: maxG)))
                        pointsY.append(CGPoint(x: x, y: mapGValue(state.gForceLateral, size: size, minG: minG, maxG: maxG)))
                    }
                }
                
                drawScales(context: context, size: size, minG: minG, maxG: maxG)
                drawAreaGradient(context: context, points: pointsX, size: size, color: Color(red: 0.2, green: 0.9, blue: 0.4).opacity(0.1), minG: minG, maxG: maxG)
                
                // 采用三阶平滑绘制
                context.stroke(createCubicPath(from: pointsY), with: .color(Color(red: 1.0, green: 0.3, blue: 0.3).opacity(0.3)), lineWidth: 2.5)
                
                context.addFilter(.shadow(color: .green.opacity(0.4), radius: 6, x: 0, y: 0))
                context.stroke(createCubicPath(from: pointsX), with: .color(Color(red: 0.2, green: 0.9, blue: 0.4)), lineWidth: 2.2)
                
                context.addFilter(.shadow(color: .clear, radius: 0))
                
                if showEvents {
                    drawEventIcons(context: context, size: size, headX: headX, pps: pixelsPerSecond)
                }
                
                if let latestX = pointsX.first, let latestY = pointsY.first {
                    context.addFilter(.shadow(color: .green, radius: 8, x: 0, y: 0))
                    context.fill(Path(ellipseIn: CGRect(x: latestX.x - 4, y: latestX.y - 4, width: 8, height: 8)), with: .color(.white))
                    context.fill(Path(ellipseIn: CGRect(x: latestX.x - 3, y: latestX.y - 3, width: 6, height: 6)), with: .color(Color(red: 0.2, green: 0.9, blue: 0.4)))
                    context.addFilter(.shadow(color: .clear, radius: 0))
                    context.fill(Path(ellipseIn: CGRect(x: latestY.x - 3, y: latestY.y - 3, width: 6, height: 6)), with: .color(Color(red: 1.0, green: 0.3, blue: 0.3)))
                }
            },
            symbols: {
                if let events = trip?.events {
                    ForEach(events) { event in
                        if let iconName = event.eventType.iconName {
                            let stableID = "\(event.type)_\(event.timestamp ?? 0)"
                            Image(systemName: iconName).resizable().aspectRatio(contentMode: .fit).foregroundStyle(.white).frame(width: 12, height: 12).tag(stableID)
                        }
                    }
                }
            }
        )
        .frame(height: 200)
    }
    
    // --- 核心：Catmull-Rom 三次样条路径生成器 ---
    private func createCubicPath(from points: [CGPoint]) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }
        
        path.move(to: points[0])
        
        for i in 0..<points.count - 1 {
            let p1 = points[i]
            let p2 = points[i+1]
            
            // 计算辅助点以模拟三阶连续
            let p0 = i > 0 ? points[i-1] : p1
            let p3 = i < points.count - 2 ? points[i+2] : p2
            
            // Catmull-Rom to Bezier 转换公式 (已修正 X/Y 混淆)
            let cp1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let cp2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            
            path.addCurve(to: p2, control1: cp1, control2: cp2)
        }
        return path
    }
    
    private func drawScales(context: GraphicsContext, size: CGSize, minG: Double, maxG: Double) {
        let steps = 4
        for i in 0...steps {
            let g = minG + (maxG - minG) * Double(i) / Double(steps)
            let y = mapGValue(g, size: size, minG: minG, maxG: maxG)
            var line = Path(); line.move(to: CGPoint(x: 0, y: y)); line.addLine(to: CGPoint(x: size.width - 40, y: y))
            context.stroke(line, with: .color(.white.opacity(0.05)), lineWidth: 1)
            let label = String(format: "%.1fG", g)
            context.draw(context.resolve(Text(label).font(.system(size: 8, weight: .light)).foregroundColor(.white.opacity(0.4))), at: CGPoint(x: size.width - 20, y: y))
        }
    }
    
    private func drawEventIcons(context: GraphicsContext, size: CGSize, headX: CGFloat, pps: CGFloat) {
        if let events = trip?.events {
            for event in events {
                guard let ts = event.timestamp else { continue }
                let x = headX - CGFloat(currentTime - ts) * pps
                if x > -20 && x <= size.width + 20 {
                    let stableID = "\(event.type)_\(event.timestamp ?? 0)"
                    var line = Path(); line.move(to: CGPoint(x: x, y: 0)); line.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(line, with: .color(.gray.opacity(0.3)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    let iconSize: CGFloat = 22; let rect = CGRect(x: x - iconSize/2, y: 25, width: iconSize, height: iconSize)
                    context.fill(Path(ellipseIn: rect), with: .color(event.eventType.eventColor))
                    context.stroke(Path(ellipseIn: rect), with: .color(.white), lineWidth: 1.5)
                    if let resolved = context.resolveSymbol(id: stableID) { context.draw(resolved, at: CGPoint(x: x, y: 25 + iconSize/2)) }
                }
            }
        }
    }
    
    private func drawAreaGradient(context: GraphicsContext, points: [CGPoint], size: CGSize, color: Color, minG: Double, maxG: Double) {
        guard points.count > 1 else { return }
        var path = createCubicPath(from: points)
        let zeroY = mapGValue(0, size: size, minG: minG, maxG: maxG)
        if let last = points.last {
            path.addLine(to: CGPoint(x: last.x, y: zeroY))
            path.addLine(to: CGPoint(x: points[0].x, y: zeroY))
            path.closeSubpath()
            context.fill(path, with: .linearGradient(Gradient(colors: [color, .clear]), startPoint: CGPoint(x: 0, y: zeroY - 20), endPoint: CGPoint(x: 0, y: zeroY)))
        }
    }
    
    private func mapGValue(_ g: Double, size: CGSize, minG: Double, maxG: Double) -> CGFloat {
        let range = maxG - minG; let normalizedG = (g - minG) / range
        return size.height - (CGFloat(max(0, min(1, normalizedG))) * size.height)
    }
}
