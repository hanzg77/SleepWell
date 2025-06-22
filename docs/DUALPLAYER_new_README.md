DualStreamPlayerController 设计文档（集成 YouTube 播放功能）
1. 概述 (Overview)
DualStreamPlayerController 是应用的核心播放控制器。它的主要职责是管理和同步不同的媒体资源流，为用户提供沉浸式的播放体验。在本次更新中，控制器将扩展其能力，在原有的双流（独立音频/视频）播放基础上，新增对 YouTube 视频资源的支持，并为 YouTube 视频提供画中画 (Picture-in-Picture) 播放功能。

该设计继续遵循关注点分离 (Separation of Concerns) 的原则，将播放器核心逻辑、UI 渲染和定时器功能解耦。通过扩展现有的 DualResource 模型，控制器能够优雅地处理不同类型的媒体资源，并分发到对应的播放逻辑，从而最大限度地减少对其他模块的改动。

DualStreamPlayerController: 负责加载、播放、暂停、停止 DualResource 资源，并根据其内部类型分发播放逻辑，同时处理系统级的播放控制。

DualStreamPlayerView: 负责根据当前播放资源的类型，动态渲染原生视频播放器 (AVPlayer) 或 YouTube 播放器 (WKWebView)，并处理相应的 UI 动画与视觉效果。

GuardianController: 负责独立的播放定时器逻辑（守护模式），与播放器核心解耦。

2. 核心功能设计 (Core Feature Design)
2.1 扩展的资源模型 (Extended Resource Model)
目标: 为了让播放控制器能够用统一的接口处理两种完全不同的资源类型（双流 vs. YouTube），我们将在现有的 DualResource 模型上进行扩展。

设计思路:
为 DualResource 增加一个 category 属性（或类似的标识），用以区分资源类型。当需要播放 YouTube 视频时，上层业务逻辑会创建一个 DualResource 实例，将其 category 标记为 youtube，并将 YouTube 视频的 ID 存放在 metadata.videoId 字段中。

控制器接口保持不变: DualStreamPlayerController 的 play 方法签名依然是 play(resource: DualResource)。这确保了所有调用方（如 PlaylistController）无需进行任何修改。

2.2 播放逻辑分发 (Playback Logic Dispatching)
目标: DualStreamPlayerController 需要根据传入的 DualResource 的 category，执行不同的播放设置和清理逻辑。

设计思路:
play 方法内部将检查 resource.category 的值来分发逻辑。

当播放 dualStream 类型的资源时:

执行原有的逻辑：根据 DualResource 中的 audioUrl 和 videoUrl 分别创建 AVPlayerItem。

将 AVPlayerItem 设置给内部的 audioPlayer 和 videoPlayer。

清空任何与 YouTube 相关的状态（例如，将 @Published 属性 currentYouTubeVideoID 设为 nil）。

同时调用两个播放器的 play() 方法。

当播放 youtube 类型的资源时:

停止并清理原有的 AVPlayer 实例。

从传入的 resource.metadata.videoId 中解析出 videoID。

将该 videoID 赋值给新增的 @Published 属性 currentYouTubeVideoID: String?。

DualStreamPlayerView 将订阅此变化并渲染 YouTubePlayerView (WKWebView)。

2.3 YouTube 画中画 (Picture-in-Picture) 支持
目标: 当播放 YouTube 类型的资源时，应用退到后台或用户手动触发时，视频能够以画中画模式继续播放。

设计思路:
此功能完全遵循基于 WKWebView 的合规方案。

App 音频会话设定: 在 App 启动时，必须将全局 AVAudioSession 的类别设置为 .playback。

视图层实现: DualStreamPlayerView 根据 currentYouTubeVideoID 是否有值，来动态渲染 YouTubePlayerView。该视图是一个封装了 WKWebView 的 UIViewRepresentable，并配置了 allowsInlineMediaPlayback = true。

2.4 视频背景动画 (Video Background Animation)
目标: 为双流模式下的背景视频提供平滑的平移动画。

设计思路:
此功能的实现保持不变，但必须明确其适用范围。

适用范围: 此平移动画效果仅适用于 category 为 dualStream 的资源。YouTube 视频的播放由其自身的 IFrame 播放器控制，不应用此自定义的平移动画。

2.5 播放定时功能 (Guardian Mode)
目标: 用户可以设置一个预定的时间，在时间到达后自动停止播放，该功能需对所有类型的资源生效。

设计思路:
原有的解耦设计保持不变。GuardianController 负责倒计时并在结束后发送通知。DualStreamPlayerController 监听通知并调用一个统一的 stop() 方法，该方法被增强以处理所有资源类型。

体验优化: 为提供更佳的“哄睡”体验，定时停止将集成音量淡出效果，具体见 3.2 节。

3. 沉浸式体验增强 (Immersive Experience Enhancements)
为了更好地服务于“哄睡”场景，我们将对 YouTube 播放体验进行视觉和功能上的优化。

3.1 视觉沉浸方案 (Visual Immersion)
目标: 针对 YouTube 资源，最大化减少视觉干扰，营造宁静、沉浸的氛围。

设计思路:

净化播放器界面:

实现: 在 YouTubePlayerView 生成的 HTML 中，为 IFrame API 的 playerVars 添加参数以隐藏所有默认 UI 元素。

// playerVars 示例
{
    'controls': 0,        // 隐藏所有播放控件
    'rel': 0,             // 播放结束后不显示相关视频
    'modestbranding': 1,  // 弱化 YouTube Logo
    'playsinline': 1,
    'autoplay': 1
}

自定义控件: 由于隐藏了原生控件，DualStreamPlayerView 将在 YouTubePlayerView 上方叠加一层 SwiftUI 视图，用于显示一个简洁的、会定时自动隐藏的播放/暂停按钮。

政策合规: 此方案符合 YouTube 服务条款，前提是自定义控件不得以任何形式遮挡、隐藏或干扰广告的展示。

视觉遮罩与效果:

实现: 在 DualStreamPlayerView 中，使用 ZStack 将 YouTubePlayerView 置于底层。在其上方，可以叠加一个或多个效果层：

亮度遮罩: 一个半透明的黑色视图 (Color.black.opacity(0.3))，用于降低视频画面的亮度。

氛围效果: 一个自定义的 SwiftUI 视图（例如 StarrySkyView），用于渲染缓慢移动的星空、光晕等梦幻效果。

效果: 在不改变视频内容本身的情况下，有效降低画面刺激，增强符合睡眠场景的氛围感。

3.2 流程与听觉优化 (Flow and Auditory Optimization)
目标: 提供无缝、不间断的听觉体验，即使用户锁定了屏幕或定时停止播放。

设计思路:

音量淡出停止:

增强 GuardianController: 在倒计时结束前的最后 10 秒，GuardianController 开始发送一个 .guardianModeWillEnd(remainingSeconds: Int) 通知。

增强 DualStreamPlayerController: 控制器监听此新通知，并根据当前播放的资源类型执行相应的音量淡出操作：

dualStream 资源: 启动 Timer 逐步降低 audioPlayer.volume。

youTube 资源: 启动 Timer 通过 evaluateJavaScript 调用 YouTube IFrame API 的 player.setVolume(value) 函数，逐步降低音量。

最终停止: 音量为 0 后，再调用 stop() 方法彻底停止播放。

效果: 避免了声音的突然中断，让用户在无意识中自然过渡到安静状态。

锁屏控制与系统集成:

实现: DualStreamPlayerController 将集成 MPNowPlayingInfoCenter 和 MPRemoteCommandCenter。

信息展示: 当开始播放任何资源时，控制器会更新 MPNowPlayingInfoCenter.default().nowPlayingInfo，向锁屏界面和控制中心提供媒体标题、封面等元数据。

远程控制: 控制器会注册并处理来自系统的远程命令（如播放、暂停、下一首），并调用自身相应的方法（play, pause, playNext 等）。

效果: 让应用表现得像一个专业的系统级播放器，用户体验更完整、更流畅，不会因为想暂停播放而必须解锁手机、打开应用。

4. 总结 (Conclusion)
通过扩展现有的 DualResource 模型并增加类别判断，本次升级将 DualStreamPlayerController 从一个单一用途的控制器，演进为一个能够处理异构媒体资源的播放逻辑分发中心。该设计不仅成功地将新的 YouTube 播放功能（包括合规的画中画实现）无缝集成到现有架构中，还通过一系列沉浸式体验增强方案，如 UI 净化、视觉遮罩、音量淡出和锁屏控制，使产品更贴近“哄睡”的核心目标。整个系统在功能扩展的同时，依然保持了清晰、健壮和可维护的结构。
