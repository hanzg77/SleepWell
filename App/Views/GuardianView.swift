import SwiftUI
import AVKit
import os.log

// MARK: - 播放控制视图
// 已移除 PlaybackControls 组件

// MARK: - 进度条视图
struct ProgressView: View {
    @EnvironmentObject private var audioManager: AudioManager
    
    var body: some View {
        if audioManager.duration > 0 {
            VStack(spacing: 8) {
                Slider(value: Binding(
                    get: { audioManager.currentTime },
                    set: { audioManager.seek(to: $0) }
                ), in: 0...audioManager.duration)
                .accentColor(.white)
                
                HStack {
                    Text(formatTime(audioManager.currentTime))
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Text(formatTime(audioManager.duration))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - 音频播放视图
struct AudioPlaybackView: View {
    @EnvironmentObject private var audioManager: AudioManager
    private let logger = Logger(subsystem: "com.sleepwell", category: "AudioPlaybackView")
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // 封面全屏自适应
                if let episode = audioManager.currentEpisode {
                    if let resource = audioManager.currentResource,
                       let url = URL(string: resource.coverImageUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .background(Color.black)
                        } placeholder: {
                            Color.black
                        }
                    } else {
                        Color.black
                    }
                    // 顶部标题
                    Text(episode.localizedName)
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .padding(.top, 12)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .top)
                } else {
                    Color.black
                }
                // 播放控制（底部）
                VStack {
                    Spacer()
                    if let episode = audioManager.currentEpisode, audioManager.duration > 0 {
                        // 进度条
                        Slider(value: Binding(
                            get: { audioManager.currentTime },
                            set: { audioManager.seek(to: $0) }
                        ), in: 0...audioManager.duration)
                        .accentColor(.white)
                        .padding(.horizontal)
                        // 时间显示
                        HStack {
                            Text(formatTime(audioManager.currentTime))
                                .font(.caption)
                                .foregroundColor(.gray)
                            Spacer()
                            Text(formatTime(audioManager.duration))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal)
                        // 播放/暂停按钮
                        Button(action: {
                            if audioManager.isPlaying {
                                audioManager.pause()
                            } else {
                                audioManager.play()
                            }
                        }) {
                            Image(systemName: audioManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .resizable()
                                .frame(width: 64, height: 64)
                                .foregroundColor(.white)
                                .shadow(radius: 10)
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                    }
                }
            }
            .background(Color.black)
        }
        .onAppear {
            logger.info("显示音频播放界面")
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - 封面图片视图
struct CoverImageView: View {
    let resource: Resource?
    
    var body: some View {
        if let resource = resource {
            AsyncImage(url: URL(string: resource.coverImageUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Image(systemName: "music.note")
                    .font(.system(size: 100))
                    .foregroundColor(.gray)
            }
            .background(Color.black)
        } else {
            Image(systemName: "music.note")
                .font(.system(size: 100))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
        }
    }
}

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
    @EnvironmentObject private var audioManager: AudioManager
    @StateObject private var videoController = VideoPlayerController.shared
    private let logger = Logger(subsystem: "com.sleepwell", category: "GuardianView")
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                //      if let videoUrl = VideoPlayerController.shared.currentURL {
                VideoPlayerView()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                //         }
                //else {
                //   AudioPlaybackView()
                //}
                //}
                //  .frame(maxWidth: .infinity, maxHeight: .infinity)
                //  }
                //  .onAppear {
                // 可选：打印当前视频URL
                /*     if let videoUrl = VideoPlayerController.shared.currentURL {
                 logger.info("当前视频: \(videoUrl)")
                 } else {
                 logger.info("当前为音频播放界面")
                 }
                 }
                 */
                //}
            }
        }
    }
}


