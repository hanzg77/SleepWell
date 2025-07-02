import SwiftUI
import AVFoundation
import BackgroundTasks
import UMCommon // 引入友盟公共库


@main
struct SleepWellApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    
    init() {
        setupAudioSession()
        registerBackgroundTasks()
        _ = LocalizationManager.shared
        _ = DynamicIslandManager.shared // 初始化灵动岛管理器
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

class AppDelegate: NSObject, UIApplicationDelegate {
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // 友盟 SDK 初始化
        // 请从友盟官网获取您的 AppKey
        UMConfigure.initWithAppkey("6853bb9179267e02108b9125", channel: "App Store")

        // 根据您集成的其他友盟服务（如统计、推送等）进行相应的初始化配置
        // 例如，配置 U-APM (如果集成了)
        // UMConfigure.setAPMEnabled(true)

        print("友盟 SDK 初始化完成")
        

        
        return true
    }

    // 其他 AppDelegate 方法...
}
