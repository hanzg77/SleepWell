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
    @EnvironmentObject private var audioManager: AudioManager
    @Binding var selectedTab: Int
    @State private var showEpisodeList = false
    @State private var guardianViewItem: GuardianViewItem?
    
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
                                await viewModel.refreshResources()
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
                                .onChange(of: viewModel.searchQuery) { newValue in
                                    viewModel.searchResources(query: newValue)
                                }
                            
                            // 分类按钮
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(viewModel.categories, id: \.self) { category in
                                        CategoryButton(
                                            title: category,
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
            .navigationBarTitle("音频库", displayMode: .inline)
            .refreshable {
                print("🔄 正在更新资源列表...")
                await viewModel.refreshResources()
            }
            .sheet(isPresented: $showEpisodeList) {
                if let resource = viewModel.selectedResource {
                    EpisodeListView(resource: resource, selectedTab: $selectedTab)
                        .environmentObject(audioManager)
                }
            }
            .sheet(item: $guardianViewItem) { item in
                if let resource = viewModel.selectedResource {
                    GuardianModeSelectionView(resource: resource, episode: nil, selectedTab: $selectedTab)
                        .environmentObject(GuardianManager.shared)
                        .environmentObject(AudioManager.shared)
                        .presentationDetents([.medium])
                }
            }
        }
    }
    
    private func handleResourceTap(_ resource: Resource) {
        print("资源被点击: \(resource.name)")
        if resource.resourceType == .singleTrackAlbum {
            // 单集资源显示守护模式选择界面
            print("是单集资源，准备显示守护模式选择界面")
            viewModel.selectedResource = resource
            guardianViewItem = GuardianViewItem()
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
            
            TextField(Constants.Text.searchPlaceholder, text: $text)
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
    @EnvironmentObject private var audioManager: AudioManager

    var body: some View {
        Button(action: {
            onTap()
        }) {
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
                        .foregroundColor(.white)
                    
                    Text(resource.description)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(2)
                    
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                            Text("\(resource.globalPlaybackCount)")
                        }
                        .foregroundColor(.gray)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: "list.bullet")
                            Text(resource.resourceType == .tracklistAlbum ? "\(resource.episodeCount)个音轨" : "\(resource.episodeCount)集")
                        }
                        .foregroundColor(.gray)
                    }
                    .font(.caption)
                }
                .padding()
                .background(Color(red: 0.1, green: 0.1, blue: 0.1))
                
                // 播放进度条（仅对单集资源显示）
                if resource.isSingleEpisode {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 2)
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: geometry.size.width * CGFloat(audioManager.getPlayProgress(for: resource)), height: 2)
                        }
                    }
                    .frame(height: 2)
                }
            }
            .background(Color(red: 0.1, green: 0.1, blue: 0.1))
            .cornerRadius(12)
            .shadow(radius: 5)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            loadImage()
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
        .environmentObject(AudioManager.shared)
        .environmentObject(GuardianManager.shared)
} 
