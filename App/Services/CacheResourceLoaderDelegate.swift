import Foundation
import AVFoundation
import MobileCoreServices

// MARK: - CacheBlock & CacheInfo Structures

/// Represents a single contiguous block of cached data.
struct CacheBlock: Codable, Equatable {
    let start: Int64
    let end: Int64 // Inclusive end
}

/// A container for all persistent caching information.
/// This includes media metadata and the index of cached blocks.
struct CacheInfo: Codable {
    var blocks: [CacheBlock]
    var contentLength: Int64
    var contentType: String
    
    init() {
        self.blocks = []
        self.contentLength = 0
        self.contentType = ""
    }
}

// MARK: - CacheResourceLoaderDelegate

///
/// A resource loading delegate that provides play-while-downloading and persistent caching capabilities.
///
/// This class intercepts AVPlayer's requests and serves data from a local cache if available.
/// If data is not cached, it downloads it from the original URL, saves it to the cache,
/// and then provides it to the player. All operations are thread-safe.
///
class CacheResourceLoaderDelegate: NSObject, AVAssetResourceLoaderDelegate, URLSessionDataDelegate {

    // MARK: - Properties

    private let originalURL: URL
    private let cacheFileURL: URL
    private let indexFileURL: URL

    private var session: URLSession?
    private var tasks: [AVAssetResourceLoadingRequest: URLSessionDataTask] = [:]
    private var cacheInfo: CacheInfo = CacheInfo()
    private var lastLoggedPercentage: Int = -1
    private var isSessionInvalidated = false

    /// A dedicated serial queue to ensure thread-safe access to properties and file I/O.
    private let workQueue = DispatchQueue(label: "com.example.cacheResourceLoader.workQueue")
    /// A specific key to identify our work queue and prevent deadlocks.
    private let workQueueKey = DispatchSpecificKey<Void>()

    // MARK: - Initialization

    init(originalURL: URL) {
        self.originalURL = originalURL

        // Create cache directory if it doesn't exist
        let fileManager = FileManager.default
        let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let loaderCacheDirectory = cacheDirectory.appendingPathComponent("MediaLoaderCache")
        
        do {
            if !fileManager.fileExists(atPath: loaderCacheDirectory.path) {
                try fileManager.createDirectory(at: loaderCacheDirectory, withIntermediateDirectories: true, attributes: nil)
            }
        } catch {
            // Using fatalError here because if the cache directory cannot be created,
            // the entire caching mechanism is non-functional.
            fatalError("[CacheLoader] Failed to create cache directory: \(error)")
        }
        
        // Generate unique file names based on the original URL
        let fileName = originalURL.absoluteString.data(using: .utf8)!.base64EncodedString().replacingOccurrences(of: "/", with: "_")
        self.cacheFileURL = loaderCacheDirectory.appendingPathComponent(fileName)
        self.indexFileURL = loaderCacheDirectory.appendingPathComponent(fileName + ".index")

        super.init()
        
        // Set the specific key for the queue, allowing us to identify it later.
        workQueue.setSpecific(key: workQueueKey, value: ())
        self.session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)

        workQueue.async { [weak self] in
            self?.loadCacheInfo()
        }
    }

    deinit {
        // Fallback cleanup, now safe from deadlocks.
        cancelAllRequests()
    }
    
    // MARK: - Public API
    
    /// Call this method to stop all network activities and cleanup resources.
    /// This is crucial when switching to a new media item.
    public func cancelAllRequests() {
        // A unified cleanup closure.
        let performCleanup = { [weak self] in
            guard let self = self else { return }
            guard !self.isSessionInvalidated else { return }
            
            self.isSessionInvalidated = true
            self.session?.invalidateAndCancel()
            self.tasks.removeAll()
            print("[CacheLoader] 所有请求已取消，会话已失效: \(self.originalURL.lastPathComponent)")
        }

        // Check if the current thread is already our work queue.
        if DispatchQueue.getSpecific(key: workQueueKey) != nil {
            // If so, execute directly to avoid a deadlock.
            performCleanup()
        } else {
            // Otherwise, dispatch synchronously to the work queue to ensure
            // cleanup is complete before this method returns.
            workQueue.sync(execute: performCleanup)
        }
    }

    // MARK: - AVAssetResourceLoaderDelegate

    /// This is the main entry point for handling AVPlayer's requests.
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        // Dispatch to the work queue to ensure serial processing of requests
        workQueue.async { [weak self] in
            self?.process(loadingRequest: loadingRequest)
        }
        return true
    }

    /// Handles cancellation of a loading request.
    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        workQueue.async { [weak self] in
            if let task = self?.tasks[loadingRequest] {
                task.cancel()
            }
        }
    }

    // MARK: - URLSessionDataDelegate
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        workQueue.async { [weak self] in
            guard let self = self, let loadingRequest = self.findLoadingRequest(for: dataTask) else {
                completionHandler(.cancel)
                return
            }

            // Handle Content Information from the network response
            if let infoRequest = loadingRequest.contentInformationRequest,
               let httpResponse = response as? HTTPURLResponse {
                self.fillContentInformation(from: httpResponse, for: infoRequest)
            }
            completionHandler(.allow)
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        workQueue.async { [weak self] in
            guard let self = self,
                  let loadingRequest = self.findLoadingRequest(for: dataTask),
                  let dataRequest = loadingRequest.dataRequest else {
                return
            }
            
            // Write data to cache file and respond to player
            let offset = dataRequest.currentOffset
            self.writeDataToCache(data, at: offset)
            dataRequest.respond(with: data)

            // Update cache index
            self.addCachedBlock(start: offset, length: Int64(data.count))
            
            // Merge blocks, save the index, and log progress for this chunk
            self.mergeBlocks()
            self.saveCacheInfo() // Save index immediately after receiving data
            self.logCacheProgress()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        workQueue.async { [weak self] in
            guard let self = self, let loadingRequest = self.findLoadingRequest(for: task) else {
                return
            }
            
            // This is the single point of cleanup for a task.
            self.tasks.removeValue(forKey: loadingRequest)
            
            if let error = error {
                if let nsError = error as? NSError, nsError.code == NSURLErrorCancelled {
                    print("[CacheLoader] 请求已正常取消: \(task.originalRequest?.value(forHTTPHeaderField: "Range") ?? "N/A")")
                    loadingRequest.finishLoading()
                } else {
                    print("[CacheLoader] 请求失败: \(error.localizedDescription)")
                    loadingRequest.finishLoading(with: error)
                }
            } else {
                loadingRequest.finishLoading()
                self.logCacheProgress()
            }
        }
    }

    // MARK: - Private: Request Handling Logic (on workQueue)

    /// Central handler for all incoming loading requests.
    private func process(loadingRequest: AVAssetResourceLoadingRequest) {
        if loadingRequest.isCancelled || isSessionInvalidated {
            if !loadingRequest.isFinished {
                loadingRequest.finishLoading()
            }
            return
        }

        // Case 1: Content Information Request (for metadata)
        if let infoRequest = loadingRequest.contentInformationRequest {
            handleContentInformationRequest(infoRequest, for: loadingRequest)
            return
        }
        
        // Case 2: Data Request (for media data)
        if let dataRequest = loadingRequest.dataRequest {
            handleDataRequest(dataRequest, for: loadingRequest)
            return
        }
    }
    
    /// Handles requests for media metadata.
    private func handleContentInformationRequest(_ infoRequest: AVAssetResourceLoadingContentInformationRequest, for loadingRequest: AVAssetResourceLoadingRequest) {
        if cacheInfo.contentLength > 0 && !cacheInfo.contentType.isEmpty {
            print("[CacheLoader] 媒体信息命中缓存。")
            infoRequest.contentLength = cacheInfo.contentLength
            infoRequest.contentType = cacheInfo.contentType
            infoRequest.isByteRangeAccessSupported = true
            loadingRequest.finishLoading()
            return
        }

        print("[CacheLoader] 媒体信息未命中，正在从网络获取...")
        var request = URLRequest(url: originalURL)
        request.httpMethod = "HEAD"
        
        guard let task = session?.dataTask(with: request) else {
            let error = NSError(domain: "CacheLoaderError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Session is unavailable."])
            loadingRequest.finishLoading(with: error)
            return
        }
        
        tasks[loadingRequest] = task
        task.resume()
    }

    /// Handles requests for actual media data.
    private func handleDataRequest(_ dataRequest: AVAssetResourceLoadingDataRequest, for loadingRequest: AVAssetResourceLoadingRequest) {
        let requestedOffset = dataRequest.requestedOffset
        let requestedLength = Int64(dataRequest.requestedLength)
        
        if isRangeFullyCached(start: requestedOffset, length: requestedLength) {
            print("[CacheLoader] 数据请求命中缓存，范围: [\(requestedOffset)-\(requestedOffset + requestedLength - 1)]")
            serveDataFromCache(for: dataRequest, loadingRequest: loadingRequest)
        } else {
            print("[CacheLoader] 数据请求未命中，正在从网络获取范围: [\(requestedOffset)-\(requestedOffset + requestedLength - 1)]")
            fetchDataFromNetwork(for: dataRequest, loadingRequest: loadingRequest)
        }
    }

    // MARK: - Private: Caching & Data Serving (on workQueue)
    
    /// Checks if a given data range is completely available in the cache.
    private func isRangeFullyCached(start: Int64, length: Int64) -> Bool {
        guard length > 0 else { return true }
        let requiredEnd = start + length - 1
        
        for block in cacheInfo.blocks {
            if start >= block.start && requiredEnd <= block.end {
                return true
            }
        }
        return false
    }

    /// Reads data from the local cache file and provides it to the player.
    private func serveDataFromCache(for dataRequest: AVAssetResourceLoadingDataRequest, loadingRequest: AVAssetResourceLoadingRequest) {
        do {
            let fileHandle = try FileHandle(forReadingFrom: cacheFileURL)
            defer { fileHandle.closeFile() }
            
            let requestedOffset = dataRequest.requestedOffset
            let requestedLength = Int64(dataRequest.requestedLength)

            try fileHandle.seek(toOffset: UInt64(requestedOffset))
            let data = try fileHandle.read(upToCount: Int(requestedLength)) ?? Data()
            
            dataRequest.respond(with: data)
            loadingRequest.finishLoading()
            
        } catch {
            print("[CacheLoader] 从缓存提供数据时出错: \(error)")
            loadingRequest.finishLoading(with: error)
        }
    }

    /// Fetches data from the network when it's not available in the cache.
    private func fetchDataFromNetwork(for dataRequest: AVAssetResourceLoadingDataRequest, loadingRequest: AVAssetResourceLoadingRequest) {
        var request = URLRequest(url: originalURL)
        
        let requestedOffset = dataRequest.requestedOffset
        let requestedToEnd = dataRequest.requestsAllDataToEndOfResource
        
        let rangeEnd: String
        if requestedToEnd {
            rangeEnd = ""
        } else {
            rangeEnd = "\(requestedOffset + Int64(dataRequest.requestedLength) - 1)"
        }
        
        let rangeHeader = "bytes=\(requestedOffset)-\(rangeEnd)"
        request.setValue(rangeHeader, forHTTPHeaderField: "Range")
        
        guard let task = session?.dataTask(with: request) else {
            let error = NSError(domain: "CacheLoaderError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Session is unavailable."])
            loadingRequest.finishLoading(with: error)
            return
        }

        tasks[loadingRequest] = task
        task.resume()
    }
    
    // MARK: - Private: File I/O & Index Management (on workQueue)

    private func loadCacheInfo() {
        guard FileManager.default.fileExists(atPath: indexFileURL.path) else {
            print("[CacheLoader] 索引文件不存在，开始全新缓存: \(originalURL.lastPathComponent)")
            return
        }
        do {
            let data = try Data(contentsOf: indexFileURL)
            self.cacheInfo = try JSONDecoder().decode(CacheInfo.self, from: data)
            print("[CacheLoader] 成功加载缓存索引: \(originalURL.lastPathComponent)")
            logCacheProgress()
        } catch {
            print("[CacheLoader] 加载索引文件失败: \(error)。重置缓存。")
            try? FileManager.default.removeItem(at: indexFileURL)
            try? FileManager.default.removeItem(at: cacheFileURL)
            self.cacheInfo = CacheInfo()
        }
    }
    
    private func saveCacheInfo() {
        do {
            let data = try JSONEncoder().encode(cacheInfo)
            try data.write(to: indexFileURL)
        } catch {
            print("[CacheLoader] 保存索引文件失败: \(error)")
        }
    }
    
    private func addCachedBlock(start: Int64, length: Int64) {
        guard length > 0 else { return }
        let newBlock = CacheBlock(start: start, end: start + length - 1)
        cacheInfo.blocks.append(newBlock)
    }
    
    private func mergeBlocks() {
        guard !cacheInfo.blocks.isEmpty else { return }
        
        var sortedBlocks = cacheInfo.blocks.sorted { $0.start < $1.start }
        
        var merged: [CacheBlock] = []
        var currentMerge = sortedBlocks.removeFirst()
        
        for block in sortedBlocks {
            if block.start <= currentMerge.end + 1 {
                currentMerge = CacheBlock(start: currentMerge.start, end: max(currentMerge.end, block.end))
            } else {
                merged.append(currentMerge)
                currentMerge = block
            }
        }
        merged.append(currentMerge)
        
        cacheInfo.blocks = merged
    }
    
    private func writeDataToCache(_ data: Data, at offset: Int64) {
        do {
            // First, ensure the file exists. If not, create it.
            if !FileManager.default.fileExists(atPath: cacheFileURL.path) {
                // Using an empty Data instance to create the file.
                try Data().write(to: cacheFileURL)
            }
            
            // Now that we're sure the file exists, open it for updating.
            let fileHandle = try FileHandle(forUpdating: cacheFileURL)
            
            // Use defer to ensure the file handle is closed, even if errors occur.
            defer { fileHandle.closeFile() }
            
            // Seek to the correct offset and write the data.
            try fileHandle.seek(toOffset: UInt64(offset))
            try fileHandle.write(contentsOf: data)
            
        } catch {
            print("[CacheLoader] 写入数据到缓存文件时出错: \(error)")
        }
    }
    
    // MARK: - Private: Helpers
    
    /// Finds the corresponding loading request for a given session task.
    private func findLoadingRequest(for task: URLSessionTask) -> AVAssetResourceLoadingRequest? {
        return tasks.first { $0.value == task }?.key
    }
    
    /// Fills content information from an HTTP response.
    private func fillContentInformation(from response: HTTPURLResponse, for infoRequest: AVAssetResourceLoadingContentInformationRequest) {
        if let contentLengthString = response.allHeaderFields["Content-Length"] as? String,
           let contentLength = Int64(contentLengthString) {
            self.cacheInfo.contentLength = contentLength
            infoRequest.contentLength = contentLength
        } else if let range = response.allHeaderFields["Content-Range"] as? String {
            if let totalSizeString = range.split(separator: "/").last, let totalSize = Int64(totalSizeString) {
                self.cacheInfo.contentLength = totalSize
                infoRequest.contentLength = totalSize
            }
        }

        if let contentType = response.mimeType {
            self.cacheInfo.contentType = contentType
            if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, contentType as CFString, nil)?.takeRetainedValue() {
                infoRequest.contentType = uti as String
            }
        }

        infoRequest.isByteRangeAccessSupported = true
    }

    /// Calculates total cached bytes.
    private func totalCachedBytes() -> Int64 {
        return cacheInfo.blocks.reduce(0) { $0 + ($1.end - $1.start + 1) }
    }
    
    /// Logs the current caching progress, but only when the percentage integer value changes.
    private func logCacheProgress() {
        guard cacheInfo.contentLength > 0 else { return }
        
        let cachedBytes = totalCachedBytes()
        let totalBytes = cacheInfo.contentLength
        let percentage = Double(cachedBytes) / Double(totalBytes) * 100.0
        let currentPercentageInt = Int(percentage)
        
        let isCompleted = percentage >= 100.0
        if currentPercentageInt > lastLoggedPercentage || (isCompleted && lastLoggedPercentage < 100) {
            let cachedMB = Double(cachedBytes) / (1024 * 1024)
            let totalMB = Double(totalBytes) / (1024 * 1024)
            
            let percentageString = String(format: "%.2f%%", percentage)
            let cachedMBString = String(format: "%.2fMB", cachedMB)
            let totalMBString = String(format: "%.2fMB", totalMB)
            
            let emoji = isCompleted ? "✅" : "🔄"
            
            print("\(emoji) [CacheLoader] 缓存进度 [\(originalURL.lastPathComponent)]: \(cachedMBString) / \(totalMBString) (\(percentageString))")
            
            lastLoggedPercentage = currentPercentageInt
        }
    }
}
