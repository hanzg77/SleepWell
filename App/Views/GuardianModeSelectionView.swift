import SwiftUI

struct GuardianModeSelectionView: View {
    let resource: Resource
    let episode: Episode?
    @StateObject private var viewModel: GuardianModeSelectionViewModel
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var guardianManager: GuardianController
    @Binding var selectedTab: Int
    @State private var guardianViewItem: GuardianViewItem?
    var onModeSelected: ((GuardianMode) -> Void)?
    
    init(resource: Resource, episode: Episode? = nil, selectedTab: Binding<Int>, onModeSelected: ((GuardianMode) -> Void)? = nil) {
        self.resource = resource
        self.episode = episode
        self._selectedTab = selectedTab
        self.onModeSelected = onModeSelected
        _viewModel = StateObject(wrappedValue: GuardianModeSelectionViewModel(
            resource: resource,
            episode: episode,
            guardianManager: GuardianController.shared
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
            Text("guardianModeSelection.title".localized)
                .font(.headline)
                .foregroundColor(.white)
                .padding(.top, 16)
            
            ScrollView {
                VStack(spacing: 20) {
                    // 模式选择按钮
                    ForEach(GuardianMode.allCases, id: \.self) { mode in
                        Button(action: {
                            selectedTab = 1  // 切换到守护睡眠页面
                            dismiss()  // 先关闭当前视图
                            DispatchQueue.main.async {
                                // 先选择模式
                                viewModel.selectMode(mode)
                                // 然后触发回调
                                onModeSelected?(mode)
                            }
                        }) {
                            HStack {
                                // 可选：根据模式显示不同图标
                                Image(systemName: mode == .smartDetection ? "brain.head.profile" : (mode == .unlimited ? "infinity" : "timer"))
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
    /*    .sheet(item: $guardianViewItem) { _ in
            GuardianView()
                .environmentObject(GuardianController.shared)
        }
     */
    }
}
/*
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
*/
// 选项按钮
struct GuardianModeButton: View {
    let mode: GuardianMode
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.displayTitle)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text(mode.displayDescription)
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

// 用于 sheet 的标识符
struct GuardianViewItem: Identifiable {
    let id = UUID()
}
