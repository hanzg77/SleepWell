import Foundation

class ResourceCacheManager {
    static let shared = ResourceCacheManager()
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
    
    // MARK: - Disk Cache
    private func cacheDirectory() -> URL? {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        return paths.first?.appendingPathComponent("ResourceCache")
    }
    
    private func cacheFileURL(for resourceId: String, language: String) -> URL? {
        guard let dir = cacheDirectory() else { return nil }
        let fileName = "\(resourceId)_\(language)"
        return dir.appendingPathComponent(fileName)
    }
    
    func saveContentToDisk(_ content: Data, for resourceId: String, language: String) {
        guard let dir = cacheDirectory() else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let fileURL = cacheFileURL(for: resourceId, language: language) else { return }
        try? content.write(to: fileURL)
    }
    
    func loadContentFromDisk(for resourceId: String, language: String) -> Data? {
        guard let fileURL = cacheFileURL(for: resourceId, language: language) else { return nil }
        return try? Data(contentsOf: fileURL)
    }
    
    func isContentCachedOnDisk(for resourceId: String, language: String) -> Bool {
        guard let fileURL = cacheFileURL(for: resourceId, language: language) else { return false }
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
}
