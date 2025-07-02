import SwiftUI

struct ResponsiveExampleView: View {
    @ObservedObject private var orientationManager = OrientationManager.shared
    
    var body: some View {
        ResponsiveLayoutView { isLandscape in
            VStack(spacing: 20) {
                // 标题
                Text("响应式布局示例")
                    .responsiveFont(24)
                    .foregroundColor(.white)
                
                // 方向信息
                HStack {
                    Image(systemName: orientationManager.isLandscape ? "rectangle" : "rectangle.portrait")
                        .foregroundColor(.blue)
                    Text("当前方向: \(orientationManager.orientationDescription)")
                        .foregroundColor(.gray)
                }
                .responsiveFont(16)
                
                // 响应式网格
                ResponsiveGridLayout(Array(1...8).map { MockItem(id: $0) }) { item in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.3))
                        .frame(height: 100)
                        .overlay(
                            Text("项目 \(item.id)")
                                .foregroundColor(.white)
                        )
                }
                .responsiveSpacing()
                
                Spacer()
            }
            .padding()
            .background(Color.black)
        }
    }
}

// 用于示例的模拟数据
struct MockItem: Identifiable {
    let id: Int
}

#Preview {
    ResponsiveExampleView()
} 