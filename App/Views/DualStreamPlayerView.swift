import SwiftUI
import AVKit
import AVFoundation
import MediaPlayer

// MARK: - 视频播放器视图
struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> UIView {
        let view = PlayerUIView(player: player)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // 更新逻辑（如果需要）
    }
}

// MARK: - 播放器UI视图
class PlayerUIView: UIView {
    private var playerLayer: AVPlayerLayer
    
    init(player: AVPlayer) {
        self.playerLayer = AVPlayerLayer(player: player)
        self.playerLayer.videoGravity = .resizeAspectFill // 改回 resizeAspectFill 以填充整个视图
        
        super.init(frame: .zero)
        layer.addSublayer(playerLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}

// MARK: - 播放控制视图
struct PlaybackControlsView: View {
    @ObservedObject var playerController: DualStreamPlayerController
    @State private var isDragging: Bool = false
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack(spacing: 12) {
                // 播放/暂停按钮
                Button(action: {
                    if playerController.isPlaying {
                        playerController.pause()
                    } else {
                        playerController.resume()
                    }
                }) {
                    Image(systemName: playerController.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .resizable()
                        .frame(width: 44, height: 44)
                        .foregroundColor(.white)
                }
                
                // 进度条
                if playerController.duration > 0 {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // 背景轨道
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 4)
                            
                            // 进度轨道
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: geometry.size.width * CGFloat(playerController.currentTime / playerController.duration), height: 4)
                            
                            // 拖动区域
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: 44)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let percentage = value.location.x / geometry.size.width
                                            let newValue = Double(percentage) * playerController.duration
                                            playerController.seek(to: newValue)
                                            if !isDragging {
                                                isDragging = true
                                            }
                                        }
                                        .onEnded { _ in
                                            isDragging = false
                                        }
                                )
                        }
                    }
                    .frame(height: 44)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)
                }
                
                // 时间显示
                HStack(spacing: 4) {
                    Text(formatTime(playerController.currentTime))
                        .font(.caption)
                        .foregroundColor(.white)
                    Text("/")
                        .font(.caption)
                        .foregroundColor(.white)
                    Text(formatTime(playerController.duration))
                        .font(.caption)
                        .foregroundColor(.white)
                }
                .frame(width: 100) // 固定时间显示的宽度
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.5))
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite else {
            return "00:00"
        }
        
        let totalSeconds = Int(max(0, time))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

// MARK: - 主界面 (DualStreamPlayerView) - 集成手记入口
struct DualStreamPlayerView: View {
    @StateObject private var playerController = DualStreamPlayerController.shared
    @StateObject private var guardianController = GuardianController.shared
    
    // 视图内部状态
    @State private var videoOpacity: Double = 0.0
    @State private var startPanning: Bool = false
    
    // 日记功能相关状态
    @State private var showingMoodBanner: Bool = false
    @State private var selectedMood: Mood? = nil
    @State private var showingJournalEntry: Bool = false
    
    // Timer for auto-hiding controls
    @State private var autoHideTimer: Timer?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Color.black.edgesIgnoringSafeArea(.all)
                
                let videoWidth = geometry.size.height * 16/9
                let screenWidth = geometry.size.width
                let totalDistance = max(0, videoWidth - screenWidth)
                
                if playerController.videoPlayer.currentItem != nil {
                    VideoPlayerView(player: playerController.videoPlayer)
                        .frame(width: max(videoWidth, screenWidth), height: geometry.size.height + 49) // 49 是 TabBar 的高度
                        .clipped()
                        .opacity(videoOpacity)
                        .offset(x: startPanning ? -totalDistance : 0)
                        .animation(
                            .linear(duration: 30).repeatForever(autoreverses: true),
                            value: startPanning
                        )
                        .id(playerController.videoPlayer.currentItem)
                        .onAppear {
                            // 重置平移状态
                            self.startPanning = false
                            // 延迟一帧后开始平移，确保视图已经完全加载
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                self.startPanning = true
                            }
                        }
                        .onDisappear {
                            self.startPanning = false
                        }
                        .onChange(of: playerController.videoPlayer.currentItem) { _ in
                            // 当视频项改变时，重置平移状态
                            self.startPanning = false
                            // 延迟一帧后开始新的平移
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                self.startPanning = true
                            }
                        }
                }
                
                // 内容层
                VStack {
                    // 顶部区域
                    HStack(alignment: .center) {
                        // 左上角文字和倒计时
                        VStack(alignment: .leading, spacing: 6) {
                            if playerController.videoPlayer.currentItem == nil {
                                (Text("guardian.emptyPrompt.line1".localized)
                                    .font(.system(size: 20, weight: .light)) // 描述部分使用细体
                                    .foregroundColor(.white.opacity(0.80)) +
                                 Text("guardian.emptyPrompt.brand".localized + "\n") // 在“睡眠岛”后添加换行
                                    .font(.system(size: 20, weight: .medium)) // 品牌名使用中等粗细
                                    .foregroundColor(.white.opacity(0.95)) +
                                 Text("guardian.emptyPrompt.line2Suffix".localized.trimmingCharacters(in: .whitespacesAndNewlines)) // 移除前导空格，确保在新行正确显示
                                    .font(.system(size: 20, weight: .regular)) // 结尾部分使用常规体
                                    .foregroundColor(.white.opacity(0.85)))
                                .lineSpacing(4)
                            } else if guardianController.currentMode == .unlimited {
                                Text("guardian.status.accompany".localized)
                                    .font(.system(size: 24, weight: .light))
                                    .foregroundColor(.white.opacity(0.9))
                                Text("guardian.status.allNight".localized)
                                    .font(.system(size: 18, weight: .light))
                                    .foregroundColor(.white.opacity(0.7))
                            } else {
                                Text("guardian.status.accompany".localized)
                                    .font(.system(size: 24, weight: .light))
                                    .foregroundColor(.white.opacity(0.9))
                                if guardianController.countdown > 0 {
                                    Text(formatCountdown(guardianController.countdown))
                                        .font(.system(size: 16, weight: .light)) // 调整字体以适应可能更长的本地化字符串
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, geometry.safeAreaInsets.top > 0 ? geometry.safeAreaInsets.top : 20)
                        .opacity(playerController.showControls ? 1 : 0) // 根据控制状态显示/隐藏
                        
                        Spacer()
                        
                        // "睡不着？"入口
                        if guardianController.isGuardianModeEnabled {
                            Button(action: {
                                withAnimation {
                                    showingMoodBanner = true
                                }
                            }) {
                                Text("guardian.action.cantSleep".localized)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .foregroundColor(.white.opacity(0.45))
                                    .background(Color.white.opacity(0.075))
                                    .clipShape(Capsule())
                            }
                            .padding(.trailing, 20)
                            .padding(.top, geometry.safeAreaInsets.top > 0 ? geometry.safeAreaInsets.top : 20)
                            .opacity(playerController.showControls ? 1 : 0) // 根据控制状态显示/隐藏
                        }
                    }
                    .frame(width: screenWidth) // 限制顶部区域宽度为屏幕宽度
                    
                    Spacer()
                    
                    // 底部播放控制
                    if playerController.videoPlayer.currentItem != nil {
                        PlaybackControlsView(playerController: playerController)
                            .padding(.bottom, 60)
                            .frame(width: screenWidth) // 限制宽度为屏幕宽度
                            .opacity(playerController.showControls ? 1 : 0) // 根据控制状态显示/隐藏
                    }
                }
                .ignoresSafeArea(.keyboard)
                
                // 心情选择Banner
                if showingMoodBanner {
                    MoodSelectionBannerView(onMoodSelected: { mood in
                        selectedMood = mood
                        showingJournalEntry = true
                    }, isPresented: $showingMoodBanner)
                   // .frame(width: geometry.size.width)
                    .frame(width: screenWidth) // 限制宽度为屏幕宽度
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .transition(.opacity)
                    .zIndex(100)
                }
                
                // 日记书写界面
                if let mood = selectedMood, showingJournalEntry {
                    JournalEntryView(mood: mood, onSave: { content in
                        // 保存到 log
                        SleepLogManager.shared.upsertLog(for: Date(), mood: mood, notes: content)
                        showingJournalEntry = false
                        selectedMood = nil
                    }, isPresented: $showingJournalEntry)
                    .transition(.opacity)
                    .frame(width: screenWidth) // 限制宽度为屏幕宽度
                    .zIndex(200)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    playerController.showControls.toggle()
                }
            }
        }
        .onAppear {
            // If controls are shown on appear and video is ready, start timer
            if playerController.showControls && playerController.videoPlayer.currentItem != nil {
                startAutoHideTimer()
            }
        }
        .onDisappear {
            cancelAutoHideTimer()
        }
        .ignoresSafeArea(.keyboard)
        .onChange(of: playerController.isVideoReady) { isReady in
            let newOpacity = isReady ? 1.0 : 0.0
            if videoOpacity != newOpacity {
                withAnimation(.easeOut(duration: 0.5)) {
                    videoOpacity = newOpacity
                }
            }
            // If video becomes ready and controls are supposed to be shown, ensure timer starts
            if isReady && playerController.showControls {
                startAutoHideTimer()
            }
        }
        .onChange(of: playerController.showControls) { areControlsShown in
            if areControlsShown {
                startAutoHideTimer()
            } else {
                // If controls are hidden (e.g., by tap or by timer itself), cancel the timer.
                cancelAutoHideTimer()
            }
        }
        // Ensure timer restarts if playback starts while controls are visible
        .onChange(of: playerController.isPlaying) { isPlaying in
            if isPlaying && playerController.showControls {
                startAutoHideTimer()
            }
        }
    }
    
    private func startAutoHideTimer() {
        cancelAutoHideTimer() // Invalidate existing timer
        // Only schedule a new timer if there's a video item
        if playerController.videoPlayer.currentItem != nil {
            autoHideTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak playerController] _ in
                // Only hide if video is currently playing
                if playerController?.isPlaying == true {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        playerController?.showControls = false
                    }
                }
            }
        }
    }
    
    private func formatCountdown(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let remainingSeconds = seconds % 60
        
        if hours > 0 {
            return String(format: "countdown.format.hms".localized, hours, minutes, remainingSeconds)
        } else if minutes > 0 {
            return String(format: "countdown.format.ms".localized, minutes, remainingSeconds)
        } else {
            return String(format: "countdown.format.s".localized, remainingSeconds)
        }
    }
    
    private func cancelAutoHideTimer() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
    }
}
