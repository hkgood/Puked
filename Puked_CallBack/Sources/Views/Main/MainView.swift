import SwiftUI
import UniformTypeIdentifiers

/// JSON 导入错误类型
enum ImportError: LocalizedError {
    case permissionDenied
    case fileTooLarge(size: Int)
    case emptyTrajectory
    case insufficientData
    case invalidTimestamps
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "无法访问文件，请确保已授予文件访问权限。"
        case .fileTooLarge(let size):
            let sizeMB = Double(size) / (1024 * 1024)
            return "文件过大（\(String(format: "%.1f", sizeMB)) MB），最大支持 50 MB。\n\n建议导出较短的行程片段。"
        case .emptyTrajectory:
            return "数据文件中没有轨迹点，无法导入。\n\n请确保文件包含完整的行程数据。"
        case .insufficientData:
            return "轨迹数据不足，至少需要 2 个以上的轨迹点。"
        case .invalidTimestamps:
            return "数据时间戳顺序异常，可能文件已损坏。\n\n请尝试重新导出数据。"
        }
    }
}

struct MainView: View {
    @StateObject private var exportEngine = VideoExportEngine()
    @State private var tripData: TripData?
    @State private var previewTime: Double = 0
    @State private var showFileImporter = false
    
    @State private var interpolator: DataInterpolator?
    @State private var isPlaying = false
    @State private var playbackTimer: Timer?
    @State private var playbackSpeed: Double = 1.0
    
    // 错误处理和加载状态
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var errorTitle = "导入失败"
    @State private var isLoadingFile = false
    
    // 用于精确回放的基准变量
    @State private var playbackStartWallTime: Date?
    @State private var playbackStartPreviewTime: Double = 0
    
    // 布局参数
    @State private var contentX: CGFloat = 0
    @State private var chartWidth: CGFloat = 560
    @State private var contentY: CGFloat = 0
    @State private var showSettings = false
    @State private var showEvents = true
    @State private var exportQuality: ExportQuality = .high
    
    // 片段导出
    @State private var showSegmentPanel = false
    @State private var segmentStartStr: String = "00:00"
    @State private var segmentEndStr: String = "00:30"
    
    var body: some View {
        VStack(spacing: 0) {
            if let trip = tripData {
                renderPlayer(trip)
            } else {
                renderDropZone()
            }
        }
        .frame(width: 600, height: 540) 
        .background(VisualEffectView(material: .underWindowBackground).ignoresSafeArea())
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first { 
                Task { await self.readJson(from: url) }
            }
        }
        .alert(errorTitle, isPresented: $showErrorAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .overlay {
            if isLoadingFile {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .progressViewStyle(.circular)
                        
                        Text("正在加载数据...")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(30)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                }
            }
        }
    }
    
    @ViewBuilder
    func renderPlayer(_ trip: TripData) -> some View {
        let startTime = trip.trajectory.first?.ts ?? 0
        let endTime = trip.trajectory.last?.ts ?? 0
        
        VStack(spacing: 0) {
            // 1. 顶部栏
            HStack(spacing: 15) {
                if let logo = trip.metadata.brandLogoName {
                    Image(logo)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                        .padding(6)
                        .background(Color.primary.opacity(0.1))
                        .cornerRadius(8)
                        .foregroundColor(.primary)
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text(trip.metadata.carModel)
                        .font(.system(size: 16, weight: .bold))
                    Text(formatDateSimple(trip.metadata.startTime))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                Button(action: { withAnimation { showSettings.toggle() } }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 15, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .popover(isPresented: $showSettings, arrowEdge: .bottom) {
                    renderSettingsSidebar()
                }
                
                Button(action: { stopPlayback(); tripData = nil }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                }.buttonStyle(.plain).foregroundColor(.secondary)
            }
            .padding(.horizontal, 15)
            .frame(height: 50)
            
            // 2. 视频预览区
            ZStack {
                if exportEngine.isExporting {
                    Color.black.overlay(
                        VStack(spacing: 15) {
                            ProgressView(value: exportEngine.progress, total: 1.0)
                                .progressViewStyle(.linear)
                                .frame(width: 200)
                                .tint(.blue)
                            
                            VStack(spacing: 6) {
                                Text("正在编码透明视频...")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                
                                HStack(spacing: 12) {
                                    Text("\(Int(exportEngine.progress * 100))%")
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    
                                    if !exportEngine.estimatedTimeRemaining.isEmpty {
                                        Text("预计剩余: \(exportEngine.estimatedTimeRemaining)")
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                }
                                .foregroundColor(.secondary)
                            }
                        }
                    )
                } else {
                    let currentState = interpolator?.state(at: previewTime)
                    ExportFrameView(
                        state: currentState,
                        tripData: trip,
                        interpolator: interpolator,
                        currentTime: previewTime,
                        layout: LayoutConfig(speedX: contentX, gX: 0, cW: chartWidth, cY: contentY),
                        showEvents: showEvents
                    )
                    .background(Color.black)
                }
                
            }
            .frame(width: 600, height: 400)
            
            // 3. 底部控制区
            VStack(spacing: 12) {
                Slider(value: $previewTime, in: startTime...endTime, onEditingChanged: { d in if d { stopPlayback() } })
                    .tint(.blue)
                    .controlSize(.small)
                    .padding(.horizontal, 15)
                    .padding(.top, 12)
                
                HStack(spacing: 20) {
                    Button(action: togglePlayback) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 38))
                            .foregroundColor(.blue)
                    }.buttonStyle(.plain)
                    
                    Picker("", selection: $playbackSpeed) {
                        Text("1x").tag(1.0); Text("2x").tag(2.0); Text("5x").tag(5.0)
                    }.pickerStyle(.segmented).frame(width: 110).controlSize(.small)
                    
                    Spacer()
                    
                    Text("\(formatDuration(previewTime - startTime)) / \(formatDuration(endTime - startTime))")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Button(action: { 
                            segmentStartStr = formatDuration(previewTime - startTime)
                            segmentEndStr = formatDuration(min(previewTime - startTime + 30, endTime - startTime))
                            showSegmentPanel.toggle() 
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "scissors")
                                Text("片段")
                            }
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 75, height: 36)
                            .background(Color.white.opacity(0.1))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                        }.buttonStyle(.plain)
                        .popover(isPresented: $showSegmentPanel, arrowEdge: .top) {
                            renderSegmentInput(startTime: startTime, endTime: endTime, trip: trip)
                        }

                        Button(action: { Task { await startExport(trip) } }) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up.fill")
                                Text("导出")
                            }
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 85, height: 36)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 15)
                .padding(.bottom, 12)
            }
            .frame(height: 90)
        }
    }
    
    private func formatDateSimple(_ isoString: String) -> String {
        let parts = isoString.split(separator: "T")
        return parts.count > 1 ? "\(parts[0]) \(String(parts[1].prefix(8)))" : isoString
    }
    
    @ViewBuilder
    private func renderSettingsSidebar() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题区（系统 popover 风格）
            Text("图表设置")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)
            
            Divider()
                .background(Color.primary.opacity(0.12))
                .padding(.horizontal, 12)
            
            // 第一组：显示负体验事件
            HStack {
                Text("显示负体验事件")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.primary)
                Spacer()
                Toggle("", isOn: $showEvents)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            
            Divider()
                .background(Color.primary.opacity(0.12))
                .padding(.horizontal, 12)
            
            // 第二组：导出视频质量
            VStack(alignment: .leading, spacing: 8) {
                Text("导出视频质量")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                Picker("", selection: $exportQuality) {
                    ForEach(ExportQuality.allCases) { quality in
                        Text(quality.rawValue).tag(quality)
                    }
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 14)
        }
        .frame(width: 220)
        .background(.regularMaterial)
    }
    
    @ViewBuilder
    private func renderSegmentInput(startTime: Double, endTime: Double, trip: TripData) -> some View {
        VStack(spacing: 18) {
            Text("导出片段设置")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                timeInputRow(label: "开始时间", value: $segmentStartStr)
                timeInputRow(label: "结束时间", value: $segmentEndStr)
            }
            
            Text("格式说明：MM:SS (例如 01:20)")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            
            Button(action: {
                showSegmentPanel = false
                Task {
                    let s = parseDuration(segmentStartStr)
                    let e = parseDuration(segmentEndStr)
                    let realRange = (startTime + s)...(startTime + e)
                    await startExport(trip, range: realRange)
                }
            }) {
                Text("开始导出片段")
                    .font(.system(size: 13, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }.buttonStyle(.plain)
        }
        .padding(20)
        .frame(width: 240)
        .background(.ultraThinMaterial)
    }
    
    private func timeInputRow(label: String, value: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.primary)
            Spacer()
            TextField("00:00", text: value)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .monospaced))
                .multilineTextAlignment(.trailing)
                .frame(width: 60)
                .padding(6)
                .background(Color.primary.opacity(0.05))
                .cornerRadius(6)
        }
    }
    
    private func parseDuration(_ str: String) -> Double {
        let parts = str.split(separator: ":").map { String($0) }
        if parts.count == 2, let m = Double(parts[0]), let s = Double(parts[1]) {
            return m * 60 + s
        }
        return Double(str) ?? 0
    }
    
    private let pukedAppStoreURL = URL(string: "https://apps.apple.com/us/app/puked-by-rocky/id6757263264")!
    private let pukedWebsiteURL = URL(string: "https://puked.osglab.com")!
    
    @ViewBuilder
    func renderDropZone() -> some View {
        VStack(spacing: 16) {
            Button(action: { showFileImporter = true }) {
                VStack(spacing: 15) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 40)).foregroundStyle(.blue)
                    Text("打开 Puked 行程数据").font(.system(size: 15, weight: .medium))
                }
            }
            .buttonStyle(.plain)
            
            VStack(spacing: 8) {
                Text("本 App 仅支持导入 Puked App 生成的数据并生成视频，点击下方链接")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 24) {
                    Link("下载 iOS Puked App", destination: pukedAppStoreURL)
                        .font(.system(size: 12, weight: .medium))
                    Link("访问官网", destination: pukedWebsiteURL)
                        .font(.system(size: 12, weight: .medium))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    func togglePlayback() {
        if isPlaying { stopPlayback() }
        else {
            isPlaying = true
            playbackStartWallTime = Date()
            playbackStartPreviewTime = previewTime
            playbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { _ in
                DispatchQueue.main.async {
                    guard let trip = self.tripData, let startTime = self.playbackStartWallTime else { return }
                    let endTime = trip.trajectory.last?.ts ?? 0
                    let elapsedWallTime = Date().timeIntervalSince(startTime)
                    let newTime = self.playbackStartPreviewTime + elapsedWallTime * self.playbackSpeed
                    if newTime < endTime { self.previewTime = newTime }
                    else { self.previewTime = endTime; self.stopPlayback() }
                }
            }
        }
    }
    
    func stopPlayback() { isPlaying = false; playbackTimer?.invalidate(); playbackTimer = nil; playbackStartWallTime = nil }
    
    func formatDuration(_ seconds: Double) -> String {
        let s = max(0, seconds)
        let mins = Int(s) / 60; let secs = Int(s) % 60; return String(format: "%02d:%02d", mins, secs)
    }
    
    private func readJson(from url: URL) async {
        // 1. 显示加载指示器
        await MainActor.run {
            isLoadingFile = true
        }
        
        // 2. 在后台线程读取和解析文件
        do {
            // 安全访问 App Sandbox 文件
            guard url.startAccessingSecurityScopedResource() else {
                throw ImportError.permissionDenied
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            // 读取文件数据（在后台线程）
            let data = try Data(contentsOf: url)
            
            // 验证文件大小（最大 50MB）
            let maxSize = 50 * 1024 * 1024
            guard data.count <= maxSize else {
                throw ImportError.fileTooLarge(size: data.count)
            }
            
            // 解析 JSON
            let decoder = JSONDecoder()
            let trip = try decoder.decode(TripData.self, from: data)
            
            // 验证数据完整性并自动修复时间戳顺序
            let validatedTrip = try validateTripData(trip)
            
            // 3. 在主线程更新 UI
            await MainActor.run {
                self.tripData = validatedTrip
                self.interpolator = DataInterpolator(points: validatedTrip.trajectory)
                self.previewTime = validatedTrip.trajectory.first?.ts ?? 0
                self.isLoadingFile = false
            }
            
        } catch let error as ImportError {
            await MainActor.run {
                self.isLoadingFile = false
                self.errorTitle = "导入失败"
                self.errorMessage = error.localizedDescription
                self.showErrorAlert = true
            }
        } catch let error as DecodingError {
            await MainActor.run {
                self.isLoadingFile = false
                self.errorTitle = "无法识别该文件"
                self.errorMessage = formatDecodingError(error)
                self.showErrorAlert = true
            }
        } catch {
            await MainActor.run {
                self.isLoadingFile = false
                self.errorTitle = "导入失败"
                self.errorMessage = "无法读取文件：\(error.localizedDescription)"
                self.showErrorAlert = true
            }
        }
    }
    
    /// 验证行程数据的完整性
    private func validateTripData(_ trip: TripData) throws -> TripData {
        // 检查轨迹点数量
        guard !trip.trajectory.isEmpty else {
            throw ImportError.emptyTrajectory
        }
        
        // 检查轨迹点数量是否合理（至少 2 个点才能形成行程）
        guard trip.trajectory.count >= 2 else {
            throw ImportError.insufficientData
        }
        
        // 🔧 核心修复：自动修复时间戳顺序，而不是报错拒绝导入
        // 原因：Android 端在高频传感器数据记录时，由于批量写入的异步特性，
        // 可能导致数据库中的轨迹点顺序与实际时间戳顺序不完全一致。
        let sortedTrajectory = trip.trajectory.sorted { $0.ts < $1.ts }
        
        // 检查是否进行了排序修复
        let wasOutOfOrder = sortedTrajectory != trip.trajectory
        if wasOutOfOrder {
            print("⚠️ [Import] Detected out-of-order timestamps, auto-sorting \(trip.trajectory.count) points")
            
            // 返回修复后的数据
            return TripData(
                version: trip.version,
                tripId: trip.tripId,
                metadata: trip.metadata,
                trajectory: sortedTrajectory,
                events: trip.events
            )
        }
        
        print("✅ [Import] Timestamps validation passed")
        return trip
    }
    
    /// 格式化 JSON 解析错误消息（非 Puked 格式时给出友好引导）
    private func formatDecodingError(_ error: DecodingError) -> String {
        let guide = """
        本工具仅支持 Puked App 导出的行程数据文件。
        
        请按以下步骤获取正确文件：
        1. 在手机打开 Puked App
        2. 进入「行程详情」→ 点击「分享」或「导出」
        3. 选择导出的 Trip_xxxx.json 文件，用本应用重新打开
        """
        
        switch error {
        case .keyNotFound(_, _):
            return guide
        case .typeMismatch(_, _):
            return guide
        case .valueNotFound(_, _):
            return guide
        case .dataCorrupted(_):
            return "该文件可能已损坏或不是 Puked 导出的数据。\n\n请从 Puked App 重新导出行程（分享 → 导出数据），或选择其他 Trip_xxx.json 文件重试。"
        @unknown default:
            return guide
        }
    }
    
    private func startExport(_ trip: TripData, range: ClosedRange<Double>? = nil) async {
        stopPlayback()
        let savePanel = NSSavePanel(); savePanel.allowedContentTypes = [.quickTimeMovie]; savePanel.nameFieldStringValue = range == nil ? "Puked_Full.mov" : "Puked_Segment.mov"
        if await savePanel.begin() == .OK, let url = savePanel.url {
            let config = LayoutConfig(speedX: contentX, gX: 0, cW: chartWidth, cY: contentY)
            _ = await exportEngine.export(trip: trip, outputURL: url, layout: config, showEvents: showEvents, quality: exportQuality, range: range)
        }
    }
}

struct ExportFrameView: View {
    let state: InterpolatedState?; let tripData: TripData?; let interpolator: DataInterpolator?; let currentTime: Double; let layout: LayoutConfig; let showEvents: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 20) {
                HStack(spacing: 25) {
                    HStack(spacing: 8) {
                        Image(systemName: "speedometer").font(.system(size: 22)).foregroundColor(.blue)
                        HStack(alignment: .lastTextBaseline, spacing: 3) {
                            Text(String(format: "%.1f", state?.speedKmh ?? 0))
                                .font(.system(size: 22, weight: .regular, design: .monospaced))
                            Text("KM/H").font(.system(size: 9, weight: .bold)).foregroundColor(.gray)
                        }
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "clock").font(.system(size: 16)).foregroundColor(.gray)
                        HStack(alignment: .lastTextBaseline, spacing: 0) {
                            Text(formatMainTime(currentTime)).font(.system(size: 16, weight: .regular, design: .monospaced))
                            Text(formatSubTime(currentTime)).font(.system(size: 16, weight: .thin, design: .monospaced)).foregroundColor(.gray)
                        }
                    }
                }
                Spacer()
                HStack(spacing: 25) {
                    accelItem(label: "X轴加速度", value: state?.gForceLongitudinal ?? 0, color: Color(red: 0.2, green: 0.9, blue: 0.4))
                    accelItem(label: "Y轴加速度", value: state?.gForceLateral ?? 0, color: Color(red: 1.0, green: 0.3, blue: 0.3))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Color.white.opacity(0.08))
            .cornerRadius(12)
            .frame(width: layout.cW)
            .foregroundColor(.white)
            
            WaveformChartView(trip: tripData, interpolator: interpolator, currentTime: currentTime, showEvents: showEvents)
                .frame(width: layout.cW)
            
            HStack(spacing: 20) {
                HStack(spacing: 4) { Circle().fill(Color(red: 0.2, green: 0.9, blue: 0.4)).frame(width: 4); Text("X-ACCEL").font(.system(size: 8, weight: .bold)) }
                HStack(spacing: 4) { Circle().fill(Color(red: 1.0, green: 0.3, blue: 0.3)).frame(width: 4); Text("Y-ACCEL").font(.system(size: 8, weight: .bold)) }
            }.foregroundColor(.gray).padding(.bottom, 10)
        }
        .offset(x: layout.speedX, y: layout.cY)
        .frame(width: 600, height: 400)
    }
    
    private func accelItem(label: String, value: Double, color: Color) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(label).font(.system(size: 9, weight: .medium)).foregroundColor(color.opacity(0.8))
            Text(String(format: "%.2f G", value)).font(.system(size: 16, weight: .regular, design: .monospaced)).foregroundColor(color)
        }
    }
    
    private func formatMainTime(_ ts: Double) -> String {
        let d = Date(timeIntervalSince1970: ts); let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f.string(from: d)
    }
    private func formatSubTime(_ ts: Double) -> String {
        let ms = Int((ts.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: ".%03d", ms)
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView(); view.material = material; view.state = .active; return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
