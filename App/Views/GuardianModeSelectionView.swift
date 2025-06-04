import SwiftUI

struct GuardianModeSelectionView: View {
    let resource: Resource
    let episode: Episode?
    @StateObject private var viewModel: GuardianModeSelectionViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var guardianManager: GuardianManager
    @EnvironmentObject private var audioManager: AudioManager
    @Binding var selectedTab: Int
    @State private var guardianViewItem: GuardianViewItem?
    
    init(resource: Resource, episode: Episode? = nil, selectedTab: Binding<Int>) {
        self.resource = resource
        self.episode = episode
        self._selectedTab = selectedTab
        _viewModel = StateObject(wrappedValue: GuardianModeSelectionViewModel(
            resource: resource,
            episode: episode,
            guardianManager: GuardianManager.shared,
            audioManager: AudioManager.shared
        ))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 拖拽指示器
            Capsule()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 8)
            
            // 标题
            Text("选择守护模式")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.top, 16)
            
            ScrollView {
                VStack(spacing: 20) {
                    // 模式选择按钮
                    ForEach(GuardianMode.allModes, id: \.self) { mode in
                        Button(action: {
                            selectedTab = 1  // 切换到守护睡眠页面
                            dismiss()  // 先关闭当前视图
                            DispatchQueue.main.async {
                                viewModel.selectMode(mode)
                            }
                        }) {
                            HStack {
                                Image(systemName: mode.icon)
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 40)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(mode.displayTitle)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Text(mode.displayDescription)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(white: 0.1))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
        }
        .background(Color.black)
        .cornerRadius(16, corners: [.topLeft, .topRight])
        .sheet(item: $guardianViewItem) { _ in
            GuardianView()
                .environmentObject(GuardianManager.shared)
                .environmentObject(AudioManager.shared)
        }
    }
}

// 用于设置特定圆角的扩展
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// 选项按钮
struct GuardianModeButton: View {
    let mode: GuardianMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.title)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text(mode.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        Divider()
    }
}

// 更新 GuardianMode 枚举
extension GuardianMode {
    static var allCases: [GuardianMode] {
        [
            .smartDetection,
            .timedClose(60),    // 1分钟
            .timedClose(1800),  // 30分钟
            .timedClose(3600),  // 1小时
            .timedClose(7200)   // 2小时
        ]
    }
    
    var title: String {
        switch self {
        case .smartDetection:
            return "检测入睡后暂停"
        case .timedClose(let duration):
            return "\(formatDuration(duration))后暂停"
        case .unlimited:
            return "整夜播放"
        }
    }
    
    var description: String {
        switch self {
        case .smartDetection:
            return "App 将尝试检测您的入睡状态，并在您睡着后自动暂停播放"
        case .timedClose:
            return "音频将在指定时间后自动停止播放"
        case .unlimited:
            return "音频将持续播放直到您手动停止"
        }
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes >= 60 {
            let hours = minutes / 60
            return "\(hours)小时"
        } else {
            return "\(minutes)分钟"
        }
    }
}

// 用于 sheet 的标识符
struct GuardianViewItem: Identifiable {
    let id = UUID()
}

