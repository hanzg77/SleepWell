import Foundation
import Combine
import SwiftUI

class AudioLibraryViewModel: ObservableObject {
    @Published var resources: [Resource] = []
   
    @Published var selectedCategory: String = "全部"
    @Published var searchQuery: String = ""
    @Published var hasMorePages = true
    @Published var isLoading = false
    @Published var error: Error?
    @Published var showingResourceDetail = false
    @Published var selectedResource: Resource?
    
    let categories = ["全部", "白噪音", "冥想", "故事", "音乐", "自然"]
    
    private var currentPage = 1
    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?
    
    init() {
        loadResources()
    }
    
    func loadResources() {
        Task { @MainActor in
            await loadResources()
        }
    }
    
    @MainActor
    private func loadResources() async {
        isLoading = true
        error = nil
        
        NetworkManager.shared.fetchResources(
            page: currentPage,
            category: selectedCategory == "全部" ? nil : selectedCategory,
            searchQuery: searchQuery.isEmpty ? nil : searchQuery,
            forceRefresh: true
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] completion in
            self?.isLoading = false
            if case .failure(let error) = completion {
                print("❌ 加载资源失败: \(error)")
                self?.error = error
            } else {
                print("✅ 加载资源完成")
            }
        } receiveValue: { [weak self] resources in
            print("✅ 收到资源数据: \(resources.count) 个资源")
            for resource in resources {
                if let episodes = resource.episodes {
                    for episode in episodes {
                        print("episodeNumber:", episode.episodeNumber, "name:", episode.localizedName)
                    }
                }
            }
            self?.resources = resources
            self?.hasMorePages = !resources.isEmpty
        }
        .store(in: &cancellables)
    }
    
    func refreshResources() {
        Task { @MainActor in
            await loadResources()
        }
    }
    
    func searchResources(query: String) {
        searchTask?.cancel()
        
        guard !query.isEmpty else {
            loadResources()  // 清空搜索时重新加载所有资源
            return
        }
        
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms 延迟
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                self.searchQuery = query
                self.loadResources()
            }
        }
    }
    
    func selectResource(_ resource: Resource) {
        selectedResource = resource
        showingResourceDetail = true
    }
} 
