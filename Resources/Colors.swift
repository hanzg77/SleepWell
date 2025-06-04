import SwiftUI

extension Color {
    // 主色调
    static let nightBlue = Color(hex: "1A2B4C")
    
    // 点缀色
    static let warmBeige = Color(hex: "F5E7B9")
    static let softPurple = Color(hex: "C8BFE7")
    static let lightGreen = Color(hex: "E7F5E7")
    
    // 睡眠状态颜色
    static let preparingColor = Color(hex: "C8BFE7") // 淡紫
    static let lightSleepColor = Color(hex: "E7F5E7") // 浅绿
    static let deepSleepColor = Color(hex: "1A2B4C") // 深夜蓝
    static let remSleepColor = Color(hex: "8BA3D9") // 中蓝
    static let awakeColor = Color(hex: "F5F5F5") // 浅灰
    
    // 背景色
    static let backgroundDark = Color(hex: "0A0A0A")
    static let ringBackground = Color(hex: "1A1A1A")
}

// 十六进制颜色扩展
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
} 