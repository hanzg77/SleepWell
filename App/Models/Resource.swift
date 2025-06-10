import Foundation

struct Resource: Identifiable, Codable, Equatable {
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
    
    // 实现 Equatable
    static func == (lhs: Resource, rhs: Resource) -> Bool {
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
