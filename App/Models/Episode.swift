import Foundation

struct Episode: Identifiable, Codable {
    let id: String
    let episodeNumber: Int
    let audioUrl: String
    let videoUrl: String?
    let videoClipUrl: String?
    let durationSeconds: Int
    let localizedContent: EpisodeLocalizedContent
    let playbackCount: Int64
    let startTime: Int?
    let endTime: Int?
    
    var localizedName: String {
        localizedContent.name
    }
    
    var localizedDescription: String? {
        localizedContent.description
    }

    enum CodingKeys: String, CodingKey {
        case id
        case episodeNumber
        case audioUrl
        case videoUrl
        case videoClipUrl
        case durationSeconds
        case localizedContent
        case playbackCount
        case startTime
        case endTime
    }

    init(id: String, episodeNumber: Int, audioUrl: String, videoUrl: String?, videoClipUrl: String? = nil, durationSeconds: Int, localizedContent: EpisodeLocalizedContent, playbackCount: Int64, startTime: Int? = nil, endTime: Int? = nil) {
        self.id = id
        self.episodeNumber = episodeNumber
        self.audioUrl = audioUrl
        self.videoUrl = videoUrl
        self.videoClipUrl = videoClipUrl
        self.durationSeconds = durationSeconds
        self.localizedContent = localizedContent
        self.playbackCount = playbackCount
        self.startTime = startTime
        self.endTime = endTime
    }
}

struct EpisodeLocalizedContent: Codable {
    let name: String
    let description: String?
} 
