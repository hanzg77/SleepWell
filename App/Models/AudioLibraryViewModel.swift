import Foundation
import Combine
import SwiftUI

class AudioLibraryViewModel: ObservableObject {
    @Published var resources: [Resource] = []
    @Published var resourceProgresses: [String: Double] = [:]
    @Published var selectedCategory: String = "all" { // 1. 统一使用 "all" 作为默认/全部的键
        didSet {
            // 追踪 selectedCategory 的变化
            print("AudioLibraryViewModel: selectedCategory DID SET to '\(selectedCategory)'. Old value was '\(oldValue)'")
        }
    }
    @Published var searchQuery: String = ""
    @Published var hasMorePages = true
    @Published var isLoading = false
    @Published var error: Error?
    @Published var showingResourceDetail = false
    @Published var selectedResource: Resource?
    
    let categories = ["all", "white_noise", "meditation", "story", "music", "nature"]
    
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
        // 追踪 public loadResources 的调用
        print("AudioLibraryViewModel: public loadResources() CALLED.")
        Task { @MainActor in
            await loadResources()
        }
    }
    
    @MainActor
    private func loadResources() async {
        // 追踪 private async loadResources 的开始及其状态
        print("AudioLibraryViewModel: private async loadResources() STARTED. Current selectedCategory: '\(selectedCategory)', searchQuery: '\(searchQuery)', isLoading: \(isLoading)")

        // 防止在已加载时重复执行核心逻辑
        // isLoading 应该在实际开始网络请求前，且在 guard 之后设置，以准确反映状态。
        // 但为了防止因快速连续调用 public loadResources() 导致多个 Task 执行此块，
        // 这里的 isLoading 检查仍然有用。
        isLoading = true
        error = nil

        let categoryParam = selectedCategory == "all" ? nil : selectedCategory // 2. 统一使用 "all" 进行比较
        let searchQueryParam = searchQuery.isEmpty ? nil : searchQuery
        
        print("AudioLibraryViewModel: Preparing to call NetworkManager.refreshResources with category: '\(categoryParam ?? "nil")', search: '\(searchQueryParam ?? "nil")'")

        NetworkManager.shared.refreshResources(pageSize: 20, category: categoryParam, searchQuery: searchQueryParam)
    }
    
    func refreshResources() {
        print("AudioLibraryViewModel: refreshResources() CALLED.")
        Task { @MainActor in
            await loadResources()
        }
    }
    
    func refreshProgresses() {
        resourceProgresses = PlaybackProgressManager.shared.getProgresses(
            for: resources.map { $0.resourceId }
        )
    }
    
    // Renamed and modified to use the ViewModel's searchQuery property directly
    func triggerSearch() {
        searchTask?.cancel()
        
        // self.searchQuery is updated by the TextField binding via AudioLibraryView
        guard !self.searchQuery.isEmpty else {
            print("AudioLibraryViewModel: Search query is empty. Loading resources without search term.")
            loadResources()  // 清空搜索时重新加载所有资源
            return
        }
        
        print("AudioLibraryViewModel: Scheduling search for query: '\(self.searchQuery)'")
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms 延迟
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                print("AudioLibraryViewModel: Debounced search executing for query: '\(self.searchQuery)'")
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
