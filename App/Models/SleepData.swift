import Foundation
import SwiftUICore

enum SleepState: String, CaseIterable {
    case preparing = "准备入睡"
    case lightSleep = "浅睡"
    case deepSleep = "深睡"
    case remSleep = "快速眼动"
    case awake = "清醒"
    
    var description: String {
        switch self {
        case .preparing: return "准备入睡"
        case .lightSleep: return "浅睡"
        case .deepSleep: return "深睡"
        case .remSleep: return "快速眼动"
        case .awake: return "清醒"
        }
    }
    
    var color: Color {
        switch self {
        case .preparing: return .preparingColor
        case .lightSleep: return .lightSleepColor
        case .deepSleep: return .deepSleepColor
        case .remSleep: return .remSleepColor
        case .awake: return .awakeColor
        }
    }
}

struct TimeBlock: Identifiable {
    let id = UUID()
    let state: SleepState
    let startTime: Date
    let endTime: Date
    
    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }
}

struct SleepSession {
    var timeBlocks: [TimeBlock] = []
    var startTime: Date?
    var endTime: Date?
    var isActive: Bool = false
    
    var totalDuration: TimeInterval {
        guard let start = startTime, let end = endTime else { return 0 }
        return end.timeIntervalSince(start)
    }
    
    var currentState: SleepState {
        timeBlocks.last?.state ?? .awake
    }
} 
