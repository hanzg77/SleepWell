import Foundation
import ActivityKit

// MARK: - 灵动岛活动属性
struct GuardianActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var endTime: Date
        var remainingTime: TimeInterval
        var guardianMode: String
    }
    
    var resourceName: String
    var guardianMode: String
} 