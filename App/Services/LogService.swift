import Foundation
import UIKit // For UIDevice

// MARK: - LogEvent Structure

/// Represents a single log event with common and event-specific data.
struct LogEvent {
    let deviceId: String
    let timestamp: String // ISO 8601 formatted date string
    let eventType: String
    let systemLanguage: String
    let appLanguage: String // Assuming this is retrieved from app settings
    let data: [String: Any] // Event-specific key-value pairs

    /// Initializes a new LogEvent.
    /// - Parameters:
    ///   - eventType: The type of event (e.g., "GuardianStart", "MoodRecord").
    ///   - appLanguage: The language currently used by the app.
    ///   - data: A dictionary of event-specific data.
    init(eventType: String, appLanguage: String, data: [String: Any]) {
        self.deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown_device"
        self.timestamp = ISO8601DateFormatter().string(from: Date())
        self.eventType = eventType
        self.systemLanguage = Locale.current.language.languageCode?.identifier ?? "unknown"
        self.appLanguage = appLanguage
        self.data = data
    }

    /// Converts the log event into a dictionary suitable for URL parameters.
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "deviceId": deviceId,
            "timestamp": timestamp,
            "eventType": eventType,
            "systemLanguage": systemLanguage,
            "appLanguage": appLanguage
        ]
        // Merge event-specific data
        data.forEach { (key, value) in
            dict[key] = value
        }
        return dict
    }
}

// MARK: - LogService Class

/// A service for sending log events to a remote server.
class LogService {
    static let shared = LogService()
    
    // TODO: Replace with your actual server endpoint
    private let baseURL = "https://sleepwell.ciyuans.com/api/log" // Replace with your actual server endpoint

    private init() {}
    
    /// 获取当前应用语言
    private func getCurrentAppLanguage() -> String {
        return LocalizationManager.shared.currentLanguage
    }

    /// Sends a log event to the configured server.
    /// - Parameters:
    ///   - eventType: The type of event (e.g., "GuardianStart", "MoodRecord").
    ///   - appLanguage: The language currently used by the app.
    ///   - data: A dictionary of event-specific key-value pairs.
    func sendLogEvent(eventType: String, appLanguage: String, data: [String: Any]) {
        let event = LogEvent(eventType: eventType, appLanguage: appLanguage, data: data)

        guard var components = URLComponents(string: baseURL) else {
            print("Error: Invalid base URL for logging.")
            return
        }

        // Convert event data to URLQueryItem array
        var queryItems: [URLQueryItem] = []
        for (key, value) in event.toDictionary() {
            // Convert all values to String for URL encoding
            queryItems.append(URLQueryItem(name: key, value: "\(value)"))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            print("Error: Could not construct URL for log event.")
            return
        }

        // Perform the GET request
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Log sending failed: \(error.localizedDescription)")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("Log sending failed with unexpected status code: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return
            }

            print("Log event sent successfully: \(event.eventType)")
        }
        task.resume()
    }
    
    /// 便捷方法：使用当前应用语言发送日志事件
    func sendLogEvent(eventType: String, data: [String: Any]) {
        sendLogEvent(eventType: eventType, appLanguage: getCurrentAppLanguage(), data: data)
    }
    
    // MARK: - 测试方法
    
    /// 演示三条日志的使用
    func demonstrateLogging() {
        // 事件1: 守护开始
        sendLogEvent(
            eventType: "GuardianStart",
            data: [
                "guardianMode": "Sleep",
                "resourceId": "ocean_waves_001"
            ]
        )
        
        // 事件2: 守护结束
        sendLogEvent(
            eventType: "GuardianEnd",
            data: [
                "guardianDuration": 3600, // duration in seconds
                "resourceId": "ocean_waves_001"
            ]
        )
        
        // 事件3: 记录心情 (有播放资源)
        sendLogEvent(
            eventType: "MoodRecord",
            data: [
                "mood": "Calm",
                "recordContent": "Feeling relaxed after listening to the rain.",
                "playedResource": "rain_sound_002"
            ]
        )
        
        // 事件3: 记录心情 (没有播放资源)
        sendLogEvent(
            eventType: "MoodRecord",
            data: [
                "mood": "Happy",
                "recordContent": "Just a good day."
            ]
        )
    }
}
