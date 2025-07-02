import SwiftUI
import AVKit
import AVFoundation
import MediaPlayer

// MARK: - VideoPlayerView (UIViewRepresentable)
// Wraps a UIKit AVPlayerLayer in a SwiftUI View.
struct VideoPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        return PlayerUIView(player: player)
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        // This can be used to update the view from SwiftUI state changes if needed.
    }
}

// MARK: - PlayerPlaceholderView
// A placeholder view displayed when no video is loaded.
struct PlayerPlaceholderView: View {
    @State private var isAnimating: Bool = false

    var body: some View {
        ZStack {
            // Background Image Layer
            Color.clear
                .overlay(
                    Image("player_background") // <-- Make sure you have this image in your Assets
                        .resizable()
                        .aspectRatio(contentMode: .fill),
                    alignment: .topTrailing
                )
                .clipped()
                .edgesIgnoringSafeArea(.all)

            // You can re-add your text content here if you want it on the placeholder
            /*
            VStack {
                Text("guardian.emptyPrompt.line1".localized)
                // ... other text elements
            }
            */
        }
        .onAppear(perform: startBreathingAnimation)
    }

    /// Starts a smooth, infinitely repeating breathing animation for the placeholder.
    private func startBreathingAnimation() {
        withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
            isAnimating = true
        }
    }
}


// MARK: - PlayerUIView (Backing UIView for VideoPlayerView)
class PlayerUIView: UIView {
    private var playerLayer: AVPlayerLayer

    init(player: AVPlayer) {
        self.playerLayer = AVPlayerLayer(player: player)
        self.playerLayer.videoGravity = .resizeAspectFill // Fills the entire view bounds.
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

// MARK: - PlaybackControlsView
// The bottom bar with play/pause, progress slider, and time display.
struct PlaybackControlsView: View {
    @ObservedObject var playerController: DualStreamPlayerController
    @State private var isDragging: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // Play/Pause Button
            // FIX: Extracted the action to a private method to resolve compiler issues.
            Button(action: togglePlayPause) {
                Image(systemName: playerController.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .resizable()
                    .frame(width: 44, height: 44)
                    .foregroundColor(.white.opacity(0.5))
            }

            // Progress Slider
            if playerController.duration > 0 {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 4)
                        // Progress track
                        Rectangle().fill(Color.white).frame(width: geometry.size.width * CGFloat(playerController.currentTime / playerController.duration), height: 4)
                        // Drag area
                        Rectangle().fill(Color.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        handleDragChange(value: value, geometry: geometry)
                                    }
                                    .onEnded { _ in isDragging = false }
                            )
                    }
                    .frame(height: 44) // Make the draggable area larger
                }
                .frame(height: 44)
            } else {
                Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 4)
            }

            // Time Display
            HStack(spacing: 4) {
                Text(formatTime(playerController.currentTime))
                Text("/")
                Text(formatTime(playerController.duration))
            }
            .font(.caption)
            .foregroundColor(.white)
            .frame(width: 115) // Fixed width for consistent layout
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.35))
    }
    
    private func togglePlayPause() {
        if playerController.isPlaying {
            playerController.pause()
        } else {
            playerController.resume()
        }
        //playerController.togglePlayPause()
    }
    
    private func handleDragChange(value: DragGesture.Value, geometry: GeometryProxy) {
        if !isDragging { isDragging = true }
        let percentage = max(0, min(1, value.location.x / geometry.size.width))
        let newTime = Double(percentage) * playerController.duration
        playerController.seek(to: newTime)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite, time > 0 else { return "00:00" }
        let totalSeconds = Int(time)
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

// MARK: - DualStreamPlayerView (Main View)
struct DualStreamPlayerView: View {
    @StateObject private var playerController = DualStreamPlayerController.shared
    @StateObject private var guardianController = GuardianController.shared
    @StateObject private var playlistController = PlaylistController.shared

    // Internal View State
    @State private var videoOpacity: Double
    @State private var startPanning: Bool = false
    @State private var dragOffset: CGFloat = 0
    @State private var autoHideTimer: Timer?

    // Journaling State
    @State private var showingMoodBanner: Bool = false
    @State private var selectedMood: Mood? = nil

    @Environment(\.globalSafeAreaInsets) private var globalSafeAreaInsets

    init() {
        // Initialize videoOpacity based on the player's initial state.
        _videoOpacity = State(initialValue: DualStreamPlayerController.shared.isVideoReady ? 0.9 : 0.0)
    }

    // MARK: - Body (Refactored)
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Layer 1: Video or Placeholder background
                videoLayer(geometry: geometry)

                // Layer 2: UI Controls (only shows when toggled)
                controlsOverlay(geometry: geometry)

                // Layer 3: Navigation Messages (e.g., "No more videos")
                navigationMessageOverlay(geometry: geometry)
                
                // Layer 4: Journaling UI (mood selection, etc.)
                journalOverlay(geometry: geometry)
            }
            .contentShape(Rectangle()) // Makes the entire area responsive to gestures
            .gesture(swipeGesture)
            .onTapGesture(perform: toggleControls)
            .onAppear(perform: viewDidAppear)
            .onDisappear(perform: cancelAutoHideTimer)
            .ignoresSafeArea(.keyboard)
            .onChange(of: playerController.isVideoReady, perform: handleVideoReadyChange)
            .onChange(of: playerController.showControls, perform: handleShowControlsChange)
            .onChange(of: playerController.isPlaying, perform: handleIsPlayingChange)
        }
    }
}

// MARK: - DualStreamPlayerView: Sub-views (Refactored Helpers)
extension DualStreamPlayerView {
    
    /// **REFACTOR REASON:** This helper contains the logic for displaying either the video player
    /// or the placeholder, keeping the main `body` clean.
    @ViewBuilder
    private func videoLayer(geometry: GeometryProxy) -> some View {
        let screenWidth = geometry.size.width
        let screenHeight = geometry.size.height
        
        if playerController.videoPlayer.currentItem != nil {
            let videoWidth = screenHeight * (16/9)
            let totalPanDistance = max(0, videoWidth - screenWidth)
            
            VideoPlayerView(player: playerController.videoPlayer)
                .frame(width: max(videoWidth, screenWidth), height: screenHeight)
                .ignoresSafeArea()
                .clipped()
                .opacity(videoOpacity)
                .offset(x: startPanning ? -totalPanDistance : 0)
                .animation(
                    startPanning ? .linear(duration: 30).repeatForever(autoreverses: true) : .default,
                    value: startPanning
                )
                .id(playerController.videoPlayer.currentItem) // Recreates view on item change
                .onAppear {
                    // Start panning animation if it's not already running
                    if !self.startPanning {
                        DispatchQueue.main.async { self.startPanning = true }
                    }
                }
                .onChange(of: playerController.videoPlayer.currentItem) { _ in
                    // Reset animation when video changes
                    self.startPanning = false
                }
        } else {
            PlayerPlaceholderView()
                .frame(width: screenWidth, height: screenHeight)
                .onAppear {
                    // Ensure panning is stopped when there's no video
                    if self.startPanning {
                       self.startPanning = false
                    }
                }
        }
    }

    /// **REFACTOR REASON:** This helper centralizes all UI controls that appear and disappear,
    /// such as buttons, sliders, and status text.
    @ViewBuilder
    private func controlsOverlay(geometry: GeometryProxy) -> some View {
        if playerController.showControls {
            VStack(alignment: .center, spacing: 0) {
                // Top controls (status text and "Can't Sleep?" button)
                HStack(alignment: .top) {
                    topLeftStatusView
                    Spacer()
                    cantSleepButton
                }
                .padding(.horizontal, 10)
                .padding(.top, 30)

                Spacer()

                // Timer selection buttons
                timerSelectionView
                
                // Bottom playback controls
                if playerController.videoPlayer.currentItem != nil {
                    PlaybackControlsView(playerController: playerController)
                        .padding(.bottom, 50) // Avoid TabBar overlap
                }
            }
            .padding(.top, globalSafeAreaInsets.top)
            .padding(.bottom, globalSafeAreaInsets.bottom)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .transition(.opacity.animation(.easeInOut(duration: 0.3)))
        }
    }

    /// **REFACTOR REASON:** Encapsulates the logic for the playlist navigation messages.
    @ViewBuilder
    private func navigationMessageOverlay(geometry: GeometryProxy) -> some View {
        if let message = playlistController.navigationMessage {
            VStack {
                Spacer()
                Text(message)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(20)
                    .padding(.bottom, 100)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .zIndex(300)
        }
    }
    
    /// **REFACTOR REASON:** Contains the logic for showing the mood banner and the journal entry view.
    @ViewBuilder
    private func journalOverlay(geometry: GeometryProxy) -> some View {
        // Mood Selection Banner
        if showingMoodBanner {
            MoodSelectionBannerView(onMoodSelected: { mood in
                selectedMood = mood
            }, isPresented: $showingMoodBanner)
            .position(x:  UIScreen.main.bounds.width / 2, y: geometry.size.height / 3)
            .frame(width: UIScreen.main.bounds.width)
            .transition(.opacity)
            .zIndex(100)
        }
        
        // Journal Entry View (using if-let for presentation)
        if let mood = selectedMood {
            JournalEntryView(
                mood: mood,
                onSave: { content in
                    SleepLogManager.shared.upsertLog(for: Date(), mood: mood, notes: content)
                    selectedMood = nil // Dismiss
                },
                onDismiss: {
                    selectedMood = nil // Dismiss
                },
                initialContent: SleepLogManager.shared.getLog(for: Date())?.notes ?? ""
            )
            .frame(width: UIScreen.main.bounds.width)
            .padding(.top, 30)
            .zIndex(200)
        }
    }
}

// MARK: - DualStreamPlayerView: Gestures (Refactored)
extension DualStreamPlayerView {
    
    /// **REFACTOR REASON:** Extracts the complex drag gesture logic into a separate computed property.
    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Only process vertical swipes
                if abs(value.translation.height) > abs(value.translation.width) {
                    self.dragOffset = value.translation.height
                }
            }
            .onEnded { value in
                let threshold: CGFloat = 100 // Swipe threshold
                if abs(value.translation.height) > threshold {
                    if value.translation.height > 0 {
                        playlistController.playPrev() // Swipe down
                    } else {
                        playlistController.playNext() // Swipe up
                    }
                }
                self.dragOffset = 0 // Reset drag offset
            }
    }
}

// MARK: - DualStreamPlayerView: Helper Views & Actions
extension DualStreamPlayerView {
    
    // --- Helper Views ---
    @ViewBuilder
    private var topLeftStatusView: some View {
        VStack(alignment: .leading, spacing: 6) {
            if playerController.videoPlayer.currentItem == nil {
                // Use a single Text view with AttributedString for different styles if needed,
                // or a VStack for simplicity.
                Text("guardian.emptyPrompt.line1".localized)
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(.white.opacity(0.80))
                Text("guardian.emptyPrompt.brand".localized)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white.opacity(0.95))
                Text("guardian.emptyPrompt.line2Suffix".localized)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(.white.opacity(0.85))
                
            } else if guardianController.currentMode == .unlimited {
                Text("guardian.status.accompany".localized)
                    .font(.system(size: 24, weight: .light))
                if let name = playerController.currentResource?.name { Text(name).lineLimit(1).truncationMode(.tail) }
                Text("guardian.status.allNight".localized)
            } else {
                Text("guardian.status.accompany".localized)
                    .font(.system(size: 24, weight: .light))
                if let name = playerController.currentResource?.name { Text(name).lineLimit(1).truncationMode(.tail) }
                if guardianController.countdown > 0 { Text(formatCountdown(guardianController.countdown)) }
            }
        }
        .font(.system(size: 18, weight: .light))
        .foregroundColor(.white.opacity(0.7))
    }

    @ViewBuilder
    private var cantSleepButton: some View {
        if guardianController.isGuardianModeEnabled {
            Button(action: { withAnimation { showingMoodBanner = true } }) {
                Text("guardian.action.cantSleep".localized)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .foregroundColor(.white.opacity(0.45))
                    .background(Color.white.opacity(0.075))
                    .clipShape(Capsule())
            }
        }
    }

    @ViewBuilder
    private var timerSelectionView: some View {
        if playerController.videoPlayer.currentItem != nil {
            HStack(spacing: 12) {
                TimerOptionButton(targetMode: .timedClose1800)
                TimerOptionButton(targetMode: .timedClose3600)
                TimerOptionButton(targetMode: .timedClose7200)
                TimerOptionButton(targetMode: .unlimited)
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
        }
    }
    
    // --- Actions & Handlers ---
    private func toggleControls() {
        withAnimation {
            playerController.showControls.toggle()
        }
    }

    private func viewDidAppear() {
        if playerController.showControls && playerController.videoPlayer.currentItem != nil {
            startAutoHideTimer()
        }
    }
    
    private func handleVideoReadyChange(isReady: Bool) {
        withAnimation(.easeOut(duration: 0.5)) {
            videoOpacity = isReady ? 0.9 : 0.0
        }
        if isReady && playerController.showControls {
            startAutoHideTimer()
        }
    }

    private func handleShowControlsChange(areShown: Bool) {
        if areShown { startAutoHideTimer() }
        else { cancelAutoHideTimer() }
    }
    
    private func handleIsPlayingChange(isPlaying: Bool) {
        if isPlaying && playerController.showControls {
            startAutoHideTimer()
        }
    }

    private func startAutoHideTimer() {
        cancelAutoHideTimer()
        guard playerController.videoPlayer.currentItem != nil else { return }
        
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            if self.playerController.isPlaying {
                self.toggleControls()
            }
        }
    }
    
    private func cancelAutoHideTimer() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
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
}


// MARK: - TimerOptionButton
struct TimerOptionButton: View {
    let targetMode: GuardianMode
    @EnvironmentObject private var guardianController: GuardianController

    private var isSelected: Bool { guardianController.currentMode == targetMode }

    var body: some View {
        Button(action: { guardianController.enableGuardianMode(targetMode) }) {
            Text(targetMode.displayTitle)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .black : .white.opacity(0.8))
                .padding(.horizontal, 12).padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(isSelected ? Color.white.opacity(0.6) : Color.white.opacity(0.2))
                .clipShape(Capsule())
        }
    }
}

// MARK: - Previews
struct PlayerPlaceholderView_Previews: PreviewProvider {
    static var previews: some View {
        PlayerPlaceholderView().preferredColorScheme(.dark)
    }
}
