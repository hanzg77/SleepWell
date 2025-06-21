import Foundation
import SwiftUI

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published var currentLanguage: String {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: "AppLanguage")
            NotificationCenter.default.post(name: Notification.Name("LanguageChanged"), object: nil)
        }
    }
    
    // 支持的语言列表
    static let supportedLanguages = [
        "zh",  // 简体中文
        "zh-hant",  // 繁体中文
        "en",       // 英文
        "ja"        // 日文
    ]
    
    private init() {
        // 获取系统语言
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        let languageCode = Locale(identifier: preferredLanguage).languageCode ?? "en"
        
        // 检查是否支持该语言
        if let savedLanguage = UserDefaults.standard.string(forKey: "AppLanguage") {
            currentLanguage = savedLanguage
        } else if Self.supportedLanguages.contains(languageCode) {
            currentLanguage = languageCode
        } else if preferredLanguage.hasPrefix("zh") {
            // 处理中文的不同变体
            if preferredLanguage.contains("Hant") || preferredLanguage.contains("TW") || preferredLanguage.contains("HK") {
                currentLanguage = "zh-hant"
            } else {
                currentLanguage = "zh"
            }
        } else {
            // 默认使用英文
            currentLanguage = "en"
        }
    }
    
    // 获取本地化字符串
    func localizedString(_ key: String) -> String {
        let path = Bundle.main.path(forResource: currentLanguage, ofType: "lproj")
        let bundle = path != nil ? Bundle(path: path!) : Bundle.main
        return NSLocalizedString(key, tableName: nil, bundle: bundle ?? Bundle.main, value: key, comment: "")
    }
    
    // 获取带参数的本地化字符串
    func localizedString(_ key: String, _ arguments: CVarArg...) -> String {
        let format = localizedString(key)
        return String(format: format, arguments: arguments)
    }
}

// 扩展 String 以支持本地化
extension String {
    var localized: String {
        return LocalizationManager.shared.localizedString(self)
    }
    
    func localized(_ arguments: CVarArg...) -> String {
        return String(format: LocalizationManager.shared.localizedString(self), arguments: arguments)
    }
} 
