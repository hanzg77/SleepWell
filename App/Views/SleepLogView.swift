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
        VStack(alignment: .leading, spacing: 16) {
            // --- 顶部标题 ---
            cardHeader

            // --- 睡眠条目 ---
            ForEach(entries) { entry in
                SleepEntryRowView(entry: entry)
                    .onTapGesture {
                        onEntryTapped(entry)
                    }
            }

            // --- 日记入口或手记预览 ---
            if Calendar.current.isDateInToday(log.date) {
                if let notes = log.notes, !notes.isEmpty {
                    notesPreview(notes: notes)
                } else {
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
            } else if let notes = log.notes, !notes.isEmpty {
                notesPreview(notes: notes)
            }
        }
        .padding(20)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        // --- 日记心情选择Banner ---
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
        // --- 日记书写界面 ---
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

    // --- 卡片标题子视图 ---
    private var cardHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatDateHeader(log.date))
                    .font(.title2.weight(.bold))
                    .foregroundColor(.primary)
                Text(formatWeekday(log.date))
                    .font(.headline.weight(.medium))
                    .foregroundColor(.secondary)
            }
            Spacer()
            if let mood = log.mood {
                HStack(spacing: 6) {
                    Text(mood.iconName)
                    Text(mood.displayName)
                        .font(.callout.weight(.semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .foregroundColor(.primary)
            }
        }
    }
    
    // --- 手记预览子视图 ---
    private func notesPreview(notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(.secondary)
                Text("手记")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.secondary)
            }
            
            Text(notes)
                .font(.body)
                .lineLimit(3)
                .foregroundColor(.primary.opacity(0.8))
                .lineSpacing(5)
        }
        .padding(.top, 8)
        .contentShape(Rectangle())
        .onTapGesture { onNotesTapped() }
    }
    
    // MARK: - Helper Functions
    private func formatDateHeader(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
    
    private func formatWeekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale.current
        return formatter.string(from: date)
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
