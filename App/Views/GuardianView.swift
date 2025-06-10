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
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                // 播放器视图
                DualStreamPlayerView()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                
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
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    playerController.showControls.toggle()
                }
            }
        }
        .onChange(of: playerController.isVideoReady) { isReady in
            let newOpacity = isReady ? 1.0 : 0.0
            if videoOpacity != newOpacity {
                withAnimation(.easeOut(duration: 0.5)) {
                    videoOpacity = newOpacity
                }
            }
        }
    }
}


