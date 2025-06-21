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


struct PlayerPlaceholderView: View {
    @State private var isAnimating: Bool = false

    var body: some View {
        ZStack {
            // MARK: - 背景
            // 假設您有一個名為 Playerground 的背景檢視
            // 如果 Playerground 不存在，可以用 Color.black 或其他檢視替代
            // Playerground()
//            Image("player_background") // <-- 使用您在 Assets 中的圖片名稱
//                           .resizable()           // 讓圖片可縮放
//                           .scaledToFill()        //
//                           .edgesIgnoringSafeArea(.all) //
//                          // .blur(radius: 5)       // (可選) 加上模糊效果，讓文字更突出
//                           //.overlay(Color.black.opacity(0.3)) // (可選) //疊加一層半透明黑色，讓背景變暗

            // Background Image Layer
            // Color.clear 作为覆盖层的基础，它将占据 ZStack 的全部空间。
            // 下面的 .edgesIgnoringSafeArea(.all) 会使 ZStack 及其内容（包括 Color.clear）全屏。
            Color.clear
                .overlay(
                    Image("player_background") // <-- 使用您在 Assets 中的圖片名稱
                        .resizable()           // 讓圖片可縮放
                        .aspectRatio(contentMode: .fill) // 保持图片的宽高比，同时填充整个可用空间。这可能会导致图片部分内容被裁剪。
                    , alignment: .topTrailing // 将图片对齐到容器（Color.clear）的右上角。
                    
                                             // 如果图片填充后比容器大，这将决定裁剪的锚点。
                )
                .clipped() // 裁剪掉图片超出 Color.clear 边界的部分。
                .edgesIgnoringSafeArea(.all)
/*
            // MARK: - 文字內容佈局
            VStack {
                Text("guardian.emptyPrompt.line1".localized)
                    .font(.system(size: 20, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .kerning(0.5)
                    .padding(.top, 60)

                Spacer()

                // MARK: - 主標題
                Text("guardian.emptyPrompt.brand".localized)
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                    .scaleEffect(isAnimating ? 1.02 : 1.0) // 應用呼吸動畫的縮放效果

                // MARK: - 副標題
                Text("guardian.emptyPrompt.line2Suffix".localized)
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .padding(.top, 8) // 在主副標題之間增加一點間距

                Spacer()
                Spacer() // 使用兩個 Spacer 將文字內容整體稍微向上推，使其在視覺上更居中
            }
 */
        }
        .onAppear(perform: startBreathingAnimation)
    }

    /// 啟動一個平滑的、無限重複的呼吸動畫
    private func startBreathingAnimation() {
        // 使用 withAnimation 包裹狀態變更
        // .repeatForever 會讓動畫無限循環
        withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
            isAnimating = true
        }
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
                        .foregroundColor(.white.opacity(0.5)) // 4. 播放按钮颜色调暗
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
                .frame(width: 115) // 固定时间显示的宽度
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            // Consider a smaller fixed bottom padding if desired, e.g., .padding(.bottom, 16)
            .background(Color.black.opacity(0.35)) // 3. 播放控制条透明度降低
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
        self.videoOpacity =   initialIsReady ? 0.9 : 0.0
        // For debugging, you can print the initial values:
        // print("hzg: DualStreamPlayerView init -> isVideoReady: \(initialIsReady), videoOpacity set to: \(self._videoOpacity.wrappedValue)")
    }
    
    
    var body: some View {
        GeometryReader { geometry in
            ZStack (alignment: .topLeading){ // Root ZStack

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
                        .offset(x: startPanning ? -totalDistance : 0) // Offset depends on startPanning
                        .animation( // Conditional animation
                            startPanning ? .linear(duration: 30).repeatForever(autoreverses: true) : .default,
                            // Animate when startPanning changes.
                            // If startPanning becomes false, offset goes to 0 with .default animation.
                            // If startPanning becomes true, offset goes to -totalDistance with repeating animation.
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
                            // Set startPanning to false. This will:
                            // 1. Change the offset target to 0.
                            // 2. Trigger the .animation modifier, which will use .default (non-repeating)
                            //    animation because startPanning is now false.
                            self.startPanning = false
                            print("hzg: VideoPlayerView onChange currentItem (startPanning set to false to reset for new item: \(newItem != nil))")
                            // The .onAppear of the new VideoPlayerView (recreated due to .id())
                            // will handle setting startPanning = true if newItem is not nil,
                            // initiating the new repeating animation from offset 0.
                            // No need to set startPanning = true here.
                        }
                } // End of VideoPlayerView conditional
                else{
                    PlayerPlaceholderView()
                        .frame(width: geometry.size.width)
                }
                
                // UI Controls Overlay Layer
                if playerController.showControls {
                    VStack(alignment: .center, spacing: 30) { // 整体顶部控件的 VStack
                        
                        // Top Controls Container
                        HStack(alignment: .top) { // Use .top alignment for elements like status and button
                            topLeftStatusView(geometry: geometry) // Pass geometry if needed by helper
                            Spacer()
                            cantSleepButton(geometry: geometry) // Pass geometry if needed by helper
                        }
                        .padding(.top, 30) // 5. 顶部控件增加额外上边距
                        .padding(.horizontal, 10) // 5. 顶部控件增加额外上边距
                        
                        Spacer() // Pushes bottom controls down (PlaybackControlsView)
                        // 新增：定时器选择条
                        if playerController.videoPlayer.currentItem != nil { // 仅当有视频播放时显示定时器选项
                            // MARK: - 优化方案
                            // 将原本左对齐的HStack改为VStack，使其在水平方向上居中，布局更开阔。
                            VStack(spacing: 8) { // 优化点 2: 增加了按钮与下方文字的间距，使其不那么拥挤
                                
                                // 按钮行
                                HStack(spacing: 12) { // 优化点 3: 略微增加按钮间的距离
                                    TimerOptionButton( targetMode: .timedClose1800)
                                    TimerOptionButton( targetMode: .timedClose3600)
                                    TimerOptionButton( targetMode: .timedClose7200)
                                    TimerOptionButton( targetMode: .unlimited)
                                }
                            }
                            .padding(.vertical, 5) // 优化点 6: 调整垂直内边距，使其更具呼吸感
                            .padding(.horizontal, 10)
                            .frame(maxWidth: .infinity) // 确保VStack横向撑满
                            
                            .cornerRadius(12) // 优化点 7: 增加圆角半径，使其看起来更柔和
                        }
                        
                        // Bottom Playback Controls
                        if playerController.videoPlayer.currentItem != nil {
                            PlaybackControlsView(playerController: playerController)
                                .frame(width: screenWidth) // screenWidth from geometry
                                .padding(.bottom, 50) // 2. 为播放控制条增加额外下边距以避开TabBar
                        }
                    }
                    
                    .padding(.bottom, globalSafeAreaInsets.bottom) // 使用全局安全区域值
                    .padding(.top, globalSafeAreaInsets.top) // 使用全局安全区域值 (确保顶部也有安全边距)
                    .frame(width: geometry.size.width, height: geometry.size.height) // Make VStack fill the screen
                    
                }
                
                // Banners and Journal Entry (positioned absolutely, might need zIndex adjustments)
                if showingMoodBanner {
                    MoodSelectionBannerView(onMoodSelected: { mood in
                        selectedMood = mood
                    //    showingJournalEntry = true
                    }, isPresented: $showingMoodBanner)
                    .frame(width: screenWidth)
                    .position(x: geometry.size.width / 2, y: geometry.size.height *  1 / 3)
                    .transition(.opacity)
                    .zIndex(100) // Ensure banners are above controls if they overlap
                }
                
            /*    if let mood = selectedMood {
                    JournalEntryView(mood: mood, onSave: { content in
                        SleepLogManager.shared.upsertLog(for: Date(), mood: mood, notes: content)
                    //    showingJournalEntry = false
                        selectedMood = nil
                    }, isPresented: $showingJournalEntry)
                    .transition(.opacity)
                    .frame(width: screenWidth)
                    .zIndex(200) // Ensure journal is above everything
 
                }
             */
                if let mood = selectedMood{
                    // 当 selectedMood 不为 nil 时，这个 cover 会自动呈现
                    // 并且 'mood' 参数就是解包后的、安全的值
                    JournalEntryView(
                        mood: mood,
                        onSave: { content in
                            // 保存逻辑
                            SleepLogManager.shared.upsertLog(for: Date(), mood: mood, notes: content)
                            
                            // 关闭 cover 的唯一方法：将 item 设为 nil
                            selectedMood = nil
                        },
                        // 记得给 JournalEntryView 传递一个关闭自身的闭包
                        // 如果 JournalEntryView 内部的关闭按钮需要起作用的话
                        onDismiss: {
                            selectedMood = nil
                        },
                        initialContent: SleepLogManager.shared.getLog(for: Date())?.notes ?? ""
                    )
                    .padding(.top, 30) // 5. 顶部控件增加额外上边距
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
            let newOpacity = isReady ? 0.9 : 0.0
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
                if let resourceName = playerController.currentResource?.name {
                    Text(resourceName)
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 250)
                }
                Text("guardian.status.allNight".localized)
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(.white.opacity(0.7))
            } else {
                Text("guardian.status.accompany".localized)
                    .font(.system(size: 24, weight: .light))
                    .foregroundColor(.white.opacity(0.9))
                if let resourceName = playerController.currentResource?.name {
                    Text(resourceName)
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 250)
                }
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

// MARK: - Timer Option Button
struct TimerOptionButton: View {
    let targetMode: GuardianMode
    @EnvironmentObject private var guardianController: GuardianController

    private var isSelected: Bool {
        guardianController.currentMode == targetMode
    }

    var body: some View {
        Button(action: {
            guardianController.enableGuardianMode(targetMode)
        }) {
            Text(targetMode.displayTitle)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .black : .white.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 8) // 增加了垂直方向的 padding，让按钮更高一点，更有点击感
                .frame(maxWidth: .infinity) // <<--- 核心优化点：让按钮在HStack中撑满可用空间
                .background(isSelected ? Color.white.opacity(0.6) : Color.white.opacity(0.2))
                .clipShape(Capsule())
        }
    }
}

// MARK: - SwiftUI 預覽
struct PlayerPlaceholderView_Previews: PreviewProvider {
    static var previews: some View {
        PlayerPlaceholderView()
    }
}
//
//// MARK: - DualStreamPlayerView 预览
//struct DualStreamPlayerView_Previews: PreviewProvider {
//    static var previews: some View {
//    
//        DualStreamPlayerView()
//            // DualStreamPlayerView uses @StateObject for its controllers,
//            // which are initialized with .shared instances,
//            // so direct environmentObject injection here might not be strictly necessary
//            // unless sub-sub-views expect them via @EnvironmentObject.
//            .environmentObject(DualStreamPlayerController.shared)
//            .environmentObject(GuardianController.shared)
//            .background(Color.gray) // Add a background to see the view against
//    }
//}
