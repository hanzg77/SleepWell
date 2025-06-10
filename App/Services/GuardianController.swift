import Foundation
import Combine
import SwiftUI

enum GuardianMode: Int, CaseIterable, Identifiable, Codable {
    case smartDetection = -1   // 智能检测
    case unlimited = 0         // 整夜播放
    case timedClose60 = 60     // 1分钟
    case timedClose1800 = 1800 // 30分钟
    case timedClose3600 = 3600 // 1小时
    case timedClose7200 = 7200 // 2小时

    var id: Int { rawValue }

    var displayTitle: String {
        switch self {
        case .smartDetection: return "检测入睡后暂停"
        case .unlimited: return "整夜播放"
        default: return "\(rawValue / 60)分钟后暂停"
        }
    }

    var displayDescription: String {
        switch self {
        case .smartDetection: return "App 将尝试检测您的入睡状态，并在您睡着后自动暂停播放"
        case .unlimited: return "音频将持续播放直到您手动停止"
        default: return "音频将在指定时间后自动停止播放"
        }
    }

    /// 获取守护时长（秒），-1 表示智能检测，0 表示整夜
    var duration: Int { rawValue }
} 
class GuardianController: ObservableObject {
    static let shared = GuardianController()
    
    // 守护模式倒计时（秒）
    @Published var countdown: Int = 0
    
    // 是否开启守护模式
    @Published var isGuardianModeEnabled: Bool = false
    
    // 取消订阅的集合
    private var cancellables = Set<AnyCancellable>()
    
    // 定时器
    private var timer: Timer?
    
    @Published var currentMode: GuardianMode = .unlimited
    
    private var sessionStartTime: Date?
    
    // ✨ 请在这里添加以下两个 @Published 属性
        // 用于暂存当前守护会话期间，用户输入的手记内容
    @Published var currentSessionNotes: String = ""
    @Published var currentSessionMood: Mood? = nil

    
    private init() {
        // 监听播放状态变化
        NotificationCenter.default.publisher(for: .playerDidStop)
            .sink { [weak self] _ in
                self?.handlePlaybackStopped()
            }
            .store(in: &cancellables)
    }
    
    // 开启守护模式
    func enableGuardianMode(_ mode: GuardianMode) {
        print("开启守护模式，当前模式：\(mode.displayTitle)")
        disableGuardianMode()
        currentMode = mode
        isGuardianModeEnabled = true
        countdown = mode.duration
        sessionStartTime = Date() // 记录开始时间
        startTimer()
        print("守护模式已开启，isGuardianModeEnabled: \(isGuardianModeEnabled)")
    }
    
    // 关闭守护模式
    func disableGuardianMode() {
        if isGuardianModeEnabled == false{
            return
        }
        isGuardianModeEnabled = false
        countdown = 0
        stopTimer()
        
        // 记录睡眠日记
        if let startTime = sessionStartTime {
            let duration = Date().timeIntervalSince(startTime)
            let entry = SleepEntry(
                startTime: startTime,
                duration: duration,
                mode: currentMode,
                resource: DualStreamPlayerController.shared.currentResource
            )
            SleepLogManager.shared.addEntry(entry)
        }
        
        // 直接调用 stop，不触发 handlePlaybackStopped
        DualStreamPlayerController.shared.stop()
    }
    
    // 开始定时器
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.countdown > 0 {
                self.countdown -= 1
            } else {
                self.disableGuardianMode()
                // 发送通知而不是直接调用 stop
                NotificationCenter.default.post(name: .guardianModeDidEnd, object: nil)
            }
        }
    }
    
    // 停止定时器
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // 处理播放停止
    private func handlePlaybackStopped() {
        // 只在非主动停止时禁用守护模式
        if isGuardianModeEnabled {
            isGuardianModeEnabled = false
            countdown = 0
            stopTimer()
        }
    }
    
    private func startSmartDetection() {
        // 智能检测模式不需要倒计时
        countdown = 0
        stopTimer()
        // 确保开始播放
        DualStreamPlayerController.shared.resume()
    }
    
    private func startUnlimitedMode() {
        // 整夜播放模式不需要倒计时
        countdown = 0
        stopTimer()
        // 确保开始播放
        DualStreamPlayerController.shared.resume()
    }
    
    private func startGuardianTimer(duration: Int) {
        countdown = duration
        startTimer()
        // 确保开始播放
        DualStreamPlayerController.shared.resume()
    }
    
    // MARK: - 公共方法
    
    /// 重新开始守护模式
    func restartGuardianMode() {
    
        
        // 重置状态
        isGuardianModeEnabled = true
        countdown = 0
        
        // 重新开始播放
        DualStreamPlayerController.shared.restart()
        
        // 重新开始守护
        enableGuardianMode(currentMode)
    }
} 
