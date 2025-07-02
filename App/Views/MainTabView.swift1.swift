import SwiftUI
import Combine


private struct GlobalSafeAreaInsetsKey: EnvironmentKey {
    static var defaultValue: EdgeInsets = EdgeInsets()
}

extension EnvironmentValues {
    var globalSafeAreaInsets: EdgeInsets {
        get { self[GlobalSafeAreaInsetsKey.self] }
        set { self[GlobalSafeAreaInsetsKey.self] = newValue }
    }
}


struct MainTabView: View {
    @State private var selectedTab = 0
    @StateObject private var playerController = DualStreamPlayerController.shared
    @StateObject private var logManager = SleepLogManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    
    // 🔥【關鍵修正】1. 新增一個用於觸發刷新的 @State 變數
    @State private var viewUpdater = UUID()
    
    var body: some View {
        GeometryReader { geometry in
            TabView(selection: $selectedTab) {
                AudioLibraryView(selectedTab: $selectedTab)
                    .tabItem {
                        Image(systemName: "music.note.list")
                        Text("tab.library".localized)
                    }
                    .tag(0)
                
                GuardianView()
                    .tabItem {
                        Image(systemName: "moon.stars")
                        Text("tab.sleep".localized)
                    }
                    .tag(1)
                
                SleepLogView(selectedTab: $selectedTab)
                    .tabItem {
                        Image(systemName: "book")
                        Text("tab.journal".localized)
                    }
                    .tag(2)
            }
            //hzg
         .id(viewUpdater) // 🔥【关键修正】将 viewUpdater 应用为 TabView 的 id
            .environmentObject(logManager)
       //     .accentColor(.blue)
            // hzg
             
            .onChange(of: playerController.isVideoReady) { isReady in
                if isReady && selectedTab == 1 { // 只在伴你入眠页面时处理
                    playerController.isInitialShow = true
                    // 移除强制显示控制条的逻辑，让 DualStreamPlayerView 内部管理
                   // playerController.showControls = true
                }
            }

            .onChange(of: selectedTab) { _ in
                if selectedTab == 1 { // 在睡眠守护页面时
                    playerController.isInitialShow = true
                    playerController.showControls = true
                } else {
                    playerController.showControls = true // 其他页面始终显示 TabBar
                }
            }
             
            // 🔥【關鍵修正】使用 .toolbar 修饰符控制 TabBar 的显示
            //hzg
      /*      .toolbar(
                selectedTab == 1 ? (
                    (playerController.videoPlayer.currentItem == nil || playerController.showControls) ? .visible : .hidden
                ) : .visible,
                for: .tabBar
            )
        */
        // 使用 SwiftUI 的方式来设置 TabBar 背景
        .toolbarBackground(
            .ultraThinMaterial, // Changed to ultraThinMaterial for translucency
            for: .tabBar
        )
            // 设置 TabBar 中图标和文字的颜色方案 (例如 .dark 会使它们在深色背景上变亮)
            .toolbarColorScheme(.dark, for: .tabBar)

            // 🔥【关键修正】当控制条显隐切换时，如果影响 TabBar，则强制刷新
        /*    .onChange(of: playerController.showControls) { _ in
                if selectedTab == 1 { // 仅当在“伴你入眠”页面，控制条变化会影响 TabBar 显隐时
                   //hzg
                    self.viewUpdater = UUID()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LanguageChanged"))) { _ in
                // 强制刷新视图
              //  objectWillChange.send()
                self.viewUpdater = UUID()
            }
         */
            .environment(\.globalSafeAreaInsets, geometry.safeAreaInsets) // 设置环境值
        }
        .ignoresSafeArea() // 让顶层 GeometryReader 获取到包括安全区域的完整尺寸
    }
}



#Preview {
    MainTabView()
        .environmentObject(GuardianController.shared)
}
