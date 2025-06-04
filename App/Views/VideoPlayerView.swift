import SwiftUI
import AVKit
import OSLog

struct VideoPlayerView: View {
    // MARK: - 属性
   // let url: URL
    @StateObject private var controller = VideoPlayerController.shared
    @Environment(\.dismiss) private var dismiss
    
    private let logger = Logger(subsystem: "com.sleepwell", category: "VideoPlayerView")
    
    // MARK: - 视图
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                if let error = controller.error {
                    ErrorView(message: error.localizedDescription)
                }else {
                    VideoPlayer(player: controller.player)
                        .edgesIgnoringSafeArea(.all)
                        .background(Color.black)
                }
            }
        }
        .onAppear {
            logger.info("视频播放器视图出现")
     //       controller.setupPlayer(url: url)
        }
    }
}
