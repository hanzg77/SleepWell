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
    @Published var isLoadingMore = false
    @Published var navigationMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private var hasMoreResources = true
    
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
        self.hasMoreResources = true
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
        
        if currentResourceIndex < resources.count - 1 {
            // 还有下一个资源
            currentResourceIndex += 1
            play(resources[currentResourceIndex])
        } else {
            // 到达列表末尾，尝试加载更多
            loadMoreResources()
        }
    }
    
    /// 播放上一首
    func playPrev() {
        guard !resources.isEmpty else { return }
        
        if currentResourceIndex > 0 {
            // 还有上一个资源
            currentResourceIndex -= 1
            play(resources[currentResourceIndex])
        } else {
            // 到达列表开头
            showNavigationMessage("player.navigation.first_resource".localized)
        }
    }
    
    /// 加载更多资源
    private func loadMoreResources() {
        guard hasMoreResources && !isLoadingMore else { return }
        
        isLoadingMore = true
        showNavigationMessage("player.navigation.loading_more".localized)
        
        // 获取当前资源的分类信息
        let currentCategory = currentResource?.category
        
        // 记录当前资源数量
        let currentResourceCount = resources.count
        
        NetworkManager.shared.loadMoreResources(pageSize: 20, category: currentCategory, searchQuery: nil)
        
        // 使用一次性监听器来监听资源更新
        var resourceUpdateCancellable: AnyCancellable?
        resourceUpdateCancellable = NetworkManager.shared.$resources
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newResources in
                guard let self = self else { return }
                
                // 取消订阅，避免重复处理
                resourceUpdateCancellable?.cancel()
                
                if newResources.count > currentResourceCount {
                    // 有新资源加载
                    self.resources = newResources
                    self.currentResourceIndex += 1
                    self.play(self.resources[self.currentResourceIndex])
                    self.hasMoreResources = newResources.count >= 20 // 假设每页20个资源
                } else {
                    // 没有更多资源
                    self.hasMoreResources = false
                    self.showNavigationMessage("player.navigation.no_more_resources".localized)
                }
                
                self.isLoadingMore = false
            }
    }
    
    /// 显示导航消息
    private func showNavigationMessage(_ message: String) {
        navigationMessage = message
        
        // 2秒后自动清除消息
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if self.navigationMessage == message {
                self.navigationMessage = nil
            }
        }
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
