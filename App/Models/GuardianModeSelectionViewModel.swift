import Foundation
import Combine
import SwiftUI

class GuardianModeSelectionViewModel: ObservableObject {
    @Published var selectedMode: GuardianMode?
    @Published var showingGuardianView = false
    
    private var resource: Resource
    private let episode: Episode?
    private var cancellables = Set<AnyCancellable>()
    private let guardianManager: GuardianManager
    private let audioManager: AudioManager
    
    var modes: [GuardianMode] {
        GuardianMode.allCases
    }
    
    init(resource: Resource, episode: Episode?, guardianManager: GuardianManager, audioManager: AudioManager) {
        self.resource = resource
        self.episode = episode
        self.guardianManager = guardianManager
        self.audioManager = audioManager
    }
    
    func selectMode(_ mode: GuardianMode) {
        selectedMode = mode
        startPlaybackWithGuardian()  // 只调用一次启动方法
    }
    
    func startPlaybackWithGuardian() {
        guard let mode = selectedMode else { return }
        
        // 开始守护模式
        guardianManager.startGuardian(mode: mode)
        
        // 开始播放音频或视频
        startPlayback()
        
        // 更新播放统计
        updatePlaybackStats()
        
        // 延迟一小段时间后跳转到守护界面，确保音频已经开始播放
        navigateToGuardianView()
    }
    private func startPlayback() {
        if let episode = episode {
            print("🎥 播放剧集: id=\(episode.id), videoUrl=\(episode.videoUrl ?? "nil")")
            if let videoUrlStr = episode.videoUrl, !videoUrlStr.isEmpty, let videoUrl = URL(string: videoUrlStr) {
                // 启动视频播放
                VideoPlayerController.shared.setupPlayer(url: videoUrl)
            } else {
                // 启动音频播放
                audioManager.currentResource = resource
                audioManager.playEpisode(episode)
            }
        } else if resource.isSingleEpisode {
            let singleEpisode = resource.createSingleEpisode()
            print("🎥 播放单集资源: id=\(singleEpisode.id), videoUrl=\(singleEpisode.videoUrl ?? "nil")")
            if let videoUrlStr = singleEpisode.videoUrl, !videoUrlStr.isEmpty, let videoUrl = URL(string: videoUrlStr) {
                // 启动视频播放
                VideoPlayerController.shared.setupPlayer(url: videoUrl)
            } else {
                // 启动音频播放
                audioManager.currentResource = resource
                audioManager.playEpisode(singleEpisode)
            }
        }
    }
    
    private func updatePlaybackStats() {
        NetworkManager.shared.trackPlayback(
            resourceId: resource.resourceId,
            id: episode?.id ?? resource.resourceId
        )
        .sink { completion in
            if case .failure(let error) = completion {
                print("更新播放统计失败: \(error)")
            }
        } receiveValue: { _ in }
        .store(in: &cancellables)
    }
    
    private func navigateToGuardianView() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showingGuardianView = true
        }
    }

    // 提取创建单集 Episode 的逻辑到单独的方法
    private func createSingleEpisode(from resource: Resource) -> Episode {
        return Episode(
            id: resource.id,
            episodeNumber: 1,
            audioUrl: resource.audioUrl,
            videoUrl: resource.videoUrl,
            durationSeconds: resource.totalDurationSeconds,
            localizedContent: EpisodeLocalizedContent(
                name: resource.localizedContent.name,
                description: resource.localizedContent.description
            ),
            playbackCount: resource.globalPlaybackCount
        )
    }
} 
