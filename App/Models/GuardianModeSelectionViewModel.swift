import Foundation
import Combine
import SwiftUI

class GuardianModeSelectionViewModel: ObservableObject {
    @Published var selectedMode: GuardianMode?
    @Published var showingGuardianView = false
    
    private var resource: Resource
    private let episode: Episode?
    private var cancellables = Set<AnyCancellable>()
    private let guardianController: GuardianController
    
    // 新增：模式选择的回调
    var onModeSelected: ((GuardianMode) -> Void)?
    
    var modes: [GuardianMode] {
        GuardianMode.allCases
    }
    
    init(resource: Resource, episode: Episode?, guardianManager: GuardianController) {
        self.resource = resource
        self.episode = episode
        self.guardianController = guardianManager
    }
    
    func selectMode(_ mode: GuardianMode) {
        selectedMode = mode
        // 开始守护模式
        guardianController.enableGuardianMode(mode)
        // 更新播放统计
        updatePlaybackStats()
        // 通知外部模式已选择
        onModeSelected?(mode)
        // 延迟跳转到守护界面
        navigateToGuardianView()
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
} 
