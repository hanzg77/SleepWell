import Foundation

// 代表一次守护过程
struct SleepEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let startTime: Date
    let duration: TimeInterval
    let mode: GuardianMode
    let resourceID: String?
    let resourceName: String?
    let resourceCoverImageURL: URL?
    
    init(id: UUID = UUID(), startTime: Date, duration: TimeInterval, mode: GuardianMode, resource: Resource?) {
        self.id = id
        self.startTime = startTime
        self.duration = duration
        self.mode = mode
        self.resourceID = resource?.id
        self.resourceName = resource?.name
        self.resourceCoverImageURL = URL(string: resource?.coverImageUrl ?? "")
    }
    
    static func == (lhs: SleepEntry, rhs: SleepEntry) -> Bool {
        lhs.id == rhs.id &&
        lhs.startTime == rhs.startTime &&
        lhs.duration == rhs.duration &&
        lhs.mode == rhs.mode &&
        lhs.resourceID == rhs.resourceID &&
        lhs.resourceName == rhs.resourceName &&
        lhs.resourceCoverImageURL == rhs.resourceCoverImageURL
    }
}

// 代表一天的日志
struct DailySleepLog: Identifiable, Codable, Equatable {
    let date: Date
    var entries: [SleepEntry]
    var mood: Mood?
    var notes: String?
    var id: Date { date }
    
    // 计算总陪伴时长
    var totalDuration: TimeInterval {
        entries.reduce(0) { $0 + $1.duration }
    }
    
    // 实现 Equatable
    static func == (lhs: DailySleepLog, rhs: DailySleepLog) -> Bool {
        lhs.date == rhs.date &&
        lhs.entries == rhs.entries &&
        lhs.mood == rhs.mood &&
        lhs.notes == rhs.notes
    }
}

// 心情模型
enum Mood: String, Codable, CaseIterable, Identifiable {
    case happy
    case calm
    case annoyed
    case racingThoughts
    case down

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .happy: return "开心"
        case .calm: return "平静"
        case .annoyed: return "烦"
        case .racingThoughts: return "想太多"
        case .down: return "丧"
        }
    }

    var iconName: String {
        switch self {
        case .happy: return "star.fill"           // 可替换为自定义图片名
        case .calm: return "drop.fill"
        case .annoyed: return "scribble"
        case .racingThoughts: return "cloud.fill"
        case .down: return "moon.stars.fill"
        }
    }
} 
