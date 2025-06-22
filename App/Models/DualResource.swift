import Foundation

struct DualResource: Identifiable, Codable, Equatable {
    let id: String
    let resourceId: String
    let resourceType: ResourceType
    let category: String
    let tags: [String]
    let totalDurationSeconds: Int
    let globalPlaybackCount: Int64
    let localizedContent: LocalizedContent
    let audioUrl: String
    let videoUrl: String?
    let videoClipUrl: String?
    let status: String
    let isPublished: Bool
    let episodeCount: Int
    let favoriteCount: Int
    let shareCount: Int
    let downloadCount: Int
    let commentCount: Int
    let rating: Double
    let ratingCount: Int
    let metadata: ResourceMetadata
    var episodes: [Episode] {
        if let _episodes = _episodes, !_episodes.isEmpty {
            return _episodes
        } else if isSingleEpisode {
            return [createSingleEpisode()]
        } else {
            return []
        }
    }
    private var _episodes: [Episode]?
    
    var name: String {
        localizedContent.name
    }
    
    var description: String {
        localizedContent.description
    }
    
    var coverImageUrl: String {
        localizedContent.coverImageUrl
    }
    
    var isVideo: Bool {
        if let videoUrl = videoUrl {
            return !videoUrl.isEmpty
        }
        return false
    }
    
    var isSingleEpisode: Bool {
        resourceType == .singleTrackAlbum || episodeCount == 1
    }
    
    // 创建单集资源时的辅助方法
    func createSingleEpisode() -> Episode {
        print("🎥 创建单集: id=\(id), resourceId=\(resourceId), videoUrl=\(videoUrl ?? "nil"), videoClipUrl=\(videoClipUrl ?? "nil")")
        return Episode(
            id: id,
            episodeNumber: 1,
            audioUrl: audioUrl,
            videoUrl: videoUrl,
            videoClipUrl: videoClipUrl,
            durationSeconds: totalDurationSeconds,
            localizedContent: EpisodeLocalizedContent(
                name: name,
                description: description
            ),
            playbackCount: globalPlaybackCount,
        )
    }
    
    // 这是一个你需要添加到 DualResource struct 中的初始化器

    init(id: String,
         resourceId: String,
         resourceType: ResourceType,
         category: String,
         tags: [String],
         totalDurationSeconds: Int,
         globalPlaybackCount: Int,
         localizedContent: LocalizedContent,
         audioUrl: String,
         videoUrl: String?,
         videoClipUrl: String?,
         status: String,
         isPublished: Bool,
         episodeCount: Int,
         favoriteCount: Int,
         shareCount: Int,
         downloadCount: Int,
         commentCount: Int,
         rating: Double,
         ratingCount: Int,
         metadata: ResourceMetadata) {
        
        self.id = id
        self.resourceId = resourceId
        self.resourceType = resourceType
        self.category = category
        self.tags = tags
        self.totalDurationSeconds = totalDurationSeconds
        self.globalPlaybackCount = Int64(globalPlaybackCount)
        self.localizedContent = localizedContent
        self.audioUrl = audioUrl
        self.videoUrl = videoUrl
        self.videoClipUrl = videoClipUrl
        self.status = status
        self.isPublished = isPublished
        self.episodeCount = episodeCount
        self.favoriteCount = favoriteCount
        self.shareCount = shareCount
        self.downloadCount = downloadCount
        self.commentCount = commentCount
        self.rating = rating
        self.ratingCount = ratingCount
        self.metadata = metadata
    }

    // 这是一个推荐的、更清晰的实现方式，可以添加到 DualResource 中
    init(from youtubeItem: YouTubeSearchResultItem) {
        let localizedContent = LocalizedContent(
            name: youtubeItem.title,
            description: youtubeItem.description,
            coverImageUrl: youtubeItem.thumbnail.high ?? youtubeItem.thumbnail.medium ?? youtubeItem.thumbnail.default ?? "",
            rank: 0
        )
        
        let metadata = ResourceMetadata(
            source: "youtube",
            videoId: youtubeItem.videoId,
            uploader: youtubeItem.channelTitle,
            uploadDate: youtubeItem.publishedAt
        )
        
        self.init(
            id: youtubeItem.videoId,
            resourceId: youtubeItem.videoId,
            resourceType: .singleTrackAlbum,
            category: "youtube",
            tags: youtubeItem.tags ?? [youtubeItem.channelTitle],
            totalDurationSeconds: 0,
            globalPlaybackCount: 0,
            localizedContent: localizedContent,
            audioUrl: "https://www.youtube.com/watch?v=\(youtubeItem.videoId)",
            videoUrl: "https://www.youtube.com/watch?v=\(youtubeItem.videoId)",
            videoClipUrl: "",
            status: "published",
            isPublished: true,
            episodeCount: 1,
            favoriteCount: 0,
            shareCount: 0,
            downloadCount: 0,
            commentCount: 0,
            rating: 0,
            ratingCount: 0,
            metadata: metadata
        )
    }

    
    // 实现 Equatable
    static func == (lhs: DualResource, rhs: DualResource) -> Bool {
        lhs.resourceId == rhs.resourceId
    }
}

// API 响应模型
struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let message: String
    let data: T
}

enum ResourceType: String, Codable {
    case singleTrackAlbum = "single_track_album"
    case multiEpisodeSeries = "multi_episode_series"
    case tracklistAlbum = "tracklist_album"
    case video = "video"
}

struct LocalizedContent: Codable {
    let name: String
    let description: String
    let coverImageUrl: String
    let rank: Int
}

struct ResourceMetadata: Codable {
    let source: String
    let videoId: String
    let uploader: String
    let uploadDate: String
    
    enum CodingKeys: String, CodingKey {
        case source
        case videoId = "video_id"
        case uploader
        case uploadDate = "upload_date"
    }
} 
