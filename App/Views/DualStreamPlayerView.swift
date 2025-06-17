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
        // PlaybackControlsView is now just the HStack with controls
        // The outer VStack and Spacer are removed.
        // The large .padding(.bottom, 100) is removed.
        // A smaller, fixed bottom padding can be added if needed for aesthetics within the safe area.
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
                .frame(width: 105) // 固定时间显示的宽度
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            // Consider a smaller fixed bottom padding if desired, e.g., .padding(.bottom, 16)
            .background(Color.black.opacity(0.5))
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
    @State private var videoOpacity:Double
    @State private var startPanning: Bool = false
    
    // 日记功能相关状态
    @State private var showingMoodBanner: Bool = false
    @State private var selectedMood: Mood? = nil
    @State private var showingJournalEntry: Bool = false
    
    // Timer for auto-hiding controls
    @State private var autoHideTimer: Timer?
    @Environment(\.globalSafeAreaInsets) private var globalSafeAreaInsets // 读取环境值
    
    init() {
        // Initialize videoOpacity based on the initial state of isVideoReady
        let initialIsReady = DualStreamPlayerController.shared.isVideoReady
        self.videoOpacity =   initialIsReady ? 0.5 : 0.0
        // For debugging, you can print the initial values:
        // print("hzg: DualStreamPlayerView init -> isVideoReady: \(initialIsReady), videoOpacity set to: \(self._videoOpacity.wrappedValue)")
    }
    
    
    var body: some View {
        GeometryReader { geometry in
            ZStack (alignment: .topLeading){ // Root ZStack
           //     Color.red.edgesIgnoringSafeArea(.all)
                // Video Layer - always full screen
                let videoWidth = geometry.size.height * 16/9
                let screenWidth = geometry.size.width
                let totalDistance = max(0, videoWidth - screenWidth)
                
                if playerController.videoPlayer.currentItem != nil {
                    VideoPlayerView(player: playerController.videoPlayer)
                        .frame(width: max(videoWidth, screenWidth), height: geometry.size.height) // 49 是 TabBar 的高度
                        .ignoresSafeArea() // Video ignores all safe areas to go full screen
                        .clipped()
                        .opacity(videoOpacity)
                        .offset(x: startPanning ? -totalDistance : 0)
                        .animation(
                            .linear(duration: 30).repeatForever(autoreverses: true),
                            value: startPanning
                        )
                    
                        .id(playerController.videoPlayer.currentItem)
                    
                        .onAppear {
                            // .onAppear 主要处理首次加载或视图因 currentItem 存在而出现的情况。
                            // 如果 currentItem 存在且平移尚未开始，则启动平移。
                            // 如果已在平移（例如，从隐藏的Tab切回），则不应重置。
                            if playerController.videoPlayer.currentItem != nil && !self.startPanning {
                                print("hzg: VideoPlayerView ON_APPEAR (currentItem exists, startPanning was false. Initiating pan.)")
                                // 使用微小延迟确保视图已准备好动画
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    self.startPanning = true
                                }
                            } else if playerController.videoPlayer.currentItem != nil && self.startPanning {
                                print("hzg: VideoPlayerView ON_APPEAR (currentItem exists, startPanning is true. Pan should continue.)")
                            } else {
                                print("hzg: VideoPlayerView ON_APPEAR (No currentItem or other state. startPanning: \(self.startPanning))")
                            }
                        }
                        .onDisappear {
                            // 仅当视图消失是因为没有视频内容时，才停止平移。
                            // 如果 currentItem 仍然存在，我们假设这可能是Tab切换等临时隐藏，
                            // 此时保持 startPanning 状态，以便动画可以在视图重新出现时继续。
                            if playerController.videoPlayer.currentItem == nil {
                                self.startPanning = false
                                print("hzg: VideoPlayerView onDisappear (currentItem is NIL. startPanning set to false)")
                            } else {
                                print("hzg: VideoPlayerView onDisappear (currentItem EXISTS. startPanning remains \(self.startPanning) for potential resume)")
                            }
                        }
                        .onChange(of: playerController.videoPlayer.currentItem) { newItem in
                            // 当视频项实际改变时，这是重置并重新启动平移的主要时机。
                            self.startPanning = false // 确保旧动画停止，偏移量回到0
                            print("hzg: VideoPlayerView onChange currentItem (startPanning set to false to reset for new item: \(newItem != nil))")
                            if newItem != nil {
                                // 延迟确保视图更新后再启动新动画
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    self.startPanning = true
                                    print("hzg: VideoPlayerView onChange currentItem (startPanning set to true for new item)")
                                }
                            }
                        }
                } // End of VideoPlayerView conditional
                
                // UI Controls Overlay Layer
               if playerController.showControls {
                    VStack(spacing: 0) { // Use spacing 0 if elements should touch or manage spacing internally
                       
                        // Top Controls Container
                        HStack(alignment: .top) { // Use .top alignment for elements like status and button
                            topLeftStatusView(geometry: geometry) // Pass geometry if needed by helper
                            Spacer()
                            cantSleepButton(geometry: geometry) // Pass geometry if needed by helper
                        }
                        .padding(.top, globalSafeAreaInsets.top + 20) // 使用全局安全区域值
                        .padding(.horizontal, 20) // Horizontal padding for the group
                        
                        Spacer() // Pushes bottom controls down
                
                        // Bottom Playback Controls
                       if playerController.videoPlayer.currentItem != nil {
                            PlaybackControlsView(playerController: playerController)
                                .frame(width: screenWidth) // screenWidth from geometry
                                // 新增这里：为控件本身增加一个额外的底部间距来避开 TabBar
                                .padding(.bottom, 49) // 49pt 是 TabBar 的标准高度，您可以根据实际情况调整
                        }
                    }

                    .padding(.bottom, globalSafeAreaInsets.bottom) // 使用全局安全区域值
                    .frame(width: geometry.size.width, height: geometry.size.height) // Make VStack fill the screen
                    .transition(.opacity) // Animate the entire controls VStack
               }

                // Banners and Journal Entry (positioned absolutely, might need zIndex adjustments)
                if showingMoodBanner {
                    MoodSelectionBannerView(onMoodSelected: { mood in
                        selectedMood = mood
                        showingJournalEntry = true
                    }, isPresented: $showingMoodBanner)
                    .frame(width: screenWidth)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .transition(.opacity)
                    .zIndex(100) // Ensure banners are above controls if they overlap
                }
                
                if let mood = selectedMood, showingJournalEntry {
                    JournalEntryView(mood: mood, onSave: { content in
                        SleepLogManager.shared.upsertLog(for: Date(), mood: mood, notes: content)
                        showingJournalEntry = false
                        selectedMood = nil
                    }, isPresented: $showingJournalEntry)
                    .transition(.opacity)
                    .frame(width: screenWidth)
                    .zIndex(200) // Ensure journal is above everything
                }
            } // End of Root ZStack
            .contentShape(Rectangle()) // 保留以便整个区域可点击
            .onTapGesture {
                print(geometry)
                withAnimation(.easeInOut(duration: 0.3)) { // Keep animation here for the toggle
                    playerController.showControls.toggle()
                }
            }
        }
        .onAppear {
            if playerController.showControls && playerController.videoPlayer.currentItem != nil {
                startAutoHideTimer()
            }
        }
        .ignoresSafeArea(.keyboard) // Keep this
        .onDisappear {
            cancelAutoHideTimer()
        }
        .onChange(of: playerController.isVideoReady) { isReady in
            print("hzg: isVideoReady changed to: \(isReady)")
            let newOpacity = isReady ? 0.5 : 0.0
            if videoOpacity != newOpacity {
                withAnimation(.easeOut(duration: 0.5)) {
                    videoOpacity = newOpacity
                }
            }
            if isReady && playerController.showControls {
                startAutoHideTimer()
            }
        }
        .onChange(of: playerController.showControls) { areControlsShown in
            if areControlsShown {
                startAutoHideTimer()
            } else {
                cancelAutoHideTimer()
            }
        }
        .onChange(of: playerController.isPlaying) { isPlaying in
            if isPlaying && playerController.showControls {
                startAutoHideTimer()
            }
        }
    }
    // Helper view for top left status text
    @ViewBuilder
    private func topLeftStatusView(geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if playerController.videoPlayer.currentItem == nil {
                (
                Text("guardian.emptyPrompt.line1".localized)
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(.white.opacity(0.80)) +
                 Text("guardian.emptyPrompt.brand".localized + "\n")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white.opacity(0.95)) +
                 Text("guardian.emptyPrompt.line2Suffix".localized.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.system(size: 20, weight: .regular))
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
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }

    // Helper view for "Can't sleep?" button
    @ViewBuilder
    private func cantSleepButton(geometry: GeometryProxy) -> some View {
        if guardianController.isGuardianModeEnabled {
            Button(action: {
                withAnimation { showingMoodBanner = true }
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
            // Removed top padding here
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
                        //hzg
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


// MARK: - DualStreamPlayerView 预览
struct DualStreamPlayerView_Previews: PreviewProvider {
    static var previews: some View {
    
        DualStreamPlayerView()
            // DualStreamPlayerView uses @StateObject for its controllers,
            // which are initialized with .shared instances,
            // so direct environmentObject injection here might not be strictly necessary
            // unless sub-sub-views expect them via @EnvironmentObject.
            .environmentObject(DualStreamPlayerController.shared)
            .environmentObject(GuardianController.shared)
            .background(Color.gray) // Add a background to see the view against
    }
}
