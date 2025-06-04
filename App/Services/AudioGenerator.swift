import Foundation
import AVFoundation

class AudioGenerator {
    private static var engine: AVAudioEngine?
    private static var sourceNode: AVAudioSourceNode?
    
    static func generateWhiteNoise() -> URL? {
        // 设置音频会话
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("设置音频会话失败: \(error.localizedDescription)")
            return nil
        }
        
        // 创建音频引擎
        engine = AVAudioEngine()
        guard let engine = engine else { return nil }
        
        // 创建音频格式
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        
        // 创建白噪音源节点
        sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                let value = Float32(arc4random_uniform(1000)) / 500.0 - 1.0
                for channel in 0..<Int(ablPointer.count) {
                    let buf = ablPointer[channel]
                    let bufData = buf.mData?.assumingMemoryBound(to: Float32.self)
                    bufData?[frame] = value
                }
            }
            return noErr
        }
        
        guard let sourceNode = sourceNode else { return nil }
        
        // 连接节点
        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
        
        // 启动引擎
        do {
            try engine.start()
            print("音频引擎已启动")
            return URL(string: "white_noise://") // 返回一个虚拟 URL
        } catch {
            print("启动音频引擎失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    static func stopWhiteNoise() {
        engine?.stop()
        engine = nil
        sourceNode = nil
    }
} 
