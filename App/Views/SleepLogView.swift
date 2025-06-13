import SwiftUI
import Combine

// MARK: - 主视图：睡眠日志 (SleepLogView)
// 注释：顶层视图保持简洁，只负责组合子视图和传递必要的状态。
struct SleepLogView: View {
    // MARK: - Properties
    @StateObject private var logManager = SleepLogManager.shared
    @StateObject private var playerController = DualStreamPlayerController.shared
    @StateObject private var networkManager = NetworkManager.shared
    @Binding var selectedTab: Int
    
    // UI 状态
    @State private var showingNotesDetail = false
    @State private var selectedLog: DailySleepLog?

    // MARK: - Body
    var body: some View {
        // STYLE: 使用 NavigationStack 以获得更现代的导航行为。
        // 如果您需要支持旧版 iOS，可以换回 NavigationView。
        NavigationStack {
            SleepLogContentView(
                logManager: logManager,
                playerController: playerController,
                networkManager: networkManager,
                selectedTab: $selectedTab,
                showingNotesDetail: $showingNotesDetail,
                selectedLog: $selectedLog,
                onCardTap: { dailyLog in
                    selectedLog = dailyLog
                    showingNotesDetail = true
                }
            )
        }
        // STYLE: 将 .sheet 和 .task 修饰符放在 NavigationStack 外层，结构更清晰。
        .sheet(isPresented: $showingNotesDetail) {
            if let log = selectedLog {
                // STYLE: 为了让 Sheet 有自己的标题和关闭按钮，内部需要 NavigationStack
                NotesDetailView(log: log)
            }
        }
        .task {
            logManager.loadLogs()
        }
    }
}

// MARK: - 内容视图：日志列表 (SleepLogContentView)
// 注释：将主要 UI 布局放在这个子视图中，让主视图保持干净。
struct SleepLogContentView: View {
    // MARK: - Properties
    @ObservedObject var logManager: SleepLogManager
    @ObservedObject var playerController: DualStreamPlayerController
    @ObservedObject var networkManager: NetworkManager
    @Binding var selectedTab: Int
    @Binding var showingNotesDetail: Bool
    @Binding var selectedLog: DailySleepLog?
    let onCardTap: (DailySleepLog) -> Void
    @State private var cancellables = Set<AnyCancellable>()
    @State private var showingGuardianModeSheet = false
    @State private var selectedEntry: SleepEntry?
    @State private var selectedResource: Resource?
    @State private var isLoadingResource = false
    @State private var resourceLoadError: Error?

    // MARK: - Body
    var body: some View {
        ZStack {
            // STYLE: 使用深色渐变背景取代纯黑，增加视觉深度。
            LinearGradient(
                gradient: Gradient(colors: [Color.gray.opacity(0.2), Color.black]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)

            // STYLE: 使用 if-let 来优雅地处理空状态。
            if logManager.dailyLogs.isEmpty {
                emptyStateView
            } else {
                logListView
            }
        }
        .navigationTitle("睡眠日记")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                RefreshButton(logManager: logManager)
            }
        }
        // STYLE: 让工具栏背景也呈现透明模糊效果，与App风格统一。
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(.black.opacity(0.3), for: .navigationBar)
        .sheet(isPresented: $showingGuardianModeSheet) {
            if let resource = selectedResource {
                GuardianModeSelectionView(
                    resource: resource,
                    episode: nil,
                    selectedTab: $selectedTab,
                    onModeSelected: { mode in
                        // 设置新的播放列表（只包含当前资源）
                        PlaylistController.shared.setPlaylist([resource])
                        // 播放当前资源
                        PlaylistController.shared.play(resource)
                    }
                )
                .environmentObject(GuardianController.shared)
                .presentationDetents([.medium])
            } else if isLoadingResource {
                VStack {
                    ProgressView()
                    Text("正在加载资源...")
                        .foregroundColor(.secondary)
                }
                .presentationDetents([.medium])
            } else if resourceLoadError != nil {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text("资源加载失败")
                        .foregroundColor(.secondary)
                }
                .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Subviews
    private var logListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // STYLE: LazyVStack 的间距稍微拉大，让卡片更有呼吸感。
                LazyVStack(spacing: 24) {
                    ForEach(logManager.dailyLogs) { dailyLog in
                        DailyLogCardView(log: dailyLog, entries: dailyLog.entries, onNotesTapped: {
                            selectedLog = dailyLog
                            showingNotesDetail = true
                        }, onEntryTapped: { entry in
                            // 点击单条守护记录时
                            fetchResourceAndShowSheet(for: entry)
                        })
                        .id(dailyLog.id)  // 添加 id 用于滚动定位
                        .onTapGesture {
                            onCardTap(dailyLog)
                        }
                    }
                }
                // STYLE: 给予垂直和水平的 padding。
                .padding(.vertical)
                .padding(.horizontal)
            }
            .onChange(of: logManager.dailyLogs) { _ in
                // 当日志更新时，滚动到最新的日志
                if let latestLog = logManager.dailyLogs.first {
                    withAnimation {
                        proxy.scrollTo(latestLog.id, anchor: .top)
                    }
                }
            }
            .onAppear {
                // 视图出现时，滚动到最新的日志
                if let latestLog = logManager.dailyLogs.first {
                    withAnimation {
                        proxy.scrollTo(latestLog.id, anchor: .top)
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("还没有睡眠记录")
                .font(.title3)
                .foregroundColor(.secondary)
            Text("创造你的第一笔日志吧。")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // 修改获取资源的方法
    private func fetchResourceAndShowSheet(for entry: SleepEntry) {
        guard let resourceID = entry.resourceID else { return }
        isLoadingResource = true
        resourceLoadError = nil
        selectedResource = nil
        selectedEntry = entry
        showingGuardianModeSheet = true
        
        NetworkManager.shared.fetchResource(resourceId: resourceID)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                self.isLoadingResource = false
                if case .failure(let error) = completion {
                    self.resourceLoadError = error
                }
            } receiveValue: { resource in
                self.selectedResource = resource
            }
            .store(in: &cancellables)
    }
}


// MARK: - 刷新按钮 (RefreshButton)
private struct RefreshButton: View {
    @ObservedObject var logManager: SleepLogManager

    var body: some View {
        Button(action: {
            logManager.loadLogs()
        }) {
            Image(systemName: "arrow.clockwise")
                // STYLE: 使用 .primary 语义化颜色，在不同模式下表现更好。
                .foregroundColor(.primary)
        }
    }
}


// MARK: - 每日日志卡片 (DailyLogCardView)
// 注释：这是视觉设计的核心，在这里进行了最多的美化。
struct DailyLogCardView: View {
    let log: DailySleepLog
    let entries: [SleepEntry]
    var onNotesTapped: () -> Void
    var onEntryTapped: (SleepEntry) -> Void = { _ in }

    // 日记功能相关状态
    @State private var showingMoodBanner: Bool = false
    @State private var selectedMood: Mood? = nil
    @State private var showingJournalEntry: Bool = false

    var body: some View {
        // [优化] VStack 的主间距由子视图的 padding 控制，更具灵活性
        VStack(alignment: .leading, spacing: 0) {

            // --- 区域 1: 日记区 ---
            // [优化] 将整个日记区视为一个整体，增加其内部间距
            VStack(alignment: .leading, spacing: 12) {
                // 标题和情绪图标
                HStack(alignment: .top) { // [优化] 使用 .top 对齐，防止因字体大小不一而错位
                    VStack(alignment: .leading, spacing: 4) {
                        // [优化] 调整字体层级，日期更突出
                        Text(formatDateHeader(log.date))
                            .font(.title2.weight(.bold))
                            .foregroundColor(.primary)
                        
                        // [优化] 星期使用次要颜色和中等字重，并确保为中文
                        Text(formatWeekday(log.date))
                            .font(.headline.weight(.medium))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // [优化] 移除胶囊背景，让心情图标更自然地融入
                    if let mood = log.mood {
                        Image(systemName: mood.iconName)
                            .font(.title2) // [优化] 调整图标大小以匹配标题
                            .foregroundColor(moodColor(for: mood)) // [优化] 赋予心情图标颜色
                    }
                }
                
                // 手记内容
                if let notes = log.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.body)
                        .foregroundColor(.secondary) // [优化] 使用 .secondary 颜色，与标题区隔
                        .lineLimit(3)
                        .lineSpacing(5) // [优化] 增加行间距，提升可读性
                        .padding(.top, 4) // [优化] 与标题之间增加少量间距
                } else if Calendar.current.isDateInToday(log.date) {
                    // ... “写点什么吧” 的按钮样式保持不变 ...
                    Button(action: {
                        withAnimation { showingMoodBanner = true }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                            Text("写点什么吧")
                                .font(.body.weight(.medium))
                        }
                        .foregroundColor(.blue)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(16)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.bottom, entries.isEmpty ? 0 : 20) // [优化] 如果有播放列表，则拉开与分隔线的间距
            
            // --- 分隔线 ---
            if !entries.isEmpty {
                // [优化] 使用更柔和的颜色和样式作为分隔线
                Divider().background(Color.white.opacity(0.2))
                    .padding(.bottom, 20)
            }
            
            // --- 资源列表区 ---
            if !entries.isEmpty {
                VStack(alignment: .leading, spacing: 18) { // [优化] 统一列表项的间距
                    ForEach(entries) { entry in
                        SleepEntryRowView(entry: entry)
                            .onTapGesture {
                                onEntryTapped(entry)
                            }
                    }
                }
            }
        }
        .padding(20)
        .background(
            // [优化] 统一使用 .ultraThinMaterial 作为卡片背景
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        
        // --- [补全] 日记心情选择Banner ---
        .overlay(
            VStack {
                if showingMoodBanner {
                    MoodSelectionBannerView(onMoodSelected: { mood in
                        selectedMood = mood
                        showingJournalEntry = true
                    }, isPresented: $showingMoodBanner)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
                }
                Spacer()
            }
        )
        // --- [补全] 日记书写界面 ---
        .fullScreenCover(isPresented: $showingJournalEntry) {
            if let mood = selectedMood {
                JournalEntryView(mood: mood, onSave: { content in
                    // 保存到 log
                    SleepLogManager.shared.upsertLog(for: Date(), mood: mood, notes:content)
                    showingJournalEntry = false
                    selectedMood = nil
                }, isPresented: $showingJournalEntry)
            }
        }
    }
    
    // MARK: - Helper Functions
    private func formatDateHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        formatter.locale = Locale(identifier: "zh_CN") // [本地化] 改为简体中文区域设置
        return formatter.string(from: date)
    }
    
    private func formatWeekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: "zh_CN") // [本地化] 改为简体中文区域设置
        return formatter.string(from: date)
    }

    private func moodColor(for mood: Mood) -> Color {
        // 假设 Mood 有一个 displayName 属性，且其值为简体中文
        switch mood.displayName {
        case "开心": return .orange
        case "平静": return .cyan
        case "丧": return .blue
        case "生气": return .red
        default: return .secondary
        }
    }
}
// MARK: - 单笔睡眠条目 (SleepEntryRowView)
struct SleepEntryRowView: View {
    let entry: SleepEntry

    var body: some View {
        HStack(spacing: 16) {
            AsyncImage(url: entry.resourceCoverImageURL) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                ZStack {
                    // STYLE: 让占位符背景色更柔和。
                    Color.gray.opacity(0.2)
                    Image(systemName: "waveform.path.ecg")
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 55, height: 55)
            // STYLE: 使用 .continuous 风格的圆角，看起来更平滑。
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(entry.resourceName ?? "未知音景")
                    .font(.footnote)
                    .fontWeight(.medium)
                    .foregroundColor(Color.white.opacity(0.85))
                    .lineLimit(2)
                Text("\(entry.startTime, style: .time) 开始，陪伴了 \(formatDuration(entry.duration))")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .brief // e.g., "1h 23m"
        formatter.calendar?.locale = Locale(identifier: "zh_cn")
        return formatter.string(from: duration) ?? ""
    }
}


// MARK: - 手记详情页 (NotesDetailView)
struct NotesDetailView: View {
    let log: DailySleepLog
    @Environment(\.dismiss) var dismiss

    var body: some View {
        // STYLE: 为了在 Sheet 中显示标题和按钮，这里需要一个 NavigationStack
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let mood = log.mood {
                        HStack(spacing: 12) {
                            Text(mood.iconName).font(.system(size: 50))
                            Text(mood.displayName).font(.title.weight(.bold))
                            Spacer()
                        }
                    }
                    
                    if let notes = log.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.body)
                            .lineSpacing(8)
                            .foregroundColor(.primary.opacity(0.9))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // STYLE: 增加更多内边距，让内容呼吸。
                .padding(30)
            }
            .navigationTitle(formatDateHeader(log.date))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭", action: { dismiss() })
                }
            }
        }
    }
    
    private func formatDateHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

// MARK: - SwiftUI 预览
struct SleepLogView_Previews: PreviewProvider {
    static var previews: some View {
        // ... 预览代码保持不变 ...
    }
}
