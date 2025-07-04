import Foundation

extension Notification.Name {
    static let playerDidStartPlaying = Notification.Name("playerDidStartPlaying")
    static let playerDidPause = Notification.Name("playerDidPause")
    static let playerDidStop = Notification.Name("playerDidStop")
    static let guardianModeDidEnd = Notification.Name("guardianModeDidEnd")
    static let guardianModeDidStart = Notification.Name("guardianModeDidStart")
    static let guardianModeDidChange = Notification.Name("guardianModeDidChange")
    // 播放进度相关
    static let playbackProgressUpdated = Notification.Name("playbackProgressUpdated")
    static let playbackDidFinish = Notification.Name("playbackDidFinish")
    // 其他全局通知名可在此统一添加
} 
