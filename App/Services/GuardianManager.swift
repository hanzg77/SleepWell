import Foundation
import Combine
import CoreMotion

// 通知名称扩展
extension Notification.Name {
    static let guardianModeDidEnd = Notification.Name("guardianModeDidEnd")
}

enum GuardianMode: CaseIterable, Equatable, Hashable {
    case smartDetection
    case timedClose(TimeInterval)
    case unlimited
    
    static let allModes: [GuardianMode] = [
        .smartDetection,
        .timedClose(60),    // 1分钟
        .timedClose(1800),  // 30分钟
        .timedClose(3600)   // 1小时
    ]
    
    var icon: String {
        switch self {
        case .smartDetection:
            return "brain.head.profile"
        case .timedClose:
            return "timer"
        case .unlimited:
            return "infinity"
        }
    }
    
    var displayTitle: String {
        switch self {
        case .smartDetection:
            return "检测入睡后暂停"
        case .timedClose(let duration):
            return "\(formatDuration(duration))后暂停"
        case .unlimited:
            return "整夜播放"
        }
    }
    
    var displayDescription: String {
        switch self {
        case .smartDetection:
            return "App 将尝试检测您的入睡状态，并在您睡着后自动暂停播放"
        case .timedClose:
            return "音频将在指定时间后自动停止播放"
        case .unlimited:
            return "音频将持续播放直到您手动停止"
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes >= 60 {
            let hours = minutes / 60
            return "\(hours)小时"
        } else {
            return "\(minutes)分钟"
        }
    }

    // 手动实现 Equatable
    static func == (lhs: GuardianMode, rhs: GuardianMode) -> Bool {
        switch (lhs, rhs) {
        case (.smartDetection, .smartDetection):
            return true
        case (.timedClose(let lhsDuration), .timedClose(let rhsDuration)):
            return lhsDuration == rhsDuration
        case (.unlimited, .unlimited):
            return true
        default:
            return false
        }
    }

    // 手动实现 Hashable
    func hash(into hasher: inout Hasher) {
        switch self {
        case .smartDetection:
            hasher.combine(0)
        case .timedClose(let duration):
            hasher.combine(1)
            hasher.combine(duration)
        case .unlimited:
            hasher.combine(2)
        }
    }
}

class GuardianManager: ObservableObject {
    static let shared = GuardianManager()

    @Published var currentMode: GuardianMode?
    @Published var isGuardianActive = false
    @Published var remainingTime: TimeInterval?
    @Published var isUserAsleep = false
    @Published var startTime: Date?
    
    var formattedRemainingTime: String {
        guard let remaining = remainingTime else { return "--:--" }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        let seconds = Int(remaining) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private var motionManager = CMMotionManager()
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // 开始守护
    func startGuardian(mode: GuardianMode) {
        currentMode = mode
        isGuardianActive = true
        startTime = Date()
        
        switch mode {
        case .smartDetection:
            startSleepDetection()
        case .timedClose(let duration):
            remainingTime = duration
            startTimer()
        case .unlimited:
            break
        }
    }
    
    // 结束守护
    func endGuardian() {
        // 停止定时器
        stopTimer()
        
        // 重置状态
        currentMode = nil
        startTime = nil
        remainingTime = nil
        
        // 发送通知
        NotificationCenter.default.post(name: .guardianModeDidEnd, object: nil)
    }
    
    // 开始睡眠检测
    private func startSleepDetection() {
        guard motionManager.isAccelerometerAvailable else { return }
        
        motionManager.accelerometerUpdateInterval = 1.0
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let data = data else { return }
            
            // 简单的运动检测逻辑
            let movement = sqrt(
                pow(data.acceleration.x, 2) +
                pow(data.acceleration.y, 2) +
                pow(data.acceleration.z, 2)
            )
            
            // 如果运动幅度小于阈值，认为用户可能已入睡
            if movement < 0.1 {
                self?.isUserAsleep = true
            } else {
                self?.isUserAsleep = false
            }
        }
    }
    
    // 停止睡眠检测
    private func stopSleepDetection() {
        motionManager.stopAccelerometerUpdates()
        isUserAsleep = false
    }
    
    // 开始定时器
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if case .timedClose = self.currentMode,
               let remaining = self.remainingTime,
               remaining > 0,
               AudioManager.shared.isPlaying {
                self.remainingTime = remaining - 1
            } else if let remaining = self.remainingTime,
                      remaining <= 0 {
                self.stopTimer()
                self.endGuardian()
            }
        }
    }
    
    // 停止定时器
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // 清理资源
    deinit {
        stopSleepDetection()
        stopTimer()
    }
} 
