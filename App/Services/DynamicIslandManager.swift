import Foundation
import ActivityKit
import SwiftUI
import Combine
import OSLog

// MARK: - 灵动岛管理器
class DynamicIslandManager: ObservableObject {
    static let shared = DynamicIslandManager()
    
    private var currentActivity: Activity<GuardianActivityAttributes>?
    private let logger = Logger(subsystem: "com.sleepwell", category: "DynamicIsland")
    
    private init() {
        setupNotifications()
    }
    
    // MARK: - 设置通知监听
    private func setupNotifications() {
        // 监听守护开始
        NotificationCenter.default.publisher(for: .guardianModeDidStart)
            .sink { [weak self] _ in
                self?.startGuardianActivity()
            }
            .store(in: &cancellables)
        
        // 监听守护结束
        NotificationCenter.default.publisher(for: .guardianModeDidEnd)
            .sink { [weak self] _ in
                self?.stopGuardianActivity()
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 启动灵动岛活动
    func startGuardianActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.info("灵动岛活动未启用")
            return
        }
        
        let resourceName = DualStreamPlayerController.shared.currentResource?.name ?? "睡眠音乐"
        let guardianMode = GuardianController.shared.currentMode.displayTitle
        
        let attributes = GuardianActivityAttributes(
            resourceName: resourceName,
            guardianMode: guardianMode
        )
        
        let endTime: Date
        let remainingTime: TimeInterval
        
        switch GuardianController.shared.currentMode {
        case .unlimited:
            // 整夜模式，设置为8小时后
            endTime = Date().addingTimeInterval(8 * 3600)
            remainingTime = 8 * 3600
        case .smartDetection:
            // 智能检测模式，设置为2小时后
            endTime = Date().addingTimeInterval(2 * 3600)
            remainingTime = 2 * 3600
        default:
            // 定时模式
            let duration = TimeInterval(GuardianController.shared.currentMode.duration)
            endTime = Date().addingTimeInterval(duration)
            remainingTime = duration
        }
        
        let contentState = GuardianActivityAttributes.ContentState(
            endTime: endTime,
            remainingTime: remainingTime,
            guardianMode: guardianMode
        )
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                contentState: contentState,
                pushType: nil
            )
            
            currentActivity = activity
            logger.info("✅ 灵动岛活动已启动")
            
            // 启动定时器更新剩余时间
            startUpdateTimer()
            
        } catch {
            logger.error("❌ 启动灵动岛活动失败: \(error)")
        }
    }
    
    // MARK: - 停止灵动岛活动
    func stopGuardianActivity() {
        guard let activity = currentActivity else { return }
        
        Task {
            await activity.end(dismissalPolicy: .immediate)
            currentActivity = nil
            logger.info("🛑 灵动岛活动已停止")
        }
    }
    
    // MARK: - 更新定时器
    private var updateTimer: Timer?
    
    private func startUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateActivity()
        }
    }
    
    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    private func updateActivity() {
        guard let activity = currentActivity,
              GuardianController.shared.isGuardianModeEnabled else {
            stopUpdateTimer()
            return
        }
        
        let remainingTime = TimeInterval(GuardianController.shared.countdown)
        let endTime = Date().addingTimeInterval(remainingTime)
        
        let contentState = GuardianActivityAttributes.ContentState(
            endTime: endTime,
            remainingTime: remainingTime,
            guardianMode: GuardianController.shared.currentMode.displayTitle
        )
        
        Task {
            await activity.update(using: contentState)
        }
    }
}

