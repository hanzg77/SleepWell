import SwiftUI
import SleepWell

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            AudioLibraryView(selectedTab: $selectedTab)
                .tabItem {
                    Label("音频", systemImage: "headphones")
                }
                .tag(0)
            
            GuardianView()
                .tabItem {
                    Label("守护睡眠", systemImage: "moon.stars")
                }
                .tag(1)
            
            SleepRecordView()
                .tabItem {
                    Label("睡眠记录", systemImage: "chart.bar")
                }
                .tag(2)
        }
       // .border(Color.red, width: 2) // 设置红色边框，宽度为2
        .accentColor(ThemeManager.Colors.textPrimary)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AudioManager.shared)
        .environmentObject(GuardianManager.shared)
}
