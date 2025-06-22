import SwiftUI
import AVKit
import Combine
import OSLog
import MediaPlayer

// MARK: - 主控制器 (DualStreamPlayerController) - 音频优先最终版
final class DualStreamPlayerController: NSObject, ObservableObject {
    // MARK: - 单例
    static let shared = DualStreamPlayerController()
    
    // MARK: - Published 属性
    @Published var isPlaying: Bool = false
    @Published var isVideoReady: Bool = false
    @Published var isAudioReady: Bool = false
    @Published var error: Error?
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var showControls: Bool = true
    @Published var isInitialShow: Bool = true
    
    let videoPlayer = AVPlayer()
    let audioPlayer = AVPlayer()
    
    // MARK: - 公开属性
    var hideControlsTimer: Timer? = nil
    
    // MARK: - 私有属性
    private let logger = Logger(subsystem: "com.sleepwell", category: "DualStreamPlayer")
    private var cancellables = Set<AnyCancellable>()
    private var notificationCancellables = Set<AnyCancellable>() // 专门管理通知监听器
    private var timeObserver: Any?
    private var isSeeking: Bool = false
    private var isAppInForeground: Bool = true // 跟踪应用是否在前台
    
    // ✨ 关键修正 1: 引入一个属性来记录时间观察者属于哪个播放器
    private var timeObserverPlayer: AVPlayer?
    
    private var videoItemStatusObserver: NSKeyValueObservation?
    private var audioItemStatusObserver: NSKeyValueObservation?
    
    private var lastProgressSaveDate: Date?
    private let progressSaveInterval: TimeInterval = 10.0 // 每10秒保存一次进度

    // MARK: - 资源信息
    public var currentResource: DualResource? {
        didSet {
            if let resource = currentResource {
                logger.info("✅ 设置新的资源: \(resource.name)")
                loadResourceMetadata(resource)
            } else {
                logger.info("❌ currentResource 被清空")
            }
        }
    }
    
    // MARK: - 初始化
    override private init() {
        super.init()
        audioPlayer.automaticallyWaitsToMinimizeStalling = true
        videoPlayer.automaticallyWaitsToMinimizeStalling = false
        setupNotifications()
        setupAudioSession()
        
        // 设置远程控制
        setupRemoteTransportControls()
        
        // 监听播放状态变化
        NotificationCenter.default.publisher(for: .playerDidStop)
            .sink { [weak self] _ in
                self?.handlePlaybackStopped()
            }
            .store(in: &notificationCancellables)
            
        // 监听守护模式结束
        NotificationCenter.default.publisher(for: .guardianModeDidEnd)
            .sink { [weak self] _ in
                print("📢 DualStreamPlayerController 收到 guardianModeDidEnd 通知，准备停止播放")
                // 先更新锁屏信息为守护结束状态
                self?.updateLockScreenForGuardianEnded()
                // 然后停止播放
                self?.stop()
            }
            .store(in: &notificationCancellables)
        
        // 监听守护模式改变
        NotificationCenter.default.publisher(for: .guardianModeDidChange)
            .sink { [weak self] _ in
                print("📢 DualStreamPlayerController 收到 guardianModeDidChange 通知，更新锁屏信息")
                if let resource = self?.currentResource {
                    self?.loadResourceMetadata(resource)
                }
            }
            .store(in: &notificationCancellables)
        
        print("🎧 DualStreamPlayerController 初始化完成，通知监听器已设置")
    }
    
    deinit {
        cleanupLockScreenControls()
    }
    
    // MARK: - 播放控制
    func pause() {
        videoPlayer.pause()
        audioPlayer.pause()
        isPlaying = false
        handlePlaybackStateChange()
    }
    
    func resume() {
        if isAudioReady || isVideoReady {
            audioPlayer.play()
            // 只在应用前台时恢复视频播放
            if isAppInForeground && isVideoReady {
                videoPlayer.play()
            }
            isPlaying = true
            handlePlaybackStateChange()
        }
    }
    
    func stop() {
        logger.info("🛑 开始停止播放")
        videoPlayer.pause()
        audioPlayer.pause()
        videoPlayer.replaceCurrentItem(with: nil)
        audioPlayer.replaceCurrentItem(with: nil)
        
        videoItemStatusObserver?.invalidate()
        audioItemStatusObserver?.invalidate()
        
        // ✨ 关键修正 2: 使用正确的播放器移除观察者
        if let player = timeObserverPlayer, let observer = timeObserver {
            player.removeTimeObserver(observer)
            logger.info("成功移除了一个时间观察者。")
        }
    //    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil // ✨ 确保清空
        timeObserver = nil
        timeObserverPlayer = nil
        
        // 只取消播放相关的订阅，保留通知监听器
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        
        // 注意：不取消 notificationCancellables，保持通知监听器活跃
        // 这样即使播放停止，仍能接收 guardianModeDidEnd 等通知
        
        isPlaying = false
        currentTime = 0
        duration = 0
        isVideoReady = false
        isAudioReady = false
        error = nil
        handlePlaybackStateChange()
        logger.info("🛑 播放已完全停止")
    }

    func seek(to time: TimeInterval) {
        guard !isSeeking, (isAudioReady || isVideoReady) else { return }
        isSeeking = true
        
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        let tolerance = CMTime.zero
        let seekGroup = DispatchGroup()
        
        if audioPlayer.currentItem != nil {
            seekGroup.enter()
            audioPlayer.seek(to: cmTime, toleranceBefore: tolerance, toleranceAfter: tolerance) { _ in seekGroup.leave() }
        }
        if videoPlayer.currentItem != nil {
            seekGroup.enter()
            videoPlayer.seek(to: cmTime, toleranceBefore: tolerance, toleranceAfter: tolerance) { _ in seekGroup.leave() }
        }
        
        seekGroup.notify(queue: .main) { [weak self] in
            self?.currentTime = time
            self?.isSeeking = false
            self?.updateNowPlayingInfo()
            
        }
    }
    
    // MARK: - 音频优先播放核心逻辑
    
    private func prepareAudioAndPlayWhenReady(item: AVPlayerItem) {
        audioItemStatusObserver = item.observe(\.status, options: [.new, .initial]) { [weak self] playerItem, _ in
            guard let self = self else { return }
            
            if playerItem.status == .readyToPlay {
                self.logger.info("✅ 音频流准备就绪，立即开始播放！")
                DispatchQueue.main.async {
                    self.isAudioReady = true
                    let dur = playerItem.asset.duration.seconds
                    if dur.isFinite, dur > 0 { // 直接使用 dur，因为它不是 Optional
                        self.duration = dur
                    }

                    let initialSeekTime = self.currentTime // currentTime 已被 play(resource:) 设置为缓存值
                    var playImmediately = true

                    // 如果有有效的缓存进度，并且不在非常接近开头或结尾的位置，则尝试跳转
                    if initialSeekTime > 1.0 && initialSeekTime < (self.duration - 1.0) {
                        playImmediately = false
                        self.isSeeking = true
                        self.logger.info("准备从缓存进度 \(initialSeekTime)s 开始播放音频。")
                        self.audioPlayer.seek(to: CMTime(seconds: initialSeekTime, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
                            guard let self = self else { return }
                            self.isSeeking = false
                            if finished {
                                self.logger.info("音频跳转到 \(initialSeekTime)s 成功。")
                            } else {
                                self.logger.warning("音频跳转到 \(initialSeekTime)s 失败，将从头播放。")
                                self.currentTime = 0 // 跳转失败，重置 currentTime
                            }
                            self.startAudioPlayback(playerItem: playerItem)
                        }
                    }

                    if playImmediately {
                        self.startAudioPlayback(playerItem: playerItem)
                    }
                }
                self.audioItemStatusObserver?.invalidate()
            } else if playerItem.status == .failed {
                self.handleError(playerItem.error, streamType: "音频")
                self.audioItemStatusObserver?.invalidate()
            }
        }
    }

    // 辅助方法，用于启动音频播放和相关设置
    private func startAudioPlayback(playerItem: AVPlayerItem) {
        self.audioPlayer.play()
        self.isPlaying = true
        self.setupTimeObserver() // 为音频流设置时间观察者
        self.setupAudioLooping()
        self.loadMetadataAndSetupNowPlaying(for: playerItem)
        self.handlePlaybackStateChange()
    }
    
    private func prepareVideoAndSyncWhenReady(item: AVPlayerItem) {
        videoItemStatusObserver = item.observe(\.status, options: [.new, .initial]) { [weak self] playerItem, _ in
            guard let self = self else { return }

            if playerItem.status == .readyToPlay {
                self.logger.info("✅ 视频流在后台准备就绪，开始同步播放。")
                DispatchQueue.main.async {
                    self.isVideoReady = true
                    self.loadMetadataAndSetupNowPlaying(for: playerItem)

                    let audioCurrentTime = self.audioPlayer.currentTime()
                    self.videoPlayer.seek(to: audioCurrentTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
                        guard let self = self, finished, self.isPlaying else { return }
                        self.videoPlayer.play()
                    }
                    
                    self.setupVideoLooping()
                }
                self.videoItemStatusObserver?.invalidate()
            } else if playerItem.status == .failed {
                self.handleError(playerItem.error, streamType: "视频")
                self.videoItemStatusObserver?.invalidate()
            }
        }
    }
    
    private func prepareVideoAndPlayWhenReady(item: AVPlayerItem) {
        videoItemStatusObserver = item.observe(\.status, options: [.new, .initial]) { [weak self] playerItem, _ in
            guard let self = self else { return }
            
            if playerItem.status == .readyToPlay {
                self.logger.info("✅ 单视频流准备就绪，开始播放。")
                DispatchQueue.main.async {
                    self.isVideoReady = true
                    let dur = playerItem.asset.duration.seconds
                    if dur.isFinite, dur > 0 { // 直接使用 dur，因为它不是 Optional
                        self.duration = dur
                    }

                    let initialSeekTime = self.currentTime // currentTime 已被 play(resource:) 设置为缓存值
                    var playImmediately = true

                    // 如果有有效的缓存进度，并且不在非常接近开头或结尾的位置，则尝试跳转
                    if initialSeekTime > 1.0 && initialSeekTime < (self.duration - 1.0) {
                        playImmediately = false
                        self.isSeeking = true
                        self.logger.info("准备从缓存进度 \(initialSeekTime)s 开始播放视频。")
                        self.videoPlayer.seek(to: CMTime(seconds: initialSeekTime, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
                            guard let self = self else { return }
                            self.isSeeking = false
                            if finished {
                                self.logger.info("视频跳转到 \(initialSeekTime)s 成功。")
                            } else {
                                self.logger.warning("视频跳转到 \(initialSeekTime)s 失败，将从头播放。")
                                self.currentTime = 0 // 跳转失败，重置 currentTime
                            }
                            self.startSingleVideoPlayback(playerItem: playerItem)
                        }
                    }
                    if playImmediately {
                        self.startSingleVideoPlayback(playerItem: playerItem)
                    }
                }
                self.videoItemStatusObserver?.invalidate()
            } else if playerItem.status == .failed {
                self.handleError(playerItem.error, streamType: "视频")
                self.videoItemStatusObserver?.invalidate()
            }
        }
    }

    // 辅助方法，用于启动单视频播放和相关设置
    private func startSingleVideoPlayback(playerItem: AVPlayerItem) {
        self.videoPlayer.play()
        self.isPlaying = true
        self.setupTimeObserver(forVideo: true) // 为视频流设置时间观察者
        self.setupVideoLooping()
        self.handlePlaybackStateChange() // 确保锁屏信息等被更新
    }
    
    // MARK: - 音频会话设置
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            logger.info("音频会话设置成功")
        } catch {
            logger.error("音频会话设置失败: \(error)")
        }
    }

    // MARK: - 音频会话处理
    @objc private func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // 中断开始，暂停播放
            logger.info("音频会话中断开始")
            pause()
        case .ended:
            // 中断结束，恢复播放
            logger.info("音频会话中断结束")
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                resume()
            }
        @unknown default:
            break
        }
    }

    // MARK: - 私有辅助方法
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    @objc private func handleDidEnterBackground() {
        logger.info("📱 App 进入后台，暂停视频播放以节省电量")
        isAppInForeground = false
        // 暂停视频播放，但保持音频播放
        if isPlaying && isVideoReady {
            videoPlayer.pause()
            logger.info("⏸️ 视频已暂停，音频继续播放")
        }
    }
    
    @objc private func handleWillEnterForeground() {
        logger.info("📱 App 返回前台，恢复视频播放")
        isAppInForeground = true
        if self.isPlaying {
            // 恢复音频播放（如果被暂停了）
            if audioPlayer.rate == 0 {
                audioPlayer.play()
            }
            // 恢复视频播放
            if self.isVideoReady && videoPlayer.rate == 0 {
                self.videoPlayer.play()
                logger.info("▶️ 视频已恢复播放")
            }
        }
    }
    
    private func setupTimeObserver(forVideo: Bool = false) {
        // ✨ 关键修正 3: 在设置新的观察者前，先用正确的方式移除旧的
          if let player = timeObserverPlayer, let observer = timeObserver {
              player.removeTimeObserver(observer)
              self.timeObserver = nil
              self.timeObserverPlayer = nil
          }
          
      let player = forVideo ? videoPlayer : audioPlayer
        // 这个 interval (0.5秒) 是为了UI上进度条的平滑更新
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600) 
        
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, !self.isSeeking else { return }
            
            let newCurrentTime = time.seconds
            // 更新UI绑定的 currentTime
            if abs(newCurrentTime - self.currentTime) > 0.01 || !self.isPlaying {
                self.currentTime = newCurrentTime
            }

            // --- 这里是关键的定期保存逻辑 ---
            if self.isPlaying { // 仅在播放时才执行
                let now = Date()
                // 检查是否达到了 progressSaveInterval (例如10秒)
                if self.lastProgressSaveDate == nil || now.timeIntervalSince(self.lastProgressSaveDate!) >= self.progressSaveInterval {
                    self.saveCurrentPlaybackProgress() // 调用保存方法
                    self.lastProgressSaveDate = now    // 更新上次保存时间
                }
            }
            // --- 定期保存逻辑结束 ---
        }
        
        timeObserverPlayer = player
        logger.info("成功添加了一个时间观察者。")
    }

        // MARK: - 进度保存辅助方法
    private func saveCurrentPlaybackProgress() {
        guard let resource = self.currentResource, !resource.resourceId.isEmpty else {
            // logger.debug("跳过进度保存：无当前资源或资源ID为空。")
            return
        }
        PlaybackProgressManager.shared.saveProgress(self.currentTime, for: resource.resourceId)
        logger.info("💾 播放进度已保存: \(String(format: "%.2f", self.currentTime))s 资源ID: \(resource.resourceId)")
    }
    
    
    private func setupVideoLooping() {
        videoPlayer.actionAtItemEnd = .none
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: videoPlayer.currentItem)
            .sink { [weak self] _ in
                self?.logger.info("视频播放到末尾。")
                
                // 检查守护模式是否还在进行
                if GuardianController.shared.isGuardianModeEnabled {
                    self?.logger.info("🔄 守护模式还在进行，视频自动循环播放")
                    self?.videoPlayer.seek(to: .zero)
                    // 重置当前时间
                    self?.currentTime = 0
                    if self?.isPlaying == true && self?.isAppInForeground == true {
                        self?.videoPlayer.play()
                    }
                } else {
                    self?.logger.info("守护模式已结束，视频停止循环")
                    // 视频停止，但音频可能还在播放
                }
            }
            .store(in: &cancellables)
    }

    private func setupAudioLooping() {
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: audioPlayer.currentItem)
            .sink { [weak self] _ in
                self?.logger.info("主音频轨播放结束。")
                
                // 检查守护模式是否还在进行
                if GuardianController.shared.isGuardianModeEnabled {
                    self?.logger.info("🔄 守护模式还在进行，自动循环播放")
                    // 跳回到开头继续播放
                    self?.audioPlayer.seek(to: .zero)
                    // 重置当前时间
                    self?.currentTime = 0
                    // 更新锁屏进度信息
                    self?.updateNowPlayingInfo()
                    if self?.isPlaying == true {
                        self?.audioPlayer.play()
                    }
                    // 如果有视频，也同步跳转
                    if self?.isVideoReady == true {
                        self?.videoPlayer.seek(to: .zero)
                        if self?.isPlaying == true && self?.isAppInForeground == true {
                            self?.videoPlayer.play()
                        }
                    }
                } else {
                    self?.logger.info("守护模式已结束，停止播放")
                    self?.stop()
                }
            }
            .store(in: &cancellables)
    }

    private func handleError(_ error: Error?, streamType: String) {
        logger.error("❌ \(streamType)流加载失败: \(error?.localizedDescription ?? "未知错误")")
        DispatchQueue.main.async {
            if self.error == nil { self.error = error }
        }
    }

    private func setupVideoPlaybackMonitoring() {
        // 监控视频播放状态
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleVideoPlaybackStalled),
            name: .AVPlayerItemPlaybackStalled,
            object: videoPlayer.currentItem
        )
        
        // 定期检查视频播放状态
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self,
                  self.isPlaying,
                  self.isVideoReady else { return }
            
            // 只在应用前台时恢复视频播放
            if self.isAppInForeground {
                // 如果视频暂停但音频在播放，则恢复视频播放
                if self.videoPlayer.rate == 0 && self.audioPlayer.rate > 0 {
                    self.logger.info("检测到视频暂停，正在恢复播放...")
                    self.videoPlayer.play()
                }
            }
        }
    }

    @objc private func handleVideoPlaybackStalled(_ notification: Notification) {
        logger.warning("视频播放缓冲中，等待缓冲完成...")
        // 不立即尝试恢复播放，等待缓冲完成
    }

    private func setupRemoteTransportControls() {
 
        UIApplication.shared.beginReceivingRemoteControlEvents()
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in 
            guard let self = self else { return .commandFailed }
            
            // 如果播放器没有准备好但守护模式已结束，重新开始播放
            if !self.isAudioReady && !self.isVideoReady && !GuardianController.shared.isGuardianModeEnabled {
                logger.info("🔄 锁屏播放按钮：重新开始播放")
                if let resource = self.currentResource {
                    self.play(resource: resource)
                    // 重新开启守护模式
                    GuardianController.shared.enableGuardianMode(GuardianController.shared.currentMode)
                }
                return .success
            }
            
            // 正常的恢复播放
            self.resume()
            return .success 
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in self?.pause(); return .success }
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                self?.seek(to: event.positionTime)
                return .success
            }
            return .commandFailed
        }
    }
    
    // ✨ 1. 新增一个核心方法，专门负责加载元数据并设置初始的锁屏信息
    private func loadResourceMetadata(_ resource: DualResource) {
        // 创建异步任务
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            // 1. 加载封面图片
            var artworkImage: UIImage? = nil
            if let coverURL = URL(string: resource.coverImageUrl),
               let imageData = try? Data(contentsOf: coverURL) {
                artworkImage = UIImage(data: imageData)
            }
            
            // 2. 获取资源信息
            let baseArtistName = "app.name".localized
            var artistSubtitle = ""
            let currentGuardianMode = GuardianController.shared.currentMode
            
            print("🔄 更新锁屏信息 - 当前守护模式: \(currentGuardianMode.displayTitle)")
            
            switch currentGuardianMode {
            case .unlimited:
                artistSubtitle = " · " + "guardian.status.allNight".localized
            case .smartDetection:
                artistSubtitle = " · " + "智能检测" // Assuming "智能检测" is the desired string
            case _ where currentGuardianMode.duration > 0:
                let stopTime = Date().addingTimeInterval(TimeInterval(GuardianController.shared.countdown)) // Use countdown for accuracy
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "HH:mm"
                artistSubtitle = " · " + String(format: "guardian.status.stopAtTimeFormat".localized, timeFormatter.string(from: stopTime))
                print("⏰ 定时模式 - 停止时间: \(timeFormatter.string(from: stopTime))")
            default:
                artistSubtitle = "" // No subtitle for other cases or if duration is not positive
            }
            
            let title = resource.name
            let artist = baseArtistName + artistSubtitle
            let tags = resource.tags.joined(separator: ", ")
            
            // 3. 在主线程更新 UI
            DispatchQueue.main.async {
                // 更新锁屏信息
                var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                
                // 设置基本信息
                nowPlayingInfo[MPMediaItemPropertyTitle] = title
                nowPlayingInfo[MPMediaItemPropertyArtist] = artist
                
                // 设置标签信息（如果有）
                if !tags.isEmpty {
                    nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = tags
                }
                
                // 设置封面图片
                if let image = artworkImage {
                    let artwork = MPMediaItemArtwork(boundsSize: image.size, requestHandler: { _ in
                        return image
                    })
                    nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
                }
                
                // 设置时长信息
                nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = self.duration // Use the player's duration
                nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = self.currentTime
                nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = self.isPlaying ? 1.0 : 0.0
                
                // 应用更新
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                self.logger.info("✅ 已更新资源元数据: \(title) - \(artist)")
            }
        }
        
        // 在后台队列执行任务
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
    }
    
    // ✨ 1. 新增一个核心方法，专门负责加载元数据并设置初始的锁屏信息
    private func loadMetadataAndSetupNowPlaying(for item: AVPlayerItem) {
        // 我们需要异步加载 'duration' 这个关键信息
        let metadataKeys = ["duration"]
        
        // loadValuesAsynchronously 的回调本身就在一个后台线程执行
        item.asset.loadValuesAsynchronously(forKeys: metadataKeys) { [weak self] in
            guard let self = self else { return }
            
            // 检查资源加载是否出错
            var error: NSError?
            if item.asset.statusOfValue(forKey: "duration", error: &error) == .failed {
                self.logger.error("❌ 加载元数据 'duration' 失败: \(error?.localizedDescription ?? "未知错误")")
                return
            }
            
            // 只有当 duration 有效时，才设置锁屏信息
            guard let duration = item.asset.duration.seconds.isFinite && item.asset.duration.seconds > 0 ? item.asset.duration.seconds : nil else {
                self.logger.warning("⚠️ 无法获取有效的时长，跳过设置锁屏信息。")
                return
            }
            
            // 在主线程更新 UI
            DispatchQueue.main.async {
                var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                
                // 设置时长信息
                nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
                nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = self.currentTime
                nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = self.isPlaying ? 1.0 : 0.0
                
                // 应用更新
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                self.logger.info("✅ 已更新播放时长信息")
            }
        }
    }
    
    private func updateNowPlayingInfo() {
        guard var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        
        // 只更新动态信息
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = self.currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = self.isPlaying ? 1.0 : 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    // 处理播放停止
    private func handlePlaybackStopped() {
        DispatchQueue.main.async {
            self.updateNowPlayingInfo()
        }
    }
    
    // 在播放状态变化时更新锁屏信息
    private func handlePlaybackStateChange() {
        updateNowPlayingInfo()
    }

    // 重新开始播放
    func restart() {
        logger.info("🔄 重新开始播放")
        stop()
        if let resource = currentResource {
            play(resource: resource)
        }
        // 注意：不在这里重新开启守护模式，由 GuardianController 自己处理
        // 这样可以避免重复开启和计时器冲突
    }

    // MARK: - 播放控制
    func play(resource: DualResource) {
        stop() // 首先停止当前播放并清理状态

        self.currentResource = resource
        logger.info("开始处理播放资源: \(resource.name)")

        // 从缓存加载此资源的播放进度
        let savedProgress = PlaybackProgressManager.shared.getProgress(for: resource.resourceId) ?? 0.0
        self.currentTime = savedProgress // 设置初始 currentTime，UI会立即响应
        self.duration = TimeInterval(resource.totalDurationSeconds) // 设置初始 duration，UI会立即响应
        logger.info("资源 \(resource.name) 的缓存进度为: \(savedProgress)s, 总时长: \(self.duration)s")
        
        // 检查是否有双流资源
        if let videoClipUrl = resource.videoClipUrl, !videoClipUrl.isEmpty,
           !resource.audioUrl.isEmpty,
           let videoClipURL = URL(string: videoClipUrl),
           let audioURL = URL(string: resource.audioUrl) {
            logger.info("开始播放双流模式（音频优先）...")
            
            let videoAsset = AVURLAsset(url: videoClipURL)
            let videoPlayerItem = AVPlayerItem(asset: videoAsset)
            videoPlayerItem.preferredForwardBufferDuration = 10
            videoPlayer.replaceCurrentItem(with: videoPlayerItem)
            videoPlayer.volume = 0
            videoPlayer.automaticallyWaitsToMinimizeStalling = false
            
            let audioAsset = AVURLAsset(url: audioURL)
            let audioPlayerItem = AVPlayerItem(asset: audioAsset)
            audioPlayer.replaceCurrentItem(with: audioPlayerItem)
            
            // 分别启动音频和视频的准备流程
            prepareAudioAndPlayWhenReady(item: audioPlayerItem)
            prepareVideoAndSyncWhenReady(item: videoPlayerItem)
            
            // 添加视频播放状态监控
            setupVideoPlaybackMonitoring()
        } else if !resource.audioUrl.isEmpty,
                  let audioURL = URL(string: resource.audioUrl) {
            // 单音频播放
            logger.info("开始播放单音频模式...")
            
            let asset = AVURLAsset(url: audioURL)
            let playerItem = AVPlayerItem(asset: asset)
            audioPlayer.replaceCurrentItem(with: playerItem)
            
            prepareAudioAndPlayWhenReady(item: playerItem)
        } else {
            logger.error("资源格式不支持: \(resource.name)")
        }
    }

    // 完全清理锁屏控制条（在应用退出或用户主动退出时调用）
    func cleanupLockScreenControls() {
        logger.info("🧹 清理锁屏控制条")
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        UIApplication.shared.endReceivingRemoteControlEvents()
    }

    // 更新守护结束后的锁屏信息
    func updateLockScreenForGuardianEnded() {
        logger.info("📱 更新锁屏信息：守护已结束")
        
        guard var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo else { 
            logger.warning("⚠️ 没有现有的锁屏信息，无法更新")
            return 
        }
        
        // 记录更新前的信息
        let oldArtist = nowPlayingInfo[MPMediaItemPropertyArtist] as? String ?? "未知"
        logger.info("📱 更新前 artist: \(oldArtist)")
        
        // 只更新 artist 信息，保持播放进度不变
        nowPlayingInfo[MPMediaItemPropertyArtist] = "guardian.status.restart".localized
        
        // 保持播放进度不变，只设置播放状态为暂停
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        logger.info("✅ 锁屏信息已更新为守护结束状态，播放进度保持不变")
    }
}


// ✨ 一个完全独立的最小化测试类
class MinimalPlayerTester {
    static let shared = MinimalPlayerTester()
    private var player: AVPlayer!

    func testPlayback() {
        print("--- [Minimal Test] 开始运行 ---")

        // 1. 设置最简单的音频会话
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            print("[Minimal Test] 音频会话设置成功并已激活。")
        } catch {
            print("[Minimal Test] ❌ 音频会话设置失败: \(error)")
            return
        }

        // 2. 使用一个绝对有效的公共音频URL，排除您自己文件的可能性
        // 这是一个Apple的测试音频文件
        guard let url = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear0/fileSequence0.aac") else {
            print("[Minimal Test] ❌ URL 创建失败。")
            return
        }
        
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)

        // 3. 开始播放
        player.play()
        print("[Minimal Test] 已调用 play()。")

        // 4. 设置最简单的远程控制命令
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.addTarget { [weak self] _ in self?.player.play(); return .success }
        commandCenter.pauseCommand.addTarget { [weak self] _ in self?.player.pause(); return .success }
        UIApplication.shared.beginReceivingRemoteControlEvents()
        print("[Minimal Test] 远程控制命令已设置。")

        // 5. 设置最简单的锁屏信息
        var nowPlayingInfo: [String: Any] = [:]
        nowPlayingInfo[MPMediaItemPropertyTitle] = "最小化测试"
        nowPlayingInfo[MPMediaItemPropertyArtist] = "正在调试"
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = playerItem.asset.duration.seconds
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = playerItem.currentTime().seconds
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player.rate

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        print("[Minimal Test] NowPlayingInfo 已设置。")
    }
}
