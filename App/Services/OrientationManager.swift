import Foundation
import UIKit
import Combine

class OrientationManager: ObservableObject {
    static let shared = OrientationManager()
    
    @Published var currentOrientation: UIDeviceOrientation = .unknown
    @Published var isLandscape: Bool = false
    @Published var isPortrait: Bool = true
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupOrientationMonitoring()
    }
    
    private func setupOrientationMonitoring() {
        // 监听设备方向变化
        NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateOrientation()
            }
            .store(in: &cancellables)
        
        // 初始化当前方向
        updateOrientation()
    }
    
    private func updateOrientation() {
        let newOrientation = UIDevice.current.orientation
        
        // 只在iPad上处理方向变化
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }
        
        DispatchQueue.main.async {
            self.currentOrientation = newOrientation
            
            switch newOrientation {
            case .landscapeLeft, .landscapeRight:
                self.isLandscape = true
                self.isPortrait = false
                print("🔄 iPad方向变化: 横屏")
            case .portrait, .portraitUpsideDown:
                self.isLandscape = false
                self.isPortrait = true
                print("🔄 iPad方向变化: 竖屏")
            default:
                break
            }
            
            // 发送方向变化通知
            NotificationCenter.default.post(name: .orientationDidChange, object: nil)
        }
    }
    
    /// 获取当前是否为横屏
    var isLandscapeMode: Bool {
        return isLandscape
    }
    
    /// 获取当前是否为竖屏
    var isPortraitMode: Bool {
        return isPortrait
    }
    
    /// 获取当前方向描述
    var orientationDescription: String {
        switch currentOrientation {
        case .portrait:
            return "竖屏"
        case .portraitUpsideDown:
            return "竖屏(倒置)"
        case .landscapeLeft:
            return "横屏(左)"
        case .landscapeRight:
            return "横屏(右)"
        default:
            return "未知"
        }
    }
}

// MARK: - 通知名称扩展
extension Notification.Name {
    static let orientationDidChange = Notification.Name("OrientationDidChange")
} 