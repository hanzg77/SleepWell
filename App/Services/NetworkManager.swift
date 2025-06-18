import Foundation
import Combine
import Security

enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case decodingError
    case serverError(String)
}



class NetworkManager: NSObject, URLSessionDelegate, ObservableObject {
    static let shared = NetworkManager()
    private let baseURL = "https://tripbwh.duoduoipo.com/api"
    //private let baseURL = "http://192.168.31.79:8000/api"
    private let language = "zh" // 固定使用中文
    
    private override init() {
        super.init()
        setupCertificateTrust()
     //   loadCache()
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
    @Published private(set) var resources: [Resource] = []
    private var currentPage = 1
    private var isLoading = false
    private var hasMore = true
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - URLSessionDelegate
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // 接受所有证书
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
                return
            }
        }
        completionHandler(.performDefaultHandling, nil)
    }
    
    // MARK: - 健全数据流管理
    func refreshResources(pageSize: Int = 20, category: String? = nil, searchQuery: String? = nil) {
        currentPage = 1
        hasMore = true
        fetchResources(page: 1, pageSize: pageSize, category: category, searchQuery: searchQuery, isRefresh: true)
        print("NetworkManager 当前资源数量：", self.resources.count)
    }
    
    func loadMoreResources(pageSize: Int = 20, category: String? = nil, searchQuery: String? = nil) {
        guard !isLoading, hasMore else { return }
        fetchResources(page: currentPage + 1, pageSize: pageSize, category: category, searchQuery: searchQuery, isRefresh: false)
    }
    
    private func fetchResources(page: Int, pageSize: Int, category: String?, searchQuery: String?, isRefresh: Bool) {
        isLoading = true
        let cacheKey = "resources_\(page)_\(pageSize)_\(category ?? "all")_\(searchQuery ?? "")"
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
        
        guard let url = components.url else { isLoading = false; return }
        print("🌐 NetworkManager: Requesting URL: \(url.absoluteString)")
        session.dataTaskPublisher(for: url)
            .map(\ .data)
            .decode(type: APIResponse<[Resource]>.self, decoder: JSONDecoder())
            .map { $0.data }
            .replaceError(with: [])
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newResources in
                guard let self = self else { return }
                if isRefresh {
                    self.resources = newResources
                } else {
                    self.resources += newResources
                }
                self.currentPage = page
                self.hasMore = !newResources.isEmpty
                self.saveCache()
                self.isLoading = false
            }
            .store(in: &cancellables)
    }
    
    // 本地缓存
    private func saveCache() {
        if let data = try? JSONEncoder().encode(resources) {
            UserDefaults.standard.set(data, forKey: "resource_cache")
        }
    }
    private func loadCache() {
        if let data = UserDefaults.standard.data(forKey: "resource_cache"),
           let cached = try? JSONDecoder().decode([Resource].self, from: data) {
            self.resources = cached
        }
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
                ResourceCacheManager.shared.cacheContent(
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
    func deleteResource(resourceId: String) async throws -> APIResponse<[String: String]> {
        guard let url = URL(string: "\(baseURL)/resources/\(resourceId)") else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (data, _) = try await session.data(for: request)
        
        // 打印原始响应数据
        if let jsonString = String(data: data, encoding: .utf8) {
            print("📦 服务端原始响应: \(jsonString)")
        }
        
        return try JSONDecoder().decode(APIResponse<[String: String]>.self, from: data)
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
    
    // MARK: - 标签管理
    
    /// 为资源添加标签
    /// - Parameters:
    ///   - resourceId: 资源ID
    ///   - tags: 要添加的标签数组
    ///   - completion: 完成回调
    func addTags(to resourceId: String, tags: [String], completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/resources/\(resourceId)/tags") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: tags)
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NetworkError.invalidResponse))
                return
            }
            
            if (200...299).contains(httpResponse.statusCode) {
                completion(.success(()))
            } else {
                completion(.failure(NetworkError.serverError("\(httpResponse.statusCode)")))
            }
        }.resume()
    }
    
    /// 从资源中移除标签
    /// - Parameters:
    ///   - resourceId: 资源ID
    ///   - tags: 要移除的标签数组
    ///   - completion: 完成回调
    func removeTags(from resourceId: String, tags: [String], completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/resources/\(resourceId)/tags") else {
            completion(.failure(NetworkError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: tags)
        
        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NetworkError.invalidResponse))
                return
            }
            
            if (200...299).contains(httpResponse.statusCode) {
                completion(.success(()))
            } else {
                completion(.failure(NetworkError.serverError("\(httpResponse.statusCode)")))
            }
        }.resume()
    }
}

// 删除不再需要的响应模型
// struct ResourceResponse: Codable {
//     let resources: [Resource]
// } 
