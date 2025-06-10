import SwiftUI

struct MoodSelectionBannerView: View {
    let onMoodSelected: (Mood) -> Void
    @Binding var isPresented: Bool

    var body: some View {
        if isPresented {
            ZStack {
                // 半透明背景，点击时关闭
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) {
                            isPresented = false
                        }
                    }
                
                VStack(spacing: 0) {
                    HStack {
                        Text("心情怎么样？")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.leading, 16)
                        Spacer()
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 4)
                    .background(.ultraThinMaterial)

                    HStack(spacing: 12) {
                        ForEach(Mood.allCases) { mood in
                            Button(action: {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    isPresented = false
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    onMoodSelected(mood)
                                }
                            }) {
                                VStack(spacing: 6) {
                                    Image(systemName: mood.iconName)
                                        .font(.system(size: 28))
                                        .foregroundColor(.white)
                                    Text(mood.displayName)
                                        .font(.caption)
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.12))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                }
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .padding(.horizontal, 16)
                .transition(.opacity)
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
