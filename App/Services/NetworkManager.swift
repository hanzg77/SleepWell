import Foundation
import Combine
import Security

enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case decodingError
    case serverError(String)
}

class NetworkManager: NSObject, URLSessionDelegate {
    static let shared = NetworkManager()
    private let baseURL = "https://tripbwh.duoduoipo.com/api"
    //private let baseURL = "http://192.168.31.79:8000/api"
    private let language = "zh" // 固定使用中文
    
    private override init() {
        super.init()
        setupCertificateTrust()
    }
    
    private func setupCertificateTrust() {
        // 创建自定义的 URLSession 配置
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30
        sessionConfig.timeoutIntervalForResource = 300
        
        // 创建自定义的 URLSession
        let session = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: nil)
        self.session = session
    }
    
    private var session: URLSession!
    
    // MARK: - URLSessionDelegate
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
                return
            }
        }
        completionHandler(.performDefaultHandling, nil)
    }
    
    // 获取资源列表
    func fetchResources(
        page: Int = 1,
        pageSize: Int = 20,
        category: String? = nil,
        searchQuery: String? = nil,
        forceRefresh: Bool = false  // 添加强制刷新参数
    ) -> AnyPublisher<[Resource], Error> {
        let cacheKey = "resources_\(page)_\(pageSize)_\(category ?? "all")_\(searchQuery ?? "")"
        
        // 如果不是强制刷新，先检查缓存
        if !forceRefresh {
            if let cachedData = UserDefaults.standard.data(forKey: cacheKey),
               let cachedResources = try? JSONDecoder().decode([Resource].self, from: cachedData),
               let timestamp = UserDefaults.standard.object(forKey: "\(cacheKey)_timestamp") as? Date,
               Date().timeIntervalSince(timestamp) < 30 * 24 * 60 * 60 {  // 30天有效期
                print("📦 使用缓存的资源列表")
                return Just(cachedResources)
                    .setFailureType(to: Error.self)
                    .eraseToAnyPublisher()
            }
        }
        
        var components = URLComponents(string: "\(baseURL)/resources")!
        var queryItems = [
            URLQueryItem(name: "language", value: self.language),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "pageSize", value: String(pageSize))
        ]
        if let category = category, category != "全部" {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }
        if let searchQuery = searchQuery, !searchQuery.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: searchQuery))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }

        return session.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: APIResponse<[Resource]>.self, decoder: JSONDecoder())
            .map { response in
                // 缓存资源内容
                for resource in response.data {
                    ResourceCache.shared.cacheContent(
                        resource.localizedContent,
                        for: resource.resourceId,
                        language: self.language
                    )
                }
                
                // 缓存资源列表
                if let encodedData = try? JSONEncoder().encode(response.data) {
                    UserDefaults.standard.set(encodedData, forKey: cacheKey)
                    UserDefaults.standard.set(Date(), forKey: "\(cacheKey)_timestamp")
                    print("💾 缓存资源列表")
                }
                
                return response.data
            }
            .catch { error in
                // 如果网络请求失败，且不是强制刷新，尝试使用缓存
                if !forceRefresh {
                    if let cachedData = UserDefaults.standard.data(forKey: cacheKey),
                       let cachedResources = try? JSONDecoder().decode([Resource].self, from: cachedData) {
                        print("⚠️ 网络请求失败，使用过期的缓存数据")
                        return Just(cachedResources)
                            .setFailureType(to: Error.self)
                            .eraseToAnyPublisher()
                    }
                }
                return Fail(error: error).eraseToAnyPublisher()
            }
            .mapError { error in
                if error is DecodingError {
                    print("解码错误: \(error)")
                    return NetworkError.decodingError
                } else {
                    print("网络错误: \(error)")
                    return NetworkError.serverError(error.localizedDescription)
                }
            }
            .eraseToAnyPublisher()
    }
    
    // 获取单个资源
    func fetchResource(resourceId: String) -> AnyPublisher<Resource, Error> {
        var components = URLComponents(string: "\(baseURL)/resources/\(resourceId)")!
        components.queryItems = [
            URLQueryItem(name: "language", value: self.language)
        ]
        
        guard let url = components.url else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: APIResponse<Resource>.self, decoder: JSONDecoder())
            .map { response in
                // 缓存资源内容
                ResourceCache.shared.cacheContent(
                    response.data.localizedContent,
                    for: response.data.resourceId,
                    language: self.language
                )
                return response.data
            }
            .mapError { error in
                if error is DecodingError {
                    print("解码错误: \(error)")
                    return NetworkError.decodingError
                } else {
                    print("网络错误: \(error)")
                    return NetworkError.serverError(error.localizedDescription)
                }
            }
            .eraseToAnyPublisher()
    }
    
    // 删除资源
    func deleteResource(resourceId: String) -> AnyPublisher<Void, Error> {
        guard let url = URL(string: "\(baseURL)/resources/\(resourceId)") else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        return session.dataTaskPublisher(for: request)
            .map { _ in () }
            .mapError { error in
                print("删除资源失败: \(error)")
                return NetworkError.serverError(error.localizedDescription)
            }
            .eraseToAnyPublisher()
    }
    
    // 获取剧集列表
    func fetchEpisodes(resourceId: String, page: Int = 1, pageSize: Int = 20) -> AnyPublisher<[Episode], Error> {
        print("🌐 请求剧集列表: resourceId=\(resourceId), page=\(page)")
        
        var components = URLComponents(string: "\(baseURL)/resources/\(resourceId)")!
        components.queryItems = [
            URLQueryItem(name: "language", value: self.language)
        ]
        
        guard let url = components.url else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: APIResponse<Resource>.self, decoder: JSONDecoder())
            .map { response in
                let resource = response.data
                print("📦 收到资源数据: id=\(resource.id), resourceId=\(resource.resourceId)")
                
                // 如果是单集资源，创建一个单集
                if resource.isSingleEpisode {
                    let singleEpisode = resource.createSingleEpisode()
                    print("✅ 返回单集数据: id=\(singleEpisode.id), videoUrl=\(singleEpisode.videoUrl ?? "nil")")
                    return [singleEpisode]
                }
                
                // 如果是多集资源，生成模拟的剧集列表
                let episodes = (1...resource.episodeCount).map { number in
                    Episode(
                        id: "\(resource.resourceId)_\(number)",  // 使用 resourceId 而不是 id
                        episodeNumber: number,
                        audioUrl: resource.audioUrl,
                        videoUrl: resource.videoUrl,
                        durationSeconds: resource.totalDurationSeconds / resource.episodeCount,
                        localizedContent: EpisodeLocalizedContent(
                            name: "第\(number)集",
                            description: "这是第\(number)集的描述"
                        ),
                        playbackCount: resource.globalPlaybackCount / Int64(resource.episodeCount)
                    )
                }
                
                // 模拟分页
                let startIndex = (page - 1) * pageSize
                let endIndex = min(startIndex + pageSize, episodes.count)
                
                // 如果起始索引超出范围，返回空数组
                guard startIndex < episodes.count else {
                    print("✅ 已到达最后一页")
                    return []
                }
                
                let pageEpisodes = Array(episodes[startIndex..<endIndex])
                print("✅ 返回第\(page)页数据，共\(pageEpisodes.count)个剧集")
                return pageEpisodes
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    // 更新播放统计
    func trackPlayback(
        resourceId: String,
        id: String
    ) -> AnyPublisher<Void, Error> {
        // TODO: 实现播放统计更新
        return Future<Void, Error> { promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                promise(.success(()))
            }
        }
        .eraseToAnyPublisher()
    }
    
    // 获取睡眠数据
    func getSleepData(for date: Date) -> AnyPublisher<SleepData, Error> {
        let urlString = "\(baseURL)/sleep-data"
        var components = URLComponents(string: urlString)!
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        components.queryItems = [
            URLQueryItem(name: "date", value: dateString)
        ]
        
        guard let url = components.url else {
            return Fail(error: NetworkError.invalidURL).eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: APIResponse<SleepData>.self, decoder: JSONDecoder())
            .map { response in
                return response.data
            }
            .mapError { error in
                if error is DecodingError {
                    print("解码错误: \(error)")
                    return NetworkError.decodingError
                } else {
                    print("网络错误: \(error)")
                    return NetworkError.serverError(error.localizedDescription)
                }
            }
            .eraseToAnyPublisher()
    }
}

// 删除不再需要的响应模型
// struct ResourceResponse: Codable {
//     let resources: [Resource]
// } 
