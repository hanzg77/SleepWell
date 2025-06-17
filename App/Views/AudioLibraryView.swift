import SwiftUI
import Combine

// MARK: - Constants
private enum Constants {
    enum Colors {
        static let background = Color.black
        static let searchBarBackground = Color(white: 0.2)
        static let resourceRowBackground = Color(white: 0.1)
        static let textPrimary = Color.white
        static let textSecondary = Color.gray
    }
    
    enum Layout {
        static let spacing: CGFloat = 16
        static let cornerRadius: CGFloat = 12
        static let searchBarHeight: CGFloat = 44
        static let categoryButtonHeight: CGFloat = 36
        static let resourceImageSize: CGFloat = 80
    }
    
    enum Text {
        static let searchPlaceholder = "搜索"
        static let emptyEpisodes = "暂无剧集"
        static let episodeCount = "%d 集"
    }
}

// MARK: - AudioLibraryView
struct AudioLibraryView: View {
    @StateObject private var viewModel = AudioLibraryViewModel()
    @StateObject private var playerController = DualStreamPlayerController.shared
    @Binding var selectedTab: Int
    @State private var showEpisodeList = false
    @State private var guardianViewItem: GuardianViewItem?
    @State private var guardianModeViewModel: GuardianModeSelectionViewModel?
    @State private var showAdminView = false
    @State private var selectedResource: Resource?
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                Color.black.edgesIgnoringSafeArea(.all)
                
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else if let error = viewModel.error {
                    VStack(spacing: 16) {
                        Text("加载失败")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(error.localizedDescription)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: {
                            Task {
                                viewModel.refreshResources()
                            }
                        }) {
                            Text("重试")
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .cornerRadius(20)
                        }
                    }
                } else {
                    ScrollView {
                        VStack(spacing: Constants.Layout.spacing) {
                            // 搜索栏
                            SearchBar(text: $viewModel.searchQuery)
                            
                            // 分类按钮
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(viewModel.categories, id: \.self) { category in
                                        CategoryButton(
                                            title: "category.\(category.lowercased())".localized,
                                            isSelected: category == viewModel.selectedCategory
                                        ) {
                                            viewModel.selectedCategory = category
                                            viewModel.loadResources()
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                            // 资源列表
                            if viewModel.isLoading {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .padding(.top, 100)
                            } else if viewModel.resources.isEmpty {
                                VStack(spacing: 20) {
                                    Image(systemName: "music.note.list")
                                        .font(.system(size: 60))
                                        .foregroundColor(Constants.Colors.textSecondary)
                                    
                                    Text("library.empty".localized)
                                        .font(.headline)
                                        .foregroundColor(Constants.Colors.textSecondary)
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(.top, 100)
                            } else {
                                LazyVStack(spacing: 20) {
                                    ForEach(viewModel.resources) { resource in
                                        ResourceCard(resource: resource) {
                                            handleResourceTap(resource)
                                        }
                                    }
                                }
                                .padding()
                            }
                        }
                    }
                }
            }
            .refreshable {
                print("🔄 正在更新资源列表...")
                viewModel.refreshResources()
            }
            .sheet(isPresented: $showEpisodeList) {
                if let resource = viewModel.selectedResource {
                    EpisodeListView(resource: resource, selectedTab: $selectedTab)
                }
            }
            .sheet(isPresented: $showAdminView) {
                if let resource = selectedResource {
                    AdminView(resource: resource)
                }
            }
            .navigationTitle("library.title".localized)
            // 移除了 guardianViewItem 的 sheet
        }
    }
    
    private func handleResourceTap(_ resource: Resource) {
        print("资源被点击: \(resource.name)")
        viewModel.selectedResource = resource // 确保 selectedResource 被设置
        if resource.resourceType == .singleTrackAlbum {
            // 单集资源直接播放
            print("是单集资源，直接播放")
            PlaylistController.shared.setPlaylist([resource])
            PlaylistController.shared.play(resource)
            // 使用 GuardianController 当前的模式（默认或上次选择的）
            GuardianController.shared.enableGuardianMode(GuardianController.shared.currentMode)
            selectedTab = 1 // 切换到播放页面
        } else {
            // 多集资源或 tracklist 资源显示剧集列表
            print("是多集资源或 tracklist 资源，准备显示剧集列表")
            viewModel.selectedResource = resource
            showEpisodeList = true
        }
    }
}

// MARK: - SearchBar
struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Constants.Colors.textSecondary)
            
            TextField("library.search.placeholder".localized, text: $text)
                .foregroundColor(Constants.Colors.textPrimary)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Constants.Colors.textSecondary)
                }
            }
        }
        .padding(8)
        .background(Constants.Colors.searchBarBackground)
        .cornerRadius(Constants.Layout.cornerRadius)
        .padding(.horizontal)
    }
}

// MARK: - CategoryButton
struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? Constants.Colors.background : Constants.Colors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Constants.Colors.textPrimary : Color.clear)
                .cornerRadius(Constants.Layout.categoryButtonHeight / 2)
                .overlay(
                    RoundedRectangle(cornerRadius: Constants.Layout.categoryButtonHeight / 2)
                        .stroke(Constants.Colors.textPrimary, lineWidth: 1)
                )
        }
    }
}

// MARK: - ResourceCard
struct ResourceCard: View {
    let resource: Resource
    let onTap: () -> Void
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var loadError = false
    @StateObject private var playerController = DualStreamPlayerController.shared
    @State private var showActionSheet = false
    @StateObject private var viewModel = AudioLibraryViewModel()
    @State private var showDeleteAlert = false
    @State private var showAdminView = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // 封面图
                ZStack {
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if loadError {
                        Color.gray.opacity(0.2)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            )
                    } else {
                        Color.gray.opacity(0.2)
                    }
                    
                    if isLoading {
                        ProgressView()
                    }
                }
                .frame(height: 200)
                .clipped()
                
                // 资源信息
                VStack(alignment: .leading, spacing: 8) {
                    Text(resource.name)
                        .font(.headline)
                        .lineLimit(1)
                        .onLongPressGesture {
                            showAdminView = true
                        }
                    
                    // 标签列表
                    if !resource.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(resource.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                    
                    // 添加进度条
                    if let progress = viewModel.resourceProgresses[resource.resourceId] {
                        ProgressView(value: progress, total: Double(resource.totalDurationSeconds))
                            .progressViewStyle(LinearProgressViewStyle())
                            .tint(.blue)
                    }
                }
                .padding()
                .background(Constants.Colors.resourceRowBackground)
            }
            .cornerRadius(Constants.Layout.cornerRadius)
            .shadow(radius: 5)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            loadImage()
        }
        .confirmationDialog("管理资源", isPresented: $showActionSheet) {
            Button("删除资源", role: .destructive) {
                showDeleteAlert = true
            }
            
            Button("添加标签") {
                // TODO: 实现添加标签功能
            }
            
            Button("设置 Rank 值") {
                // TODO: 实现设置 Rank 值功能
            }
            
            Button("取消", role: .cancel) {}
        } message: {
            Text(resource.name)
        }
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                viewModel.deleteResource(resource)
            }
        } message: {
            Text("确定要删除{resource.name}吗？此操作不可撤销。")
        }
        .sheet(isPresented: $showAdminView) {
            AdminView(resource: resource)
        }
    }
    
    private func loadImage() {
        guard let url = URL(string: resource.coverImageUrl) else {
            print("❌ 无效的封面图片URL: \(resource.coverImageUrl)")
            DispatchQueue.main.async {
                self.isLoading = false
                self.loadError = true
            }
            return
        }
        
        print("📸 开始加载封面图片: \(url)")
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ 加载封面图片失败: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.loadError = true
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 封面图片响应状态码: \(httpResponse.statusCode)")
            }
            
            if let data = data, let image = UIImage(data: data) {
                print("✅ 成功加载封面图片")
                DispatchQueue.main.async {
                    self.image = image
                    self.isLoading = false
                }
            } else {
                print("❌ 无法从数据创建图片")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.loadError = true
                }
            }
        }.resume()
    }
}

// MARK: - Preview
#Preview {
    AudioLibraryView(selectedTab: .constant(0))
        .environmentObject(GuardianController.shared)
} 
