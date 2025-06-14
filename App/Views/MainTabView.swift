import SwiftUI
import Combine

struct MainTabView: View {
    @State private var selectedTab = 0
    @StateObject private var playerController = DualStreamPlayerController.shared
    @StateObject private var logManager = SleepLogManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    
    // 🔥【關鍵修正】1. 新增一個用於觸發刷新的 @State 變數
    @State private var viewUpdater = UUID()
    
    var body: some View {
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
        .environmentObject(logManager)
        .accentColor(.blue)
        .onAppear {
            updateTabBarAppearance()
        }
        .onChange(of: selectedTab) { _ in
            updateTabBarAppearance()
            // 强制更新 TabBar
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.subviews.forEach { view in
                    if let tabBar = view as? UITabBar {
                        tabBar.setNeedsLayout()
                        tabBar.layoutIfNeeded()
                    }
                }
            }
        }
        .onChange(of: playerController.isVideoReady) { isReady in
            if isReady && selectedTab == 1 { // 只在伴你入眠页面时处理
                playerController.isInitialShow = true
                playerController.showControls = true
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
        .toolbar(selectedTab == 1 ? (!playerController.showControls ? .visible : .hidden) : .visible, for: .tabBar)
        .animation(.easeInOut(duration: 0.3), value: playerController.showControls)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("LanguageChanged"))) { _ in
            // 强制刷新视图
          //  objectWillChange.send()
            self.viewUpdater = UUID()
        }
    }
    
    private func updateTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        
        // 根据当前选中的 tab 设置背景透明度
        let bgAlpha: CGFloat = selectedTab == 1 ?   0.7:0.7
        appearance.backgroundColor = UIColor.black.withAlphaComponent(bgAlpha)
        
        // 设置选中和未选中状态的颜色
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor.white
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.white]
        
        // 根据当前选中的 tab 设置未选中状态的透明度
        let normalAlpha: CGFloat = selectedTab == 1 ? 0.5:0.5
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor.white.withAlphaComponent(normalAlpha)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.white.withAlphaComponent(normalAlpha)]
        
        // 应用 appearance 设置
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        
        // 强制更新所有 TabBar 实例
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.subviews.forEach { view in
                if let tabBar = view as? UITabBar {
                    tabBar.standardAppearance = appearance
                    tabBar.scrollEdgeAppearance = appearance
                }
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(GuardianController.shared)
}
