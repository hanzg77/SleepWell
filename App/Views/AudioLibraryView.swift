import SwiftUI
import Combine

// MARK: - 常量
private enum Constants {
    enum Colors {
        static let background = Color.black
        static let searchBarBackground = Color(white: 0.15)
        static let resourceRowBackground = Color(white: 0.12)
        static let categoryUnselected = Color(white: 0.2)
        static let textPrimary = Color.white
        static let textSecondary = Color.gray
        static let accent = Color.blue
    }
    
    enum Layout {
        static let spacing: CGFloat = 16
        static let cornerRadius: CGFloat = 16
        static let searchBarHeight: CGFloat = 44
        static let categoryButtonHeight: CGFloat = 36
    }
}

// MARK: - AudioLibraryView
struct AudioLibraryView: View {
    // MARK: - 屬性
    @StateObject private var viewModel = AudioLibraryViewModel()
    @StateObject private var playerController = DualStreamPlayerController.shared
    @Binding var selectedTab: Int
    @State private var showEpisodeList = false
    @State private var showAdminView = false
    @State private var selectedResource: Resource?
    
    // 用於智慧型 Header 的狀態變數
    @State private var headerHeight: CGFloat = 0
    @State private var headerOffset: CGFloat = 0
    @State private var lastScrollOffset: CGFloat = 0

    var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                Color.black.edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    GeometryReader { proxy -> Color in
                        let currentOffset = proxy.frame(in: .global).minY
                        DispatchQueue.main.async {
                            self.updateHeaderOffset(currentOffset: currentOffset)
                        }
                        return Color.clear
                    }
                    .frame(height: 0)
                    
                    VStack(spacing: 0) {
                        contentView
                    }
                    .padding(.top, headerHeight)
                }
                .refreshable {
                    print("🔄 正在更新資源列表...")
                    viewModel.refreshResources()
                }

                HeaderView(
                    searchQuery: $viewModel.searchQuery,
                    categories: viewModel.categories,
                    selectedCategory: $viewModel.selectedCategory,
                    onSearch: { viewModel.loadResources() }
                )
                .readSize { size in
                    if self.headerHeight == 0 {
                        self.headerHeight = size.height
                    }
                }
                .offset(y: headerOffset)
            }
            .edgesIgnoringSafeArea(.top)
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
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Header 位移計算邏輯
    private func updateHeaderOffset(currentOffset: CGFloat) {
        if currentOffset > 0 {
            self.headerOffset = currentOffset
            self.lastScrollOffset = 0
            return
        }

        let delta = currentOffset - self.lastScrollOffset
        var newOffset = self.headerOffset + delta
        newOffset = max(-self.headerHeight, newOffset)
        newOffset = min(0, newOffset)
        self.headerOffset = newOffset
        self.lastScrollOffset = currentOffset
    }

    // MARK: - 子视图和事件处理
    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading {
            ProgressView()
                .scaleEffect(1.5)
                .frame(maxWidth: .infinity)
                .padding(.top, 100)
        } else if viewModel.resources.isEmpty {
            emptyStateView
                .padding(.top, 100)
        } else {
            LazyVStack(spacing: 24) {
                ForEach(viewModel.resources) { resource in
                    ResourceCard(resource: resource, onTap: {
                        handleResourceTap(resource)
                    }, viewModel: viewModel)
                }
            }
            .padding()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(Constants.Colors.textSecondary)
            Text("library.empty".localized)
                .font(.headline)
                .foregroundColor(Constants.Colors.textSecondary)
            Button(action: { Task { viewModel.refreshResources() } }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("library.retry".localized)
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Constants.Colors.accent)
                .cornerRadius(24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handleResourceTap(_ resource: Resource) {
        print("资源被点击: \(resource.name)")
        viewModel.selectedResource = resource
        if resource.resourceType == .singleTrackAlbum {
            print("是单集资源，直接播放")
            PlaylistController.shared.setPlaylist([resource])
            PlaylistController.shared.play(resource)
            GuardianController.shared.enableGuardianMode(GuardianController.shared.currentMode)
            selectedTab = 1
        } else {
            print("是多集资源或 tracklist 资源，准备显示剧集列表")
            showEpisodeList = true
        }
    }
}


// MARK: - HeaderView (浮動的Header)
struct HeaderView: View {
    @Binding var searchQuery: String
    let categories: [String]
    @Binding var selectedCategory: String
    let onSearch: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Text("library.title".localized)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, (UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0) + 10)
                .padding(.bottom, 12)
            
            SearchBar(text: $searchQuery, onSearch: onSearch)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(categories, id: \.self) { category in
                        CategoryButton(
                            title: "category.\(category.lowercased())".localized,
                            isSelected: category == selectedCategory
                        ) {
                            searchQuery = ""
                            selectedCategory = category
                            onSearch()
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
        }
        .background(Constants.Colors.background.edgesIgnoringSafeArea(.top))
    }
}

// MARK: - 搜索栏
struct SearchBar: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    let onSearch: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Constants.Colors.textSecondary)
            
            TextField("搜索", text: $text)
                .foregroundColor(Constants.Colors.textPrimary)
                .focused($isFocused)
                .submitLabel(.search)
                .onSubmit(onSearch)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                    onSearch()
                    isFocused = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Constants.Colors.textSecondary)
                }
            }
        }
        .padding(12)
        .background(Constants.Colors.searchBarBackground)
        .cornerRadius(Constants.Layout.cornerRadius)
        .padding(.horizontal)
    }
}

// MARK: - 分类按钮
struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 16)
                .frame(height: Constants.Layout.categoryButtonHeight)
                .background(isSelected ? .white : Constants.Colors.categoryUnselected)
                .cornerRadius(Constants.Layout.categoryButtonHeight / 2)
        }
    }
}


// MARK: - 资源卡片
struct ResourceCard: View {
    let resource: Resource
    let onTap: () -> Void
    @StateObject private var imageLoader = ImageLoader()
    @StateObject private var playerController = DualStreamPlayerController.shared
    @ObservedObject var viewModel: AudioLibraryViewModel
    @State private var showAdminView = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottom) {
                    coverImage
                    if let progress = viewModel.resourceProgresses[resource.resourceId] {
                        progressOverlay(progress: progress)
                    }
                    if playerController.currentResource?.resourceId == resource.resourceId && playerController.isPlaying {
                        playingIndicator
                    }
                }
                .aspectRatio(16/9, contentMode: .fill)
                .cornerRadius(Constants.Layout.cornerRadius)
                .clipped()
                
                VStack(alignment: .leading, spacing: 10) {
                    Text(resource.name)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(Constants.Colors.textPrimary)
                        .lineLimit(2)
                        .onLongPressGesture { showAdminView = true }
                    
                    if !resource.tags.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(resource.tags, id: \.self) { tag in
                                TagView(text: "category.\(tag)".localized)
                            }
                        }
                        .frame(maxHeight: 50, alignment: .top)
                        .clipped()
                    }
                }
                .padding()
            }
            .background(Constants.Colors.resourceRowBackground)
            .cornerRadius(Constants.Layout.cornerRadius)
            .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            imageLoader.loadImage(from: resource.coverImageUrl)
        }
        .sheet(isPresented: $showAdminView) {
            AdminView(resource: resource)
        }
    }
    
    // MARK: ResourceCard 的子视图
    @ViewBuilder
    private var coverImage: some View {
        if let image = imageLoader.image {
            Image(uiImage: image)
                .resizable()
                .transition(.opacity.animation(.easeInOut))
        } else {
            Rectangle()
                .fill(Constants.Colors.searchBarBackground)
                .overlay {
                    if imageLoader.isLoading { ProgressView() }
                }
        }
    }
    
    private func progressOverlay(progress: Double) -> some View {
        VStack {
            Spacer()
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, .black.opacity(0.8)], startPoint: .top, endPoint: .bottom))
                    .frame(height: 50)
                ProgressView(value: progress, total: Double(resource.totalDurationSeconds))
                    .progressViewStyle(LinearProgressViewStyle())
                    .tint(Constants.Colors.accent)
                    .padding()
            }
        }
    }
    
    private var playingIndicator: some View {
        HStack {
            Spacer()
            VStack {
                Image(systemName: "headphones")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                Spacer()
            }
        }
        .padding(8)
    }
}

// MARK: - 标签视图
struct TagView: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Constants.Colors.accent.opacity(0.2))
            .foregroundColor(Constants.Colors.accent)
            .cornerRadius(8)
    }
}

// MARK: - FlowLayout 自动换行布局 (需要 iOS 16+)
struct FlowLayout: Layout {
    var spacing: CGFloat
    
    init(spacing: CGFloat) {
        self.spacing = spacing
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        let rows = generateRows(maxWidth: width, subviews: subviews)
        
        let height = rows.map { $0.maxHeight }.reduce(0, +) + CGFloat(max(0, rows.count - 1)) * spacing
        
        return CGSize(width: width, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = generateRows(maxWidth: bounds.width, subviews: subviews)
        var origin = bounds.origin
        
        for row in rows {
            origin.x = bounds.origin.x
            for view in row.views {
                // 修正 #1：明确指定 ProposedViewSize.unspecified
                let viewSize = view.sizeThatFits(ProposedViewSize.unspecified)
                view.place(at: origin, proposal: .unspecified)
                origin.x += viewSize.width + spacing
            }
            origin.y += row.maxHeight + spacing
        }
    }
    
    private func generateRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentRow = Row()
        
        for view in subviews {
            // 修正 #2：明确指定 ProposedViewSize.unspecified
            let viewSize = view.sizeThatFits(ProposedViewSize.unspecified)
            
            if currentRow.width + viewSize.width + (currentRow.views.isEmpty ? 0 : spacing) <= maxWidth {
                currentRow.views.append(view)
                currentRow.width += viewSize.width + (currentRow.views.isEmpty ? 0 : spacing)
                currentRow.maxHeight = max(currentRow.maxHeight, viewSize.height)
            } else {
                rows.append(currentRow)
                currentRow = Row(views: [view], width: viewSize.width, maxHeight: viewSize.height)
            }
        }
        
        if !currentRow.views.isEmpty {
            rows.append(currentRow)
        }
        
        return rows
    }
    
    // 辅助结构体：代表布局中的“一行”
    private struct Row {
        // 修正 #3：使用正确的 'Layout.Subviews.Element' 类型
        var views: [Layout.Subviews.Element] = []
        var width: CGFloat = 0
        var maxHeight: CGFloat = 0
    }
}


// MARK: - 辅助工具：图片加载器
class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    private var cancellable: AnyCancellable?
    
    func loadImage(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        isLoading = true
        cancellable = URLSession.shared.dataTaskPublisher(for: url)
            .map { UIImage(data: $0.data) }
            .replaceError(with: nil)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loadedImage in
                self?.image = loadedImage
                self?.isLoading = false
            }
    }
}

// MARK: - 辅助工具：读取视图尺寸
struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {}
}

extension View {
    func readSize(onChange: @escaping (CGSize) -> Void) -> some View {
        background(
            GeometryReader { geometryProxy in
                Color.clear
                    .preference(key: SizePreferenceKey.self, value: geometryProxy.size)
            }
        )
        .onPreferenceChange(SizePreferenceKey.self, perform: onChange)
    }
}


// MARK: - 预览
#Preview {
    AudioLibraryView(selectedTab: .constant(0))
        .preferredColorScheme(.dark)
}
