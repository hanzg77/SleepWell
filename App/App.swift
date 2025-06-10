import SwiftUI
import AVFoundation
import BackgroundTasks

@main
struct SleepWellApp: App {
    @StateObject private var themeManager = ThemeManager.shared
    
    init() {
        // 设置音频会话
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category: \(error)")
        }
        
        // 注册后台任务
        UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        
        // 确保应用启动时设置音频会话和注册后台任务
        setupAudioSession()
        registerBackgroundTasks()
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(themeManager.networkManager)
                .environmentObject(themeManager.guardianManager)
                .environmentObject(themeManager.playlistController)
                .environmentObject(themeManager.dualStreamPlayerController)
 //               .environmentObject(themeManager.sleepMonitorController)
                .environmentObject(themeManager.sleepLogManager)
                .preferredColorScheme(.dark)
        }
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("音频会话设置失败: \(error)")
        }
    }
    
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.han.sleepwell2024.ios.refresh", using: nil) { task in
            self.handleBackgroundRefresh(task: task as! BGAppRefreshTask)
        }
        
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.han.sleepwell2024.ios.processing", using: nil) { task in
            self.handleBackgroundProcessing(task: task as! BGProcessingTask)
        }
    }
    
    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        // 调度下一次后台刷新
        scheduleBackgroundRefresh()
        
        // 执行后台刷新任务
        task.setTaskCompleted(success: true)
    }
    
    private func handleBackgroundProcessing(task: BGProcessingTask) {
        // 调度下一次后台处理
        scheduleBackgroundProcessing()
        
        // 执行后台处理任务
        task.setTaskCompleted(success: true)
    }
    
    private func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: "com.han.sleepwell2024.ios.refresh")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15分钟后
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("无法调度后台刷新: \(error)")
        }
    }
    
    private func scheduleBackgroundProcessing() {
        let request = BGProcessingTaskRequest(identifier: "com.han.sleepwell2024.ios.processing")
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("无法调度后台处理: \(error)")
        }
    }
} 
