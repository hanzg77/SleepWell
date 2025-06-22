DualStreamPlayerController 设计文档
1. 概述 (Overview)
DualStreamPlayerController 是应用的核心播放控制器。它的主要职责是管理和同步独立的音频流和视频流（双流播放），为用户提供沉浸式的背景播放体验。它与UI层（DualStreamPlayerView）紧密协作以展示视频和控制界面，并响应来自业务逻辑层（如 PlaylistController 和 GuardianController）的指令。

该设计遵循关注点分离 (Separation of Concerns) 的原则，将播放器核心逻辑、UI动画和定时器功能解耦到不同的模块中，使得系统更易于维护和扩展。

DualStreamPlayerController: 负责媒体资源的加载、播放、暂停、停止和状态同步。
DualStreamPlayerView: 负责视频画面的渲染、UI控件的布局以及视频背景的平移动画。
GuardianController: 负责独立的播放定时器逻辑（守护模式）。
2. 核心功能设计 (Core Feature Design)
2.1 双流播放 (Dual Stream Playback)
目标: 为了在保证音频质量的同时提供动态视觉效果，系统需要能够同时播放一个来自 DualResource 的高质量音频 (audioUrl) 和一个视频 (videoUrl)。

设计思路:

内部播放器: DualStreamPlayerController 内部维护两个独立的 AVPlayer 实例：一个用于音频 (audioPlayer)，一个用于视频 (videoPlayer)。
数据源: 当外部调用 play(resource: DualResource) 方法时，控制器会根据传入资源的 audioUrl 和 videoUrl 分别创建 AVPlayerItem，并设置给对应的播放器。
播放控制与同步:
播放/暂停操作 (play, pause, resume) 会被同时应用到 audioPlayer 和 videoPlayer 上，以确保音视频的启停同步。
播放状态（如 isPlaying, currentTime, duration）由音频播放器 (audioPlayer) 作为主要数据源。视频播放器仅作为视觉呈现，其播放进度被动地与音频播放器保持一致。
状态发布: 控制器通过 @Published 属性向外暴露播放状态（如 isPlaying, currentTime, currentResource）和视频播放器实例 (videoPlayer)，供 SwiftUI 视图 (DualStreamPlayerView) 订阅和响应。
代码关联:

DualResource.swift: 定义了 audioUrl 和 videoUrl，是双流的数据基础。
PlaylistController.swift: 调用 DualStreamPlayerController.shared.play(resource:) 来启动播放流程。
DualStreamPlayerView.swift: 订阅 playerController.videoPlayer 来渲染视频画面。
2.2 视频平移动画 (Video Panning Animation)
目标: 为了避免静态视频背景带来的单调感，视频画面需要在播放时进行缓慢、平滑的水平移动，创造出类似“肯·伯恩斯效果”(Ken Burns Effect)的动态体验。

设计思路:

责任分离: 视频的动画效果是一个纯粹的 UI 表现层 逻辑。因此，DualStreamPlayerController 不参与任何动画计算，它仅负责提供一个准备就绪的 videoPlayer 实例。
视图层实现 (DualStreamPlayerView):
尺寸计算: 在 GeometryReader 中，根据屏幕的高度和 16:9 的视频宽高比，计算出视频视图的宽度，使其超出屏幕宽度。
状态驱动: 使用一个 @State 变量 startPanning 来控制动画的启停。
动画应用:
通过 .offset(x: ...) 修改器来改变视频视图的水平位置。当 startPanning 为 true 时，目标偏移量为视频超出屏幕的总宽度。
使用 .animation(.linear(duration: 30).repeatForever(autoreverses: true), value: startPanning) 来创建一个持续30秒、无限循环且自动往返的线性动画。
生命周期管理: 动画的启动和停止与视频内容 (videoPlayer.currentItem) 的生命周期绑定。当一个新的视频项加载时，startPanning 被触发为 true；当视频项被移除时，则为 false。
代码关联:

DualStreamPlayerView.swift:
swift
 Show full code block 
// 伪代码，展示核心逻辑
let videoWidth = geometry.size.height * 16/9
let totalDistance = videoWidth - geometry.size.width

VideoPlayerView(player: playerController.videoPlayer)
    .frame(width: videoWidth, height: geometry.size.height)
    .offset(x: startPanning ? -totalDistance : 0)
    .animation(
        .linear(duration: 30).repeatForever(autoreverses: true),
        value: startPanning
    )
2.3 播放定时功能 (Playback Timer Functionality)
目标: 用户可以设置一个预定的时间（如30分钟、1小时或整夜），在时间到达后自动停止播放。

设计思路:

责任分离: 定时器逻辑被完全封装在独立的 GuardianController 中。DualStreamPlayerController 对定时器的具体模式和倒计时一无所知，它只关心何时需要停止播放。
GuardianController 的职责:
管理定时器模式 (GuardianMode) 和倒计时状态 (countdown, isGuardianModeEnabled)。
通过 Timer 实现秒级倒计时。
当倒计时结束时，通过 NotificationCenter 发送一个全局通知，例如 .guardianModeDidEnd。
DualStreamPlayerController 的职责:
在初始化时，订阅 GuardianController 发出的 .guardianModeDidEnd 通知。
当接收到该通知时，调用自身的 pause() 或 stop() 方法来停止媒体播放。
UI (DualStreamPlayerView) 的职责:
从 guardianController 获取并显示当前的倒计时时间。
提供 TimerOptionButton 等UI控件，允许用户调用 guardianController.enableGuardianMode() 来切换和启动不同的定时模式。
交互流程示例:

用户在 DualStreamPlayerView 中点击“1小时”按钮。
TimerOptionButton 调用 guardianController.enableGuardianMode(.timedClose3600)。
GuardianController 启动一个3600秒的倒计时，并更新其 @Published 属性。
DualStreamPlayerView 监听到 guardianController.countdown 的变化并刷新UI。
1小时后，GuardianController 的 Timer 触发，发送 .guardianModeDidEnd 通知。
DualStreamPlayerController 监听到通知，执行 self.pause()。
音频和视频同步暂停。
3. 总结 (Conclusion)
该系统通过将播放器核心、UI动画和业务逻辑（定时器）清晰地分离开来，构建了一个健壮且可维护的播放体系。DualStreamPlayerController 专注于其核心使命——媒体同步与控制，而将其他职责委托给专门的模块，这使得每个部分都易于理解、测试和修改。
