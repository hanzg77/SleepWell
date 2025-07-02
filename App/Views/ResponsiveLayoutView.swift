import SwiftUI

struct ResponsiveLayoutView<Content: View>: View {
    @ObservedObject private var orientationManager = OrientationManager.shared
    let content: (Bool) -> Content // Bool参数表示是否为横屏
    
    init(@ViewBuilder content: @escaping (Bool) -> Content) {
        self.content = content
    }
    
    var body: some View {
        content(orientationManager.isLandscape)
            .animation(.easeInOut(duration: 0.3), value: orientationManager.isLandscape)
    }
}

// MARK: - 响应式网格布局
struct ResponsiveGridLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    @ObservedObject private var orientationManager = OrientationManager.shared
    let data: Data
    let content: (Data.Element) -> Content
    
    // 根据方向调整列数
    private var columns: Int {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return orientationManager.isLandscape ? 4 : 3
        } else {
            return 2
        }
    }
    
    init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.content = content
    }
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: columns), spacing: 16) {
            ForEach(data) { item in
                content(item)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: columns)
    }
}

// MARK: - 响应式间距
struct ResponsiveSpacing: ViewModifier {
    @ObservedObject private var orientationManager = OrientationManager.shared
    
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, orientationManager.isLandscape ? 32 : 16)
            .animation(.easeInOut(duration: 0.3), value: orientationManager.isLandscape)
    }
}

extension View {
    func responsiveSpacing() -> some View {
        modifier(ResponsiveSpacing())
    }
}

// MARK: - 响应式字体大小
struct ResponsiveFont: ViewModifier {
    @ObservedObject private var orientationManager = OrientationManager.shared
    let baseSize: CGFloat
    
    init(_ size: CGFloat) {
        self.baseSize = size
    }
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: orientationManager.isLandscape ? baseSize * 1.2 : baseSize))
            .animation(.easeInOut(duration: 0.3), value: orientationManager.isLandscape)
    }
}

extension View {
    func responsiveFont(_ size: CGFloat) -> some View {
        modifier(ResponsiveFont(size))
    }
} 