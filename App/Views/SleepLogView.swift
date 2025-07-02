import SwiftUI
import Combine
import OSLog

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
        .navigationTitle("journal.title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
             //   RefreshButton(logManager: logManager) // 保留刷新按钮，或者按需移除
            }
        }
    }

    // MARK: - Subviews
    private var logListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // STYLE: LazyVStack 的间距稍微拉大，让卡片更有呼吸感。
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 24)], spacing: 24) {
                    ForEach(logManager.dailyLogs) { dailyLog in
                        DailyLogCardView(log: dailyLog, entries: dailyLog.entries, onNotesTapped: {
                            selectedLog = dailyLog
                            showingNotesDetail = true
                        }, onEntryTapped: { entry in
                            // 点击单条守护记录时
                            fetchResourceAndShowSheet(for: entry)
                        }, onCardTap: onCardTap)
                        .id(dailyLog.id)  // 添加 id 用于滚动定位
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
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "moon.zzz.fill") // 保留图标
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                    .padding(.top, 40) // 与导航栏的间距

                Text("journal.empty".localized) // "暂无日记条目"
                    .font(.title3)
                    .foregroundColor(.secondary)

                Text("journal.empty.addTodayPrompt".localized) // 新增提示: "要记录今天的心情吗？"
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.bottom, 10) // 卡片前的间距
                
                // 为今天创建一个空的日志对象
                let todayLog = DailySleepLog(date: Date(), entries: [], mood: nil, notes: nil)
                
                // 显示今日卡片，DailyLogCardView 内部会处理 "写点什么吧" 按钮的逻辑
                DailyLogCardView(
                    log: todayLog,
                    entries: todayLog.entries,
                    onNotesTapped: { /* 对于新条目，此回调暂时无操作，主要交互通过卡片内部按钮 */ },
                    onEntryTapped: { _ in /* 新条目无历史播放记录可点击 */ },
                    onCardTap: onCardTap
                )
                Spacer() // 如果内容较少，将内容推向顶部
            }
            .padding(.horizontal) // 整体内容的水平边距
            .padding(.vertical)   // 整体内容的垂直边距
            .frame(maxWidth: .infinity) // 确保 VStack 占据全部宽度以便文本居中
        }
    }

    // 修改获取资源的方法
    private func fetchResourceAndShowSheet(for entry: SleepEntry) {
        guard let resourceID = entry.resourceID else { return } // 1. 确保资源ID存在
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
                // 2. 直接播放视频
                PlaylistController.shared.setPlaylist([resource])
                PlaylistController.shared.play(resource)
                GuardianController.shared.enableGuardianMode(GuardianController.shared.currentMode)
                self.selectedTab = 1
                self.isLoadingResource = false // 加载完成后，取消加载状态
            }
            .store(in: &cancellables)
    }
}

// MARK: - 每日日志卡片 (DailyLogCardView)
// 注释：这是视觉设计的核心，在这里进行了最多的美化。
struct DailyLogCardView: View {
    let log: DailySleepLog
    let entries: [SleepEntry]
    var onNotesTapped: () -> Void
    var onEntryTapped: (SleepEntry) -> Void = { _ in }
    var onCardTap: (DailySleepLog) -> Void = { _ in }

    // 日记功能相关状态
    @State private var showingMoodBanner: Bool = false
    @State private var selectedMood: Mood? = nil
  //  @State private var showingJournalEntry: Bool = false

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
                    
                    // 心情显示在右上角
                    if let mood = log.mood {
                        Text(mood.iconName)
                            .font(.title2)
                    }
                }
                
                // 手记内容
                if let notes = log.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.body)
                        .lineSpacing(8)
                        .foregroundColor(.primary.opacity(0.9))
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(.systemGray6).opacity(0.85))
                                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                        )
                        .padding(.top, 8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if Calendar.current.isDateInToday(log.date) {
                                selectedMood = log.mood
                            } else {
                                onCardTap(log)
                            }
                        }
                } else if Calendar.current.isDateInToday(log.date) {
                    // ... "写点什么吧" 的按钮样式保持不变 ...
                    Button(action: {
                        withAnimation { showingMoodBanner = true }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                            Text("journal.write".localized)
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
        .fullScreenCover(isPresented: $showingMoodBanner) {
            MoodSelectionBannerView(onMoodSelected: { mood in
                selectedMood = mood
            }, isPresented: $showingMoodBanner)
        }
        
        // --- [日记编辑] ---
        .fullScreenCover(item: $selectedMood) { mood in
            JournalEntryView(
                mood: mood,
                onSave: { content in
                    SleepLogManager.shared.upsertLog(for: Date(), mood: mood, notes: content)
                    selectedMood = nil
                },
                onDismiss: {
                    selectedMood = nil
                },
                initialContent: log.notes ?? ""
            )
        }
    }
    
    // MARK: - Helper Functions
    private func formatDateHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        let currentLanguage = LocalizationManager.shared.currentLanguage
        
        // 使用本地化的日期格式
        formatter.locale = Locale(identifier: currentLanguage)
        
        // 根据语言设置不同的日期样式
        switch currentLanguage {
        case "zh", "zh-hant":
            formatter.dateFormat = "M月d日"
        case "ja":
            formatter.dateFormat = "M月d日"
        case "en":
            formatter.dateFormat = "MMM d"
        default:
            formatter.dateFormat = "MMM d"
        }
        
        return formatter.string(from: date)
    }
    
    private func formatWeekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        // Use the app's current locale
        formatter.locale = Locale(identifier: LocalizationManager.shared.currentLanguage)
        return formatter.string(from: date)
    }

    private func moodColor(for mood: Mood) -> Color {
        // IMPORTANT: This should switch on a non-localized identifier, e.g., mood.id or a mood enum case
        // For demonstration, assuming Mood has an 'id' property that's stable:
        switch mood.id { // Example: Assuming mood.id is "happy", "calm", "sad", "angry"
        case "happy_id": return .orange // Replace "happy_id" with actual stable ID
        case "calm_id": return .cyan   // Replace "calm_id" with actual stable ID
        case "sad_id": return .blue     // Replace "sad_id" with actual stable ID
        case "angry_id": return .red    // Replace "angry_id" with actual stable ID
        default: return .gray // Use a more distinct default or ensure all moods are covered
        }
        // Alternatively, if Mood is an enum: switch mood { case .happy: ... }
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
        formatter.calendar?.locale = Locale(identifier: LocalizationManager.shared.currentLanguage)
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
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color(.systemGray6).opacity(0.85))
                                    .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                            )
                            .padding(.top, 8)
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
                    Button("action.close".localized, action: { dismiss() })
                }
            }
        }
    }
    
    private func formatDateHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        let currentLanguage = LocalizationManager.shared.currentLanguage
        
        // 使用本地化的日期格式
        formatter.locale = Locale(identifier: currentLanguage)
        
        // 根据语言设置不同的日期样式
        switch currentLanguage {
        case "zh", "zh-hant":
            formatter.dateFormat = "M月d日"
        case "ja":
            formatter.dateFormat = "M月d日"
        case "en":
            formatter.dateFormat = "MMM d"
        default:
            formatter.dateFormat = "MMM d"
        }
        
        return formatter.string(from: date)
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
                .foregroundColor(.primary) // 保持颜色设置
        }
    }
}

// MARK: - SwiftUI 预览
struct SleepLogView_Previews: PreviewProvider {
    static var previews: some View {
        // ... 预览代码保持不变 ...
    }
}
