import Foundation
import AVFoundation
import Combine
import os.log
import SwiftUI

extension Notification.Name {
    static let audioDidStartPlaying = Notification.Name("audioDidStartPlaying")
    static let videoDidStartPlaying = Notification.Name("videoDidStartPlaying")
}

class AudioManager: MediaPlayerController {
    static let shared = AudioManager()
    
    @Published var currentResource: Resource?
    @Published var currentEpisode: Episode?
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var shouldLoop = false
    @Published var isBuffering: Bool = false
    
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()
    private var playProgressDict: [String: Double] = [:]
    private let progressKey = "audio_play_progress"
    
    private override init() {
        super.init()
       // loadPlayProgress()
        //NotificationCenter.default.addObserver(self, selector: #selector(handleVideoDidStartPlaying), name: .videoDidStartPlaying, object: nil)
    }
    
    @objc private func handleVideoDidStartPlaying() {
        logger.info("收到视频开始播放通知")
        stop()
    }
    
    func playEpisode(_ episode: Episode) {
        return
        logger.info("[AudioManager] playEpisode called for id=\(episode.id)")
        removeTimeObserver()
        currentEpisode = episode
        currentTime = 0
        duration = TimeInterval(episode.durationSeconds)
        logger.info("播放剧集: id=\(episode.id), videoUrl=\(episode.videoUrl ?? "nil")")
        if let resource = currentResource, resource.resourceType == .tracklistAlbum {
            if !resource.audioUrl.isEmpty, let url = URL(string: resource.audioUrl) {
                logger.info("tracklist_album类型，使用resource.audioUrl: \(resource.audioUrl)")
                let playerItem = AVPlayerItem(url: url)
                player = AVPlayer(playerItem: playerItem)
                playerItem.addObserver(self, forKeyPath: "status", options: [.new, .old], context: nil)
                setupTimeObserver()
                player?.seek(to: CMTime(seconds: Double(episode.startTime ?? 0), preferredTimescale: 1000))
                NotificationCenter.default.post(name: .audioDidStartPlaying, object: nil)
                logger.info("[AudioManager] 发送 audioDidStartPlaying 通知 (tracklist)")
                player?.play()
                super.play()
                updatePlaybackState()
            } else {
                logger.error("tracklist_album类型但resource.audioUrl无效")
            }
            return
        }
        if let videoUrl = episode.videoUrl, !videoUrl.isEmpty {
            logger.info("使用视频URL: \(videoUrl)")
            if let url = URL(string: videoUrl) {
                let playerItem = AVPlayerItem(url: url)
                player = AVPlayer(playerItem: playerItem)
                playerItem.addObserver(self, forKeyPath: "status", options: [.new, .old], context: nil)
                setupTimeObserver()
                NotificationCenter.default.post(name: .audioDidStartPlaying, object: nil)
                logger.info("[AudioManager] 发送 audioDidStartPlaying 通知 (视频)")
                player?.play()
                super.play()
                updatePlaybackState()
            }
        } else if let url = URL(string: episode.audioUrl) {
            logger.info("使用音频URL: \(episode.audioUrl)")
            let playerItem = AVPlayerItem(url: url)
            player = AVPlayer(playerItem: playerItem)
            playerItem.addObserver(self, forKeyPath: "status", options: [.new, .old], context: nil)
            setupTimeObserver()
            NotificationCenter.default.post(name: .audioDidStartPlaying, object: nil)
            logger.info("[AudioManager] 发送 audioDidStartPlaying 通知 (普通)")
            player?.play()
            super.play()
            updatePlaybackState()
        }
    }
    
    func playResource(_ resource: Resource) {
        return
        logger.info("[AudioManager] playResource called for id=\(resource.id)")
        removeTimeObserver()
        currentResource = resource
        currentEpisode = nil
        currentTime = 0
        duration = TimeInterval(resource.totalDurationSeconds)
        if let videoUrl = resource.videoUrl, !videoUrl.isEmpty {
            logger.info("使用视频URL: \(videoUrl)")
            if let url = URL(string: videoUrl) {
                let playerItem = AVPlayerItem(url: url)
                player = AVPlayer(playerItem: playerItem)
                playerItem.addObserver(self, forKeyPath: "status", options: [.new, .old], context: nil)
                setupTimeObserver()
                NotificationCenter.default.post(name: .audioDidStartPlaying, object: nil)
                logger.info("[AudioManager] 发送 audioDidStartPlaying 通知 (视频)")
                player?.play()
                super.play()
                updatePlaybackState()
            }
        } else if !resource.audioUrl.isEmpty, let url = URL(string: resource.audioUrl) {
            logger.info("使用音频URL: \(resource.audioUrl)")
            let playerItem = AVPlayerItem(url: url)
            player = AVPlayer(playerItem: playerItem)
            playerItem.addObserver(self, forKeyPath: "status", options: [.new, .old], context: nil)
            setupTimeObserver()
            NotificationCenter.default.post(name: .audioDidStartPlaying, object: nil)
            logger.info("[AudioManager] 发送 audioDidStartPlaying 通知 (resource)")
            player?.play()
            super.play()
            updatePlaybackState()
        }
    }
    
    override func pause() {
        player?.pause()
        super.pause()
        updatePlaybackState()
        savePlayProgress()
    }
    
    override func play() {
    //    player?.play()
     //   super.play()
    }
    
    func seek(to time: TimeInterval) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 1000))
    }
    
    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time.seconds
            self.updatePlaybackState()
        }
    }
    
    private func removeTimeObserver() {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
    }
    
    private func updatePlaybackState() {
        // 更新播放状态
        if let player = player {
            isPlaying = player.rate > 0
            isBuffering = player.currentItem?.isPlaybackBufferEmpty ?? false
            player.actionAtItemEnd = shouldLoop ? .none : .pause
        }
    }
    
    override func stop() {
        removeTimeObserver()
        player?.pause()
        player = nil
        currentEpisode = nil
        currentResource = nil
        currentTime = 0
        duration = 0
        super.stop()
        savePlayProgress()
    }
    
    deinit {
        removeTimeObserver()
    }
    
    @objc private func playerDidFinishPlaying() {
        guard let resource = currentResource else { return }
        
        if resource.resourceType == .tracklistAlbum {
            // 对于 tracklist 类型，继续播放整个音频
            if shouldLoop {
                seek(to: 0)
                play()
            } else {
                isPlaying = false
                updatePlaybackState()
            }
        } else if let currentEpisode = currentEpisode,
                  let episodes = resource.episodes,
                  let currentIndex = episodes.firstIndex(where: { $0.id == currentEpisode.id }) {
            // 对于多集资源，自动播放下一集
            let nextIndex = currentIndex + 1
            if nextIndex < episodes.count {
                // 还有下一集，播放下一集
                playEpisode(episodes[nextIndex])
            } else {
                // 已经是最后一集
                if shouldLoop {
                    // 如果需要循环，从第一集开始播放
                    playEpisode(episodes[0])
                } else {
                    // 不需要循环，停止播放
                    isPlaying = false
                    updatePlaybackState()
                }
            }
        } else {
            // 单集资源的处理
            if shouldLoop {
                seek(to: 0)
                play()
            } else {
                isPlaying = false
                updatePlaybackState()
            }
        }
    }
    
    func resume() {
        player?.play()
        isPlaying = true
        updatePlaybackState()
    }
    
    // 获取剧集的播放进度百分比
    func getPlayProgressPercentage(for episode: Episode) -> Double {
        let progress = getPlayProgress(for: episode)
        return progress / Double(episode.durationSeconds)
    }
    
    // 获取剧集的播放进度
    func getPlayProgress(for episode: Episode) -> TimeInterval {
        return playProgressDict[episode.id] ?? 0
    }
    
    // 保存播放进度
    private func savePlayProgress() {
        if let data = try? JSONEncoder().encode(playProgressDict) {
            UserDefaults.standard.set(data, forKey: "playProgressDict")
        }
    }
    
    // 加载播放进度
    private func loadPlayProgress() {
        if let data = UserDefaults.standard.data(forKey: "playProgressDict"),
           let dict = try? JSONDecoder().decode([String: Double].self, from: data) {
            playProgressDict = dict
        }
    }
    
    // 添加观察者方法
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status",
           let playerItem = object as? AVPlayerItem {
            switch playerItem.status {
            case .readyToPlay:
                logger.info("音频准备就绪，可以播放")
            case .failed:
                logger.error("音频加载失败: \(String(describing: playerItem.error))")
            case .unknown:
                logger.info("音频状态未知")
            @unknown default:
                logger.info("未知状态")
            }
        }
    }
    
    func updatePlayProgress(for resource: Resource, progress: Double) {
        playProgressDict[resource.resourceId] = progress
        savePlayProgress()
    }
    
    func getPlayProgress(for resource: Resource) -> Double {
        playProgressDict[resource.resourceId] ?? 0.0
    }
}

// 播放进度模型
struct PlaybackProgress: Codable {
    let resourceId: String
    let id: String
    let currentTime: TimeInterval
}

extension AudioManager {
    // 获取当前track的起止时间
    var trackStart: Double {
        Double(currentEpisode?.startTime ?? 0)
    }
    var trackEnd: Double {
        Double(currentEpisode?.endTime ?? 0)
    }
    var trackDuration: Double {
        max(0, trackEnd - trackStart)
    }
    // 用于进度条分段和精准进度的 AVPlayer 当前时间
    var playerCurrentTime: Double {
        player?.currentTime().seconds ?? 0
    }
    var trackProgress: Double {
        max(0, min(playerCurrentTime - trackStart, trackDuration))
    }
    var progressPercent: Double {
        trackDuration > 0 ? trackProgress / trackDuration : 0
    }
    
    // 向前快进10秒
    func seekForward() {
        let newTime = playerCurrentTime + 10
        seek(to: newTime)
    }
    
    // 向后快退10秒
    func seekBackward() {
        let newTime = max(0, playerCurrentTime - 10)
        seek(to: newTime)
    }
    
    // 拖动进度条时调用
    func seekToTrackPosition(_ seconds: Double) {
        let seekTime = trackStart + seconds
        player?.seek(to: CMTime(seconds: seekTime, preferredTimescale: 600), completionHandler: { _ in })
    }
} 
