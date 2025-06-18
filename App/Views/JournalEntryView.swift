import SwiftUI

// 假设 Mood enum 及其属性已在项目的其他地方定义
// struct Mood { ... }

struct JournalEntryView: View {
    // MARK: - Properties
    let mood: Mood
    let onSave: (String) -> Void
    @Binding var isPresented: Bool
    
    @State private var content: String = ""
    @State private var isSealing: Bool = false
    @State private var showCompletion: Bool = false
    
    @FocusState private var isTextEditorFocused: Bool

    // MARK: - Body
    var body: some View {
            // 主要UI层
        
        mainContentView
        .padding(.bottom, 60)
         //   .edgesIgnoringSafeArea(.bottom) // 让 safeAreaInset 能控制最底部
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isTextEditorFocused = true
                print("onAppear")   
            }
        }
        .preferredColorScheme(.dark)
        // 将动画应用在最外层，以获得更平滑的整体过渡
      //  .animation(.easeInOut(duration: 0.4), value: isSealing)
       // .animation(.easeInOut(duration: 0.4), value: showCompletion)
    }

    // MARK: - Subviews

    /// 将主内容和完成提示包装起来，以便控制动画和布局
    private var mainContentView: some View {
        ZStack {
            // 毛玻璃背景和主要卡片内容
            VStack(spacing: 0) {
                // 背景
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .onTapGesture {
                        isTextEditorFocused = false
                        print("点击了背景1" )
                    }
            }
            
            // 卡片式布局
            ScrollView {
                VStack(spacing: 24) {
                    headerView
                    moodPromptView
                    textEditorView
                    saveButton
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.black.opacity(0.3))
                )
                .padding(.horizontal, 16)
                .padding(.top, 20)
            }
            .onTapGesture {
                isTextEditorFocused = false
                print("点击了背景")
            }
            .scrollDismissesKeyboard(.interactively) // iOS 16+
            .opacity(isSealing || showCompletion ? 0 : 1)
     /*       .safeAreaInset(edge: .bottom) {
                // 保存按钮
                saveButton
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(Color.black.opacity(0.3))
            }
          */
            // 完成提示
            if showCompletion {
                completionView
                    .transition(.opacity)
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            Spacer()
            Button(action: {
                isTextEditorFocused = false
                isPresented = false
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(8)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
        }
    }

    private var moodPromptView: some View {
        VStack(spacing: 12) {
            Image(systemName: mood.iconName)
                .font(.system(size: 36))
                .foregroundColor(.white)
                .symbolRenderingMode(.hierarchical)
            
            Text(mood.displayName)
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(journalPrompt(for: mood))
                .font(.system(.body, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }

    private var textEditorView: some View {
        TextEditor(text: $content)
            .focused($isTextEditorFocused)
            .scrollContentBackground(.hidden) // For iOS 16+
            .frame(minHeight: 150, maxHeight: 250)
            .foregroundColor(.white)
            .font(.system(.body, design: .serif))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .overlay(alignment: .topLeading) {
                if content.isEmpty {
                    Text("journalEntry.placeholder".localized)
                        .font(.system(.body, design: .serif))
                        .foregroundColor(.white.opacity(0.35))
                        .padding(.horizontal, 21)
                        .padding(.vertical, 20)
                        .allowsHitTesting(false)
                }
            }
    }

    /// --- 按钮修正 3: 调整按钮大小 ---
    private var saveButton: some View {
        Button(action: handleSave) {
            Text("journalEntry.sealThoughts.button".localized)
                .font(.system(.headline, design: .rounded).weight(.semibold))
                .foregroundColor(.white) // 文字使用高對比度的純白色
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity)
                // --- 核心修改 ---
                // 使用和背景一致的毛玻璃材質
                .background(.ultraThinMaterial)
        }
        // --- 核心修改 ---
        // 1. 使用圓角矩形
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        // 2. （可選）在按鈕上再疊加一個非常細的邊框，增加立體感
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .disabled(content.isEmpty)
        .opacity(content.isEmpty ? 0.6 : 1.0)
        .animation(.easeInOut, value: content.isEmpty)
    }
    
    private var completionView: some View {
        VStack {
            Text("journalEntry.completion.message".localized)
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Methods
    
    private func handleSave() {
        isTextEditorFocused = false
        isSealing = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            onSave(content)
            showCompletion = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                isPresented = false
            }
        }
    }
    
    private func journalPrompt(for mood: Mood) -> String {
        switch mood {
        case .happy: return "journalEntry.prompt.happy".localized
        case .calm: return "journalEntry.prompt.calm".localized
        case .annoyed: return "journalEntry.prompt.annoyed".localized
        case .racingThoughts: return "journalEntry.prompt.racingThoughts".localized
        case .down: return "journalEntry.prompt.down".localized
        }
    }
}
