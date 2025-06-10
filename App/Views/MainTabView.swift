import SwiftUI
import SleepWell

struct MainTabView: View {
    @State private var selectedTab = 0
    @StateObject private var playerController = DualStreamPlayerController.shared
    @StateObject private var logManager = SleepLogManager.shared
    
    var body: some View {
        TabView(selection: $selectedTab) {
            AudioLibraryView(selectedTab: $selectedTab)
                .tabItem {
                    Label("音景", systemImage: "music.note.list")
                }
                .tag(0)
            
            GuardianView()
                .tabItem {
                    Label("伴你入眠", systemImage: "moon.stars.fill")
                }
                .tag(1)
            
            SleepLogView(selectedTab: $selectedTab)
                .tabItem {
                    Label("睡眠日记", systemImage: "person.fill")
                }
                .tag(2)
        }
        .environmentObject(logManager)
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
