import SwiftUI

struct SpeedometerView: View {
    let speedKmh: Double
    
    var body: some View {
        VStack(spacing: -10) {
            ZStack {
                // 背景环
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 8)
                    .frame(width: 140, height: 140)
                
                // 进度环 (蓝色发光)
                Circle()
                    .trim(from: 0, to: CGFloat(min(speedKmh / 200.0, 1.0)))
                    .stroke(
                        LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: .blue.opacity(0.5), radius: 10)
                
                // 刻度线
                ForEach(0..<20) { i in
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 2, height: i % 5 == 0 ? 10 : 5)
                        .offset(y: -60)
                        .rotationEffect(.degrees(Double(i) * 18))
                }
                
                // 速度值
                VStack(spacing: 0) {
                    Text("\(Int(speedKmh))")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("KM/H")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }
}

// 新组件：G-G 圆盘 (重心感应器)
struct GForceCircleView: View {
    let lonG: Double
    let latG: Double
    
    var body: some View {
        ZStack {
            // 背景圆盘
            Circle()
                .fill(.white.opacity(0.05))
                .frame(width: 100, height: 100)
                .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
            
            // 十字准星
            Rectangle().fill(.white.opacity(0.1)).frame(width: 100, height: 1)
            Rectangle().fill(.white.opacity(0.1)).frame(width: 1, height: 100)
            
            // 当前重心点 (发光红点)
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
                .shadow(color: .red, radius: 5)
                // 映射坐标 (5G 对应 50px 偏移，即圆盘边缘)
                .offset(x: CGFloat(latG * 10), y: CGFloat(-lonG * 10))
        }
    }
}
