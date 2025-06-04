import AVFoundation
import OSLog
import UIKit
import Combine

class MediaPlayerController: NSObject, ObservableObject {
    // MARK: - 属性
    @Published var isPlaying: Bool = false
    let logger = Logger(subsystem: "com.sleepwell", category: "MediaPlayer")
    
    // MARK: - 初始化
    override init() {
        super.init()
        setupAudioSession()
    }
    
    // MARK: - 音频会话设置
    func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // 设置音频会话为后台播放模式
            try session.setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP])
            try session.setActive(true)
            
            // 设置音频会话优先级
            try session.setPreferredIOBufferDuration(0.005)
            try session.setPreferredSampleRate(44100.0)
            
            // 注册远程控制事件
            UIApplication.shared.beginReceivingRemoteControlEvents()
            
            // 设置音频会话中断处理
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleInterruption),
                name: AVAudioSession.interruptionNotification,
                object: nil
            )
            
            // 设置音频会话路由变化处理
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleRouteChange),
                name: AVAudioSession.routeChangeNotification,
                object: nil
            )
            
            logger.info("音频会话设置成功")
        } catch {
            logger.error("音频会话设置失败: \(error)")
        }
    }
    
    // MARK: - 播放控制
    func play() {
        isPlaying = true
    }
    
    func pause() {
        isPlaying = false
    }
    
    func stop() {
        isPlaying = false
    }
    
    // MARK: - 音频会话处理
    @objc func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // 中断开始，暂停播放
            pause()
        case .ended:
            // 中断结束，恢复播放
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else { return }
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                play()
            }
        @unknown default:
            break
        }
    }
    
    @objc func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .oldDeviceUnavailable:
            // 设备断开连接，暂停播放
            pause()
        case .newDeviceAvailable:
            // 新设备连接，恢复播放
            play()
        default:
            break
        }
    }
    
    // MARK: - 清理
    func cleanup() {
        NotificationCenter.default.removeObserver(self)
        UIApplication.shared.endReceivingRemoteControlEvents()
    }
    
    deinit {
        cleanup()
    }
} 