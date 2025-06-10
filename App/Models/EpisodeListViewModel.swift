import Foundation
import Combine

class EpisodeListViewModel: ObservableObject {
    @Published var episodes: [Episode] = []
    @Published var selectedEpisode: Episode?
    @Published var hasMorePages = true
    @Published var isLoading = false
    @Published var error: Error?
    
    private let resource: Resource
    private var currentPage = 1
    private let pageSize = 20
    private var cancellables = Set<AnyCancellable>()
    
    init(resource: Resource) {
        self.resource = resource
        print("初始化 EpisodeListViewModel，资源ID: \(resource.resourceId)")
        loadEpisodes()
    }
    
    func loadEpisodes() {
        guard !isLoading else {
            print("已经在加载中，跳过重复请求")
            return
        }
        print("开始加载剧集列表，页码: \(currentPage)")
        isLoading = true
        currentPage = 1
        // 直接从 resource.episodes 获取剧集
        let allEpisodes = resource.episodes

        // 分页
        let startIndex = (currentPage - 1) * pageSize
        let endIndex = min(startIndex + pageSize, allEpisodes.count)
        if startIndex < allEpisodes.count {
            self.episodes = Array(allEpisodes[startIndex..<endIndex])
            self.hasMorePages = endIndex < allEpisodes.count
        } else {
            self.episodes = []
            self.hasMorePages = false
        }
        isLoading = false
        print("✅ 收到剧集数据: \(self.episodes.count) 个剧集")
    }
    
    func loadMoreEpisodes() {
        guard !isLoading, hasMorePages else { return }
        isLoading = true
        currentPage += 1
        
        let allEpisodes = resource.episodes

        let startIndex = (currentPage - 1) * pageSize
        let endIndex = min(startIndex + pageSize, allEpisodes.count)
        if startIndex < allEpisodes.count {
            self.episodes += Array(allEpisodes[startIndex..<endIndex])
            self.hasMorePages = endIndex < allEpisodes.count
        } else {
            self.hasMorePages = false
        }
        isLoading = false
        print("✅ 加载更多剧集: 当前总数 \(self.episodes.count)")
    }
    
    func refreshEpisodes() {
        currentPage = 1
        loadEpisodes()
    }
    
    func selectEpisode(_ episode: Episode) {
        print("选择剧集: \(episode.localizedName)")
        selectedEpisode = episode
    }
} 
