import Foundation
import Combine

class PlaylistController: ObservableObject {
    static let shared = PlaylistController()
    
    // MARK: - Properties
    @Published private(set) var resources = [Resource]()
    @Published private(set) var currentResourceIndex = 0
    @Published private(set) var currentEpisode: Episode?
    @Published private(set) var playMode = PlayMode.sequential
    @Published private(set) var resourceProgresses = [String: Double]()
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Play Mode
    enum PlayMode {
        case sequential  // 顺序播放
        case singleLoop  // 单曲循环
        case random      // 随机播放
    }
    
    private init() {
        setupProgressSubscription()
    }
    
    // MARK: - Public Methods
    
    /// 设置播放列表
    func setPlaylist(_ resources: [Resource]) {
        self.resources = resources
        self.currentResourceIndex = 0
        refreshProgresses()
    }
    
    /// 播放指定资源
    func play(_ resource: Resource, episode: Episode? = nil) {
        // 如果资源不在当前列表中，则创建新列表
        if !resources.contains(where: { $0.resourceId == resource.resourceId }) {
            resources = [resource]
            currentResourceIndex = 0
        } else {
            // 如果资源在列表中，只更新索引
            currentResourceIndex = resources.firstIndex(where: { $0.resourceId == resource.resourceId }) ?? 0
        }
        currentEpisode = episode
        DualStreamPlayerController.shared.play(resource: resource)
    }
    
    /// 播放下一首
    func playNext() {
        guard !resources.isEmpty else { return }
        currentResourceIndex = (currentResourceIndex + 1) % resources.count
        play(resources[currentResourceIndex])
    }
    
    /// 播放上一首
    func playPrev() {
        guard !resources.isEmpty else { return }
        currentResourceIndex = (currentResourceIndex - 1 + resources.count) % resources.count
        play(resources[currentResourceIndex])
    }
    
    /// 设置播放模式
    func setPlayMode(_ mode: PlayMode) {
        self.playMode = mode
    }
    
    /// 刷新进度
    func refreshProgresses() {
        resourceProgresses = PlaybackProgressManager.shared.getProgresses(
            for: resources.map { $0.resourceId }
        )
    }
    
    // MARK: - Private Methods
    
 /*   private func startPlayback() {
        guard currentResourceIndex < resources.count else { return }
        let resource = resources[currentResourceIndex]
        
        // 通知 DualStreamPlayerController 开始播放
        if let episode = currentEpisode {
            DualStreamPlayerController.shared.play(
                resource: resource,
                episode: episode,
                progress: PlaybackProgressManager.shared.getProgress(for: resource.resourceId)
            )
        } else {
            DualStreamPlayerController.shared.play(
                resource: resource,
                progress: PlaybackProgressManager.shared.getProgress(for: resource.resourceId)
            )
        }
    }
    */
    private func setupProgressSubscription() {
        // 订阅播放进度更新
        NotificationCenter.default.publisher(for: .playbackProgressUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshProgresses()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Computed Properties
    
    /// 获取当前播放的资源
    var currentResource: Resource? {
        guard currentResourceIndex < resources.count else { return nil }
        return resources[currentResourceIndex]
    }
    
    /// 获取下一个资源（用于预览）
    var nextResource: Resource? {
        guard !resources.isEmpty else { return nil }
        let nextIndex = (currentResourceIndex + 1) % resources.count
        return resources[nextIndex]
    }
    
    /// 获取上一个资源（用于预览）
    var previousResource: Resource? {
        guard !resources.isEmpty else { return nil }
        let prevIndex = (currentResourceIndex - 1 + resources.count) % resources.count
        return resources[prevIndex]
    }
}

// 扩展 Array 以安全访问索引
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
} 
