import Foundation

class PlaybackProgressManager {
    static let shared = PlaybackProgressManager()
    
    // 缓存所有资源的进度
    private var progressCache: [String: Double] = [:]
    private let progressCacheKeyPrefix = "playback_progress_"
    
    private init() {}
    
    // 获取单个资源的进度
    func getProgress(for resourceId: String) -> Double {
        if let cached = progressCache[resourceId] {
            return cached
        }
        let key = progressCacheKeyPrefix + resourceId
        let progress = UserDefaults.standard.double(forKey: key)
        progressCache[resourceId] = progress
        return progress
    }
    
    // 批量获取资源进度
    func getProgresses(for resourceIds: [String]) -> [String: Double] {
        var result: [String: Double] = [:]
        for id in resourceIds {
            result[id] = getProgress(for: id)
        }
        return result
    }
    
    // 保存进度
    func saveProgress(_ progress: Double, for resourceId: String) {
        let key = progressCacheKeyPrefix + resourceId
        UserDefaults.standard.set(progress, forKey: key)
        progressCache[resourceId] = progress
    }
    
    // 清除缓存
    func clearCache() {
        progressCache.removeAll()
    }
} 