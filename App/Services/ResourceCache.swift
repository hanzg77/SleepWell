import Foundation

class ResourceCache {
    static let shared = ResourceCache()
    private var cache: [String: [String: LocalizedContent]] = [:] // resourceId: [language: content]
    
    private init() {}
    
    func cacheContent(_ content: LocalizedContent, for resourceId: String, language: String) {
        if cache[resourceId] == nil {
            cache[resourceId] = [:]
        }
        cache[resourceId]?[language] = content
    }
    
    func getContent(for resourceId: String, language: String) -> LocalizedContent? {
        return cache[resourceId]?[language]
    }
    
    func clearAllCache() {
        cache.removeAll()
    }
    
    func clearCacheForResource(_ resourceId: String) {
        cache.removeValue(forKey: resourceId)
    }
    
    func clearCacheForLanguage(_ language: String) {
        for (resourceId, _) in cache {
            cache[resourceId]?.removeValue(forKey: language)
        }
    }
} 