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
    private var timeObserver: Any?
    private var isSeeking: Bool = false
    
    // ✨ 关键修正 1: 引入一个属性来记录时间观察者属于哪个播放器
    private var timeObserverPlayer: AVPlayer?
    
    private var videoItemStatusObserver: NSKeyValueObservation?
    private var audioItemStatusObserver: NSKeyValueObservation?

    // MARK: - 资源信息
    public var currentResource: Resource? {
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
            .store(in: &cancellables)
            
        // 监听守护模式结束
        NotificationCenter.default.publisher(for: .guardianModeDidEnd)
            .sink { [weak self] _ in
                self?.stop()
            }
            .store(in: &cancellables)
    }
    
    deinit {
        stop()
        UIApplication.shared.endReceivingRemoteControlEvents()
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
            videoPlayer.play()
            isPlaying = true
            handlePlaybackStateChange()
        }
    }
    
    func stop() {
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
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil // ✨ 确保清空
        timeObserver = nil
        timeObserverPlayer = nil
        
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        
        isPlaying = false
        currentTime = 0
        duration = 0
        isVideoReady = false
        isAudioReady = false
        error = nil
        handlePlaybackStateChange()
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
                    if let dur = playerItem.asset.duration.seconds.isFinite ? playerItem.asset.duration.seconds : nil {
                        self.duration = dur
                    }
                    self.audioPlayer.play()
                    self.isPlaying = true
                    self.setupTimeObserver()
                    self.setupAudioLooping()
                    self.loadMetadataAndSetupNowPlaying(for: playerItem)
                }
                self.audioItemStatusObserver?.invalidate()
            } else if playerItem.status == .failed {
                self.handleError(playerItem.error, streamType: "音频")
                self.audioItemStatusObserver?.invalidate()
            }
        }
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
                    if let dur = playerItem.asset.duration.seconds.isFinite ? playerItem.asset.duration.seconds : nil {
                        self.duration = dur
                    }
                    self.videoPlayer.play()
                    self.isPlaying = true
                    self.setupTimeObserver(forVideo: true)
                    self.setupVideoLooping()
                }
                self.videoItemStatusObserver?.invalidate()
            } else if playerItem.status == .failed {
                self.handleError(playerItem.error, streamType: "视频")
                self.videoItemStatusObserver?.invalidate()
            }
        }
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
    }
    
    @objc private func handleWillEnterForeground() {
        if self.isPlaying {
            logger.info("App 返回前台，恢复播放。")
            self.audioPlayer.play()
            if self.isVideoReady { self.videoPlayer.play() }
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
          let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
          
          timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
              guard let self = self, !self.isSeeking else { return }
              self.currentTime = time.seconds
          }
          
          // ✨ 关键修正 4: 在"记事本"上记下这把钥匙属于谁
          timeObserverPlayer = player
          logger.info("成功添加了一个时间观察者。")
    }
    
    private func setupVideoLooping() {
        videoPlayer.actionAtItemEnd = .none
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: videoPlayer.currentItem)
            .sink { [weak self] _ in
                self?.logger.info("视频循环：播放到末尾，跳回开头。")
                self?.videoPlayer.seek(to: .zero)
                if self?.isPlaying == true { self?.videoPlayer.play() }
            }
            .store(in: &cancellables)
    }

    private func setupAudioLooping() {
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: audioPlayer.currentItem)
            .sink { [weak self] _ in
                self?.logger.info("主音频轨播放结束。")
                self?.stop()
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
            
            // 如果视频暂停但音频在播放，则恢复视频播放
            if self.videoPlayer.rate == 0 && self.audioPlayer.rate > 0 {
                self.logger.info("检测到视频暂停，正在恢复播放...")
                self.videoPlayer.play()
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
        
        commandCenter.playCommand.addTarget { [weak self] _ in self?.resume(); return .success }
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
    private func loadResourceMetadata(_ resource: Resource) {
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
            let title = resource.name
            let artist = "伴你入眠"
            let tags = resource.tags.joined(separator: ", ")
            let duration = resource.totalDurationSeconds
            
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
                nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
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
        stop()
        if let resource = currentResource {
            play(resource: resource)
        }
        // 如果之前开启了守护模式，重新开启
        if GuardianController.shared.isGuardianModeEnabled {
            GuardianController.shared.enableGuardianMode(GuardianController.shared.currentMode)
        }
    }

    // MARK: - 播放控制
    func play(resource: Resource) {
        self.currentResource = resource
        
        // 检查是否有双流资源
        if let videoClipUrl = resource.videoClipUrl, !videoClipUrl.isEmpty,
           !resource.audioUrl.isEmpty,
           let videoClipURL = URL(string: videoClipUrl),
           let audioURL = URL(string: resource.audioUrl) {
            // 双流播放
            logger.info("开始播放双流模式（音频优先）...")
            stop()
            
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
            stop()
            
            let asset = AVURLAsset(url: audioURL)
            let playerItem = AVPlayerItem(asset: asset)
            audioPlayer.replaceCurrentItem(with: playerItem)
            
            prepareAudioAndPlayWhenReady(item: playerItem)
        } else {
            logger.error("资源格式不支持: \(resource.name)")
        }
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
