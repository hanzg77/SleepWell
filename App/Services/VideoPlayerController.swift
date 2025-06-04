import AVKit
import SwiftUI
import OSLog

class VideoPlayerController: ObservableObject {
    // MARK: - 单例
    static let shared = VideoPlayerController()
    
    // MARK: - 属性
    @Published var player: AVPlayer = AVPlayer()
    @Published var currentURL: URL?
    @Published var isLoading: Bool = false
    @Published var error: Error?
    
    private init() {}
    
    // MARK: - 公共方法
    func setupPlayer(url: URL) {
        // 如果正在播放相同的 URL，不做任何改变
        if currentURL == url {
            play()
            return
        }
        stop()
        currentURL = url
        isLoading = true
        error = nil
        loadVideo(url: url)
    }
    
    private func loadVideo(url: URL) {
        let asset = AVURLAsset(url: url)
        asset.loadValuesAsynchronously(forKeys: ["tracks"]) { [weak self] in
            guard let self = self else { return }
            var error: NSError? = nil
            let status = asset.statusOfValue(forKey: "tracks", error: &error)
            DispatchQueue.main.async {
                switch status {
                case .loaded:
                    let playerItem = AVPlayerItem(asset: asset)
                    self.player.replaceCurrentItem(with: playerItem)
                    self.isLoading = false
                    self.play()
                case .failed:
                    self.error = error
                    self.isLoading = false
                default:
                    self.isLoading = false
                }
            }
        }
    }
    
    func play() {
        player.play()
    }
    
    func pause() {
        player.pause()
    }
    
    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        currentURL = nil
        isLoading = false
        error = nil
    }
}

