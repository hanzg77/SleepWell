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
    
    init(id: UUID = UUID(), startTime: Date, duration: TimeInterval, mode: GuardianMode, resource: DualResource?) {
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
    case lonely // 孤独
    case annoyed // 烦
    case racingThoughts // 想太多
    case calm // 平静
    case happy // 快乐
    case unhappy // 不开心

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lonely: return "mood.lonely".localized
        case .annoyed: return "mood.annoyed".localized
        case .racingThoughts: return "mood.racingThoughts".localized
        case .calm: return "mood.calm".localized
        case .happy: return "mood.happy".localized
        case .unhappy: return "mood.unhappy".localized
        }
    }

    var iconName: String {
        switch self {
        case .lonely: return "🥺"
        case .annoyed: return "😾"
        case .racingThoughts: return "🤔"
        case .calm: return "😌"
        case .happy: return "🥹"
        case .unhappy: return "😮‍💨"
        }
    }
} 
