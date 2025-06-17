import SwiftUI
import AVKit
import AVFoundation
import MediaPlayer
import os.log

// MARK: - 播放控制视图
// 已移除 PlaybackControls 组件

// MARK: - 进度条视图

// MARK: - 剧集信息视图
struct EpisodeInfoView: View {
    let episode: Episode
    
    var body: some View {
        Text(episode.localizedName)
            .font(.title2)
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
    }
}

// MARK: - 错误视图
struct ErrorView: View {
    let message: String
    
    var body: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.red)
            Text("视频加载失败")
                .foregroundColor(.white)
            Text(message)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

// MARK: - 加载视图
struct LoadingView: View {
    var body: some View {
        ProgressView()
            .scaleEffect(1.5)
    }
}

// MARK: - 主视图
struct GuardianView: View {
    @StateObject private var guardianController = GuardianController.shared
    @StateObject private var playerController = DualStreamPlayerController.shared
    
    // 视图内部状态
    @State private var videoOpacity: Double = 0.0
    @State private var startPanning: Bool = false
    
    // 日记功能相关状态
    @State private var showingMoodBanner: Bool = false
    @State private var selectedMood: Mood? = nil
    @State private var showingJournalEntry: Bool = false
    
    @Environment(\.globalSafeAreaInsets) private var globalSafeAreaInsets // 读取环境值
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
             //   Color.blue.edgesIgnoringSafeArea(.all)
                
                // 播放器视图
                DualStreamPlayerView() // 传递 geometry
                    .frame(width: geometry.size.width, height: geometry.size.height)
                 //   .ignoresSafeArea(.all)
                
                // DEBUG: 直接显示 GuardianView 的 GeometryReader 报告的底部安全区域高度
                Text("Guardian GR Inset: B=\(globalSafeAreaInsets.top, specifier: "%.1f")")
                    .foregroundColor(.yellow)
                    .background(Color.black.opacity(0.7))
                    .position(x: geometry.size.width / 2, y: 60) // 调整位置以便观察
                
                // 心情选择Banner
                if showingMoodBanner {
                    MoodSelectionBannerView(onMoodSelected: { mood in
                       
                        selectedMood = mood
                        showingJournalEntry = true
                    }, isPresented: $showingMoodBanner)
                    .transition(.opacity)
                    .zIndex(100)
                }
                
                // 日记书写界面
                if let mood = selectedMood, showingJournalEntry {
                    JournalEntryView(mood: mood, onSave: { content in
                        // 保存到 log
                        SleepLogManager.shared.upsertLog(for: Date(), mood: mood, notes: content)
                        showingJournalEntry = false
                        selectedMood = nil
                    }, isPresented: $showingJournalEntry)
                    .transition(.opacity)
                    .zIndex(200)
                }
            }
        
        }
        .ignoresSafeArea(.all)
    }

}

// MARK: - SwiftUI 预览
struct GuardianView_Previews: PreviewProvider {
    static var previews: some View {
        GuardianView()
            .environmentObject(GuardianController.shared) // 如果子视图依赖
            .environmentObject(DualStreamPlayerController.shared) // 如果子视图依赖
    }
}
