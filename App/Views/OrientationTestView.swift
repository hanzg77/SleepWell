import SwiftUI

struct OrientationTestView: View {
    @ObservedObject private var orientationManager = OrientationManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("iPad方向测试")
                .font(.title)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("当前方向: \(orientationManager.orientationDescription)")
                    .foregroundColor(.blue)
                
                Text("设备类型: \(UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone")")
                    .foregroundColor(.green)
                
                Text("横屏模式: \(orientationManager.isLandscape ? "是" : "否")")
                    .foregroundColor(.orange)
                
                Text("竖屏模式: \(orientationManager.isPortrait ? "是" : "否")")
                    .foregroundColor(.purple)
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
            
            // 方向图标
            Image(systemName: orientationManager.isLandscape ? "rectangle" : "rectangle.portrait")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
            
            // 测试网格
            ResponsiveGridLayout(Array(1...6).map { MockItem(id: $0) }) { item in
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.3))
                    .frame(height: 80)
                    .overlay(
                        Text("\(item.id)")
                            .foregroundColor(.white)
                            .font(.title2)
                    )
            }
            .responsiveSpacing()
            
            Spacer()
        }
        .padding()
        .background(Color.black)
        .navigationTitle("方向测试")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    OrientationTestView()
} 