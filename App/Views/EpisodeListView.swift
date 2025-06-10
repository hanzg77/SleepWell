import SwiftUI
import Combine

struct EpisodeListView: View {
    let resource: Resource
    @StateObject private var viewModel: EpisodeListViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isRefreshing = false
    @State private var selectedEpisode: Episode?
    @Binding var selectedTab: Int
    @State private var guardianModeItem: GuardianModeItem?
    @State private var showingGuardianModeSelection = false
    @State private var selectModel: GuardianModeSelectionViewModel?
    @EnvironmentObject private var guardianManager: GuardianController
    
    init(resource: Resource, selectedTab: Binding<Int>) {
        self.resource = resource
        self._selectedTab = selectedTab
        _viewModel = StateObject(wrappedValue: EpisodeListViewModel(resource: resource))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                Color.black.edgesIgnoringSafeArea(.all)
                
                if viewModel.isLoading && viewModel.episodes.isEmpty {
                    // 首次加载状态
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.error {
                    // 错误状态
                    VStack(spacing: 16) {
                        Text("加载失败")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(error.localizedDescription)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: {
                            viewModel.refreshEpisodes()
                        }) {
                            Text("重试")
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .cornerRadius(20)
                        }
                    }
                } else if viewModel.episodes.isEmpty {
                    // 空状态
                    VStack(spacing: 16) {
                        Text("暂无剧集")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Button(action: {
                            viewModel.refreshEpisodes()
                        }) {
                            Text("刷新")
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .cornerRadius(20)
                        }
                    }
                } else {
                    // 列表内容
                    List {
                        // 资源信息头部
                        ResourceHeaderView(resource: resource)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.black)
                        
                        // 剧集列表
                        ForEach(viewModel.episodes) { episode in
                            EpisodeRow(episode: episode) {
                                selectedEpisode = episode
                                guardianModeItem = GuardianModeItem()
                            }
                            .id(episode.id)
                            .listRowBackground(Color.black)
                        }
                        
                        if viewModel.hasMorePages {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .listRowBackground(Color.black)
                                .onAppear {
                                    viewModel.loadMoreEpisodes()
                                }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .background(Color.black)
                    .scrollContentBackground(.hidden)
                    .refreshable {
                        isRefreshing = true
                        viewModel.refreshEpisodes()
                        isRefreshing = false
                    }
                    .onAppear {
                        // 确保在视图出现时加载数据
                        if viewModel.episodes.isEmpty {
                            viewModel.loadEpisodes()
                        }
                    }
                }
            }
            .navigationBarTitle(resource.name, displayMode: .inline)
            .sheet(item: $guardianModeItem) { _ in
                GuardianModeSelectionView(resource: resource, episode: selectedEpisode, selectedTab: $selectedTab)
                    .environmentObject(GuardianController.shared)
                    .presentationDetents([.medium])
                    .onDisappear {
                        // 在守护模式选择界面消失后再关闭当前视图
                        dismiss()
                    }
            }
        }
    }
    
    private func showGuardianModeSelection(for episode: Episode) {
        selectedEpisode = episode
        selectModel = GuardianModeSelectionViewModel(
            resource: resource,
            episode: episode,
            guardianManager: GuardianController.shared
        )
        showingGuardianModeSelection = true
    }
}

struct ResourceHeaderView: View {
    let resource: Resource
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var loadError = false
    @State private var isDescriptionExpanded = false
    
    var body: some View {
        VStack(spacing: 16) {
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
            .onAppear {
                loadImage()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(resource.name)
                    .font(.title2)
                    .bold()
                    .foregroundColor(.white)
                
                ZStack(alignment: .bottomTrailing) {
                    Text(resource.description)
                        .font(.body)
                        .foregroundColor(.white)
                        .lineLimit(isDescriptionExpanded ? nil : 3)
                        .animation(.easeInOut, value: isDescriptionExpanded)
                        .padding(.trailing, 32)
                    HStack {
                        Spacer()
                        Button(action: {
                            isDescriptionExpanded.toggle()
                        }) {
                            Image(systemName: isDescriptionExpanded ? "chevron.up" : "chevron.down")
                                .foregroundColor(.white)
                        }
                        .padding(.trailing, 4)
                        .padding(.bottom, 2)
                    }
                }
                
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                        Text("\(resource.globalPlaybackCount)")
                    }
                    .foregroundColor(.white)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet")
                        Text(resource.resourceType == .tracklistAlbum ? "\(resource.episodeCount)个音轨" : "\(resource.episodeCount)集")
                    }
                    .foregroundColor(.white)
                }
                .font(.caption)
            }
            .padding(.horizontal)
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

struct EpisodeRow: View {
    let episode: Episode
    let onTap: () -> Void
    
    var body: some View {
        Button(action: {
            onTap()
        }) {
            HStack(spacing: 12) {
                // 集数标记
                Text("\(episode.episodeNumber)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(episode.localizedName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    if let description = episode.localizedDescription, !description.isEmpty {
                        Text(description)
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .lineLimit(2)
                    }
                    
                    // 如果是 tracklist 类型，显示时间范围
                    if let startTime = episode.startTime, let endTime = episode.endTime {
                        Text("\(formatTime(startTime)) - \(formatTime(endTime))")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color.black)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

// 用于 sheet 的标识符
struct GuardianModeItem: Identifiable {
    let id = UUID()
}


