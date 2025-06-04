import Foundation
import AVFoundation
import Combine
import BackgroundTasks
import CoreMotion
import UIKit
import UserNotifications

enum SleepMode {
    case auto
    case timer(seconds: Int)
}

class SleepMonitor: ObservableObject {
    @Published var currentSession = SleepSession()
    @Published var isMonitoring = false
    @Published var audioPlayer: AVAudioPlayer?
    @Published var isAudioPlaying = false
    @Published var remainingTime: TimeInterval = 0
    @Published var showEndMessage = false
    @Published var currentMode: SleepMode = .auto
    
    private var timer: Timer?
    private var audioSession: AVAudioSession?
    private let motionManager = CMMotionManager()
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var subtleBackgroundPlayer: AVAudioPlayer?
    private var interruptionObserver: NSObjectProtocol?
    
    init() {
        setupMotionManager()
        setupAudioSessionInterruptionHandling()
        requestNotificationPermission()
    }
    
    deinit {
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupAudioSessionInterruptionHandling() {
        // 监听音频会话中断通知
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            
            guard let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                return
            }
            
            switch type {
            case .began:
                // 中断开始，暂停播放
                self.handleInterruptionBegan()
            case .ended:
                // 中断结束，恢复播放
                guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                self.handleInterruptionEnded(shouldResume: options.contains(.shouldResume))
            @unknown default:
                break
            }
        }
    }
    
    private func handleInterruptionBegan() {
        // 中断开始时的处理
        subtleBackgroundPlayer?.pause()
        isAudioPlaying = false
        
        // 如果是定时器模式，可能需要特殊处理
        if case .timer = currentMode {
            // 可以选择是否在中断期间暂停计时
            // timer?.invalidate()
        }
    }
    
    private func handleInterruptionEnded(shouldResume: Bool) {
        // 中断结束时的处理
        if shouldResume {
            do {
                try audioSession?.setActive(true)
                subtleBackgroundPlayer?.play()
                isAudioPlaying = true
            } catch {
                print("恢复音频播放失败: \(error.localizedDescription)")
            }
        } else {
            // 如果不需要恢复，可能需要停止监测
            stopMonitoring()
        }
    }
    
    private func setupMotionManager() {
        motionManager.deviceMotionUpdateInterval = 1.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }
            // 处理动作数据
            self.processMotionData(motion)
        }
    }
    
    private func processMotionData(_ motion: CMDeviceMotion) {
        // 根据动作数据判断睡眠状态
        // 这里可以添加具体的睡眠状态判断逻辑
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("通知权限已获取")
            } else if let error = error {
                print("通知权限请求失败: \(error.localizedDescription)")
            }
        }
    }
    
    private func sendAudioControlNotification() {
        let content = UNMutableNotificationContent()
        content.title = "睡眠监测"
        content.body = "点击暂停其他应用的音频"
        content.sound = .default
        
        // 添加快捷操作
        let action = UNNotificationAction(
            identifier: "PAUSE_OTHER_AUDIO",
            title: "暂停其他音频",
            options: .foreground
        )
        let category = UNNotificationCategory(
            identifier: "AUDIO_CONTROL",
            actions: [action],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
        content.categoryIdentifier = "AUDIO_CONTROL"
        
        // 创建通知请求
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        // 发送通知
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("发送通知失败: \(error.localizedDescription)")
            }
        }
    }
    
    // 切换到独占模式
    private func changeAudioSessionToExclusiveMode() {
        // 停止当前播放
        subtleBackgroundPlayer?.stop()
        isAudioPlaying = false
        
        // 启动后台任务
        var backgroundTask: UIBackgroundTaskIdentifier = .invalid
        backgroundTask = UIApplication.shared.beginBackgroundTask {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
        
        // 发送通知，让用户可以通过快捷操作控制音频
        sendAudioControlNotification()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let session = self.audioSession else {
                print("音频会话或 self 不可用")
                self?.endBackgroundTask()
                return
            }
            
            do {
                // 先停用当前会话
                try session.setActive(false, options: .notifyOthersOnDeactivation)
                
                // 设置音频会话为独占模式
                try session.setCategory(.playback, mode: .default, options: [])
                
                // 设置音频会话参数
                try session.setPreferredIOBufferDuration(0.005)
                try session.setPreferredSampleRate(44100.0)
                
                // 激活音频会话
                try session.setActive(true)
                
                // 延迟后释放音频焦点
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                    do {
                        try self?.audioSession?.setActive(false, options: .notifyOthersOnDeactivation)
                        self?.isAudioPlaying = false
                        print("成功释放音频焦点")
                    } catch {
                        print("释放音频焦点失败: \(error)")
                    }
                    self?.endBackgroundTask()
                }
            } catch {
                print("音频设置失败: \(error)")
                self.endBackgroundTask()
            }
        }
    }
    
    // 设置初始音频会话（混合模式）
    private func setupInitialAudioSessionForMixing() {
        do {
            audioSession = AVAudioSession.sharedInstance()
            // 使用混合模式，允许与其他应用混音
            try audioSession?.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession?.setActive(true)
        } catch {
            print("音频会话设置失败: \(error.localizedDescription)")
        }
    }
    
    // 开始监测
    func startMonitoring(mode: SleepMode) {
        isMonitoring = true
        currentSession = SleepSession()
        currentSession.startTime = Date()
        currentSession.isActive = true
        currentMode = mode
        
        // 设置初始音频会话（混合模式）
        setupInitialAudioSessionForMixing()
        
        // 添加初始准备状态
        addTimeBlock(state: .preparing)
        
        switch mode {
        case .auto:
            // 启动定时器模拟状态变化
            startStateSimulation()
        case .timer(let seconds):
            // 设置定时器
            remainingTime = TimeInterval(seconds)
            startTimer()
        }
        
        // 开始后台任务
        beginBackgroundTask()
    }
    
    // 停止监测
    func stopMonitoring() {
        isMonitoring = false
        currentSession.endTime = Date()
        currentSession.isActive = false
        timer?.invalidate()
        timer = nil
        remainingTime = 0
        
        // 停止背景音
        subtleBackgroundPlayer?.stop()
        isAudioPlaying = false
        
        // 显示结束提示
        showEndMessage = true
        
        // 3秒后隐藏提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.showEndMessage = false
        }
        
        // 结束后台任务
        endBackgroundTask()
    }
    
    // 开始后台任务
    private func beginBackgroundTask() {
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        
        // 确保音频会话在后台保持活跃
        do {
            // 保持当前音频会话配置
            try audioSession?.setActive(true)
        } catch {
            print("设置后台音频会话失败: \(error.localizedDescription)")
        }
    }
    
    // 结束后台任务
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    // 添加时间块
    private func addTimeBlock(state: SleepState) {
        let startTime = Date()
        let endTime = startTime.addingTimeInterval(300) // 5分钟一个状态
        let block = TimeBlock(state: state, startTime: startTime, endTime: endTime)
        currentSession.timeBlocks.append(block)
    }
    
    // 模拟状态变化
    private func startStateSimulation() {
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let states: [SleepState] = [.lightSleep, .deepSleep, .remSleep, .awake]
            let randomState = states.randomElement() ?? .awake
            self.addTimeBlock(state: randomState)
            
            // 当检测到用户睡着时，切换到独占模式
            if randomState != .awake {
                self.changeAudioSessionToExclusiveMode()
            }
        }
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.remainingTime > 0 {
                self.remainingTime -= 1
            } else {
                // 定时结束时，切换到独占模式
                self.changeAudioSessionToExclusiveMode()
                self.stopMonitoring()
            }
        }
    }
    
    // 音频控制
    func toggleAudio() {
        if isAudioPlaying {
            audioPlayer?.pause()
        } else {
            audioPlayer?.play()
        }
        isAudioPlaying.toggle()
    }
} 
