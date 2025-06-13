import Foundation
import Combine
import SwiftUI

class AudioLibraryViewModel: ObservableObject {
    @Published var resources: [Resource] = []
    @Published var resourceProgresses: [String: Double] = [:]
    @Published var selectedCategory: String = "全部"
    @Published var searchQuery: String = ""
    @Published var hasMorePages = true
    @Published var isLoading = false
    @Published var error: Error?
    @Published var showingResourceDetail = false
    @Published var selectedResource: Resource?
    
    let categories = ["全部", "白噪声", "冥想", "故事", "音乐", "自然"]
    
    // 获取所有可用的标签
    var availableTags: [String] {
        Array(Set(resources.flatMap { $0.tags })).sorted()
    }
    
    // 根据选中的标签过滤资源
    func filteredResources(selectedTags: Set<String>) -> [Resource] {
        if selectedTags.isEmpty {
            return resources
        }
        return resources.filter { resource in
            !Set(resource.tags).isDisjoint(with: selectedTags)
        }
    }
    
    private var currentPage = 1
    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?
    
    init() {
        NetworkManager.shared.$resources
            .receive(on: DispatchQueue.main)
            .sink { [weak self] resources in
                print("AudioLibraryViewModel 收到的资源：", resources.count)
                self?.resources = resources
                self?.isLoading = false
                // 批量获取进度
                self?.resourceProgresses = PlaybackProgressManager.shared.getProgresses(
                    for: resources.map { $0.resourceId }
                )
            }
            .store(in: &cancellables)
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

        NetworkManager.shared.refreshResources(
            pageSize: 20,
            category: selectedCategory == "全部" ? nil : selectedCategory,
            searchQuery: searchQuery.isEmpty ? nil : searchQuery
        )
    }
    
    func refreshResources() {
        Task { @MainActor in
            await loadResources()
        }
    }
    
    func refreshProgresses() {
        resourceProgresses = PlaybackProgressManager.shared.getProgresses(
            for: resources.map { $0.resourceId }
        )
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
    
    // 删除资源
    func deleteResource(_ resource: Resource) {
        Task { @MainActor in
            do {
                print("🗑️ 开始删除资源: \(resource.name) (ID: \(resource.resourceId))")
                let response = try await NetworkManager.shared.deleteResource(resourceId: resource.resourceId)
                print("📦 服务端返回内容: \(response)")
                
                if response.success {
                    // 从本地列表中移除
                    resources.removeAll { $0.id == resource.id }
                    print("📋 从本地列表中移除资源")
                } else {
                    print("❌ 删除失败: \(response.message)")
                    self.error = NetworkError.serverError(response.message)
                }
            } catch {
                print("❌ 删除资源失败: \(error)")
                self.error = error
            }
        }
    }
} 
