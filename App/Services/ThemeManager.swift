import SwiftUI

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    // 颜色
    struct Colors {
        static let background = Color.black
        static let cardBackground = Color(white: 0.1)
        static let searchBarBackground = Color(white: 0.2)
        static let textPrimary = Color.red
        static let textSecondary = Color.gray
    }
    
    // 字体
    struct Typography {
        static let title = Font.system(size: 24, weight: .bold)
        static let headline = Font.system(size: 18, weight: .semibold)
        static let body = Font.system(size: 16, weight: .regular)
        static let caption = Font.system(size: 14, weight: .regular)
    }
    
    // 间距
    struct Spacing {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
    }
    
    // 圆角
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
    }
    
    private init() {}
} 
