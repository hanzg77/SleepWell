import SwiftUI

struct SettingsView: View {
    @StateObject private var localizationManager = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss
    
    let languages = [
        ("en", "English"),
        ("zh-Hans", "简体中文"),
        ("zh-Hant", "繁體中文"),
        ("ja", "日本語")
    ]
    
    var body: some View {
        NavigationView {
            List {
                // 语言设置
                Section(header: Text("settings.language".localized)) {
                    ForEach(languages, id: \.0) { code, name in
                        Button(action: {
                            localizationManager.currentLanguage = code
                        }) {
                            HStack {
                                Text(name)
                                    .foregroundColor(.primary)
                                Spacer()
                                if localizationManager.currentLanguage == code {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                // 主题设置
                Section(header: Text("settings.theme".localized)) {
                    Button(action: {}) {
                        HStack {
                            Text("settings.theme.system".localized)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // 关于
                Section(header: Text("settings.about".localized)) {
                    HStack {
                        Text("settings.version".localized)
                            .foregroundColor(.primary)
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: {}) {
                        Text("settings.privacy".localized)
                            .foregroundColor(.primary)
                    }
                    
                    Button(action: {}) {
                        Text("settings.terms".localized)
                            .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("settings.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Text("action.done".localized)
                    }
                }
            }
        }
    }
} 
