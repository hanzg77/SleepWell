import SwiftUI

struct MoodSelectionBannerView: View {
    let onMoodSelected: (Mood) -> Void
    @Binding var isPresented: Bool

    var body: some View {
        if isPresented {
            ZStack {
                // 1. 调整背景暗度，使其更突出内容卡片
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.25)) {
                            isPresented = false
                        }
                    }
                
                // 2. 内容卡片，使用单一背景材质
                VStack(alignment: .leading, spacing: 16) { // 调整主 VStack 间距
                    Text("moodSelectionBanner.title".localized)
                        .font(.system(.title3, design: .rounded).weight(.semibold)) // 调整字体
                        .foregroundColor(.primary) // 使用 .primary 以适应材质背景
                        .padding(.horizontal, 4) // 微调标题内边距

                    // 3. 使用 LazyVGrid 实现两行三列布局
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 12 // 调整网格间距
                    ) {
                        ForEach(Mood.allCases, id: \.self) { mood in
                            Button(action: {
                                withAnimation(.easeOut(duration: 0.25)) {
                                    isPresented = false
                                }
                                // 动画结束后执行回调
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    onMoodSelected(mood)
                                }
                            }) {
                                VStack(spacing: 8) { // 调整 Emoji 和文字间距
                                    Text(mood.iconName)
                                        .font(.system(size: 32)) // 稍大一点的 Emoji
                                        .foregroundColor(.primary)
                                    Text(mood.displayName)
                                        .font(.system(.caption, design: .rounded)) // 调整字体
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16) // 增加垂直内边距，使按钮更高
                                .background(Color.primary.opacity(0.05)) // 更微妙的按钮背景
                                .cornerRadius(12) // 统一圆角
                            }
                            .buttonStyle(.plain) // 移除默认按钮样式，以便自定义背景生效
                        }
                    }
                }
                .padding(20) // 卡片内边距
                .background(.thinMaterial) // 使用 .thinMaterial 或 .regularMaterial
                .cornerRadius(20) // 调整圆角
                .padding(.horizontal, 24) // 卡片与屏幕边缘的间距
                .transition(.move(edge: .bottom).combined(with: .opacity)) // 更改出
            }
            .zIndex(100)
        }
    }
}
/*
// 用于圆角扩展
fileprivate extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

fileprivate struct RoundedCorner: Shape {
    var radius: CGFloat = 12.0
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

*/
