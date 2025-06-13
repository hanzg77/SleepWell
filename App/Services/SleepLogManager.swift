import Foundation
import SwiftUI

class SleepLogManager: ObservableObject {
    static let shared = SleepLogManager()
    
    @Published private(set) var dailyLogs: [DailySleepLog] = []
    private let userDefaults = UserDefaults.standard
    private let logsKey = "sleep_logs"
    
    private init() {
        loadLogs()
    }
    
    // MARK: - 数据加载
    func loadLogs() {
        if let data = userDefaults.data(forKey: logsKey),
           let logs = try? JSONDecoder().decode([DailySleepLog].self, from: data) {
            // 过滤每一天的 entries，去除 duration < 5 分钟的记录
            let filteredLogs = logs.map { log in
                var newLog = log
                newLog.entries = log.entries.filter { $0.duration >= 300 }
                return newLog
            }.filter { !$0.entries.isEmpty } // 只保留有有效 entry 的日志
            
            // 按日期倒序排序
            let sortedLogs = filteredLogs.sorted(by: { $0.date > $1.date })
            
            // 检查第一个记录是否是今天的
            let today = Calendar.current.startOfDay(for: Date())
            if let firstLog = sortedLogs.first, Calendar.current.isDate(firstLog.date, inSameDayAs: today) {
                dailyLogs = sortedLogs
            } else {
                // 如果没有今天的记录，添加一个默认的今日记录
                let defaultLog = DailySleepLog(date: today, entries: [], mood: nil, notes: nil)
                dailyLogs = [defaultLog] + sortedLogs
            }
        }
    }
    
    // MARK: - 数据保存
    private func saveLogs() {
        if let data = try? JSONEncoder().encode(dailyLogs) {
            userDefaults.set(data, forKey: logsKey)
        }
    }
    
    // MARK: - 添加条目
    func addEntry(_ entry: SleepEntry) {
        let calendar = Calendar.current
        let entryDate = calendar.startOfDay(for: entry.startTime)
        
        if let index = dailyLogs.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: entryDate) }) {
            dailyLogs[index].entries.append(entry)
        } else {
            let newLog = DailySleepLog(date: entryDate, entries: [entry], mood: nil, notes: nil)
            dailyLogs.append(newLog)
        }
        
        saveLogs()
    }
    
    // MARK: - 更新日志
    func updateDailyLog(for date: Date, mood: Mood?, notes: String?) {
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)
        
        if let index = dailyLogs.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: targetDate) }) {
            dailyLogs[index].mood = mood
            dailyLogs[index].notes = notes
        } else {
            let newLog = DailySleepLog(date: targetDate, entries: [], mood: mood, notes: notes)
            dailyLogs.append(newLog)
        }
        
        saveLogs()
    }
    
    // MARK: - 获取日志
    func getLog(for date: Date) -> DailySleepLog? {
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)
        return dailyLogs.first { calendar.isDate($0.date, inSameDayAs: targetDate) }
    }
    
    // MARK: - 删除日志
    func deleteLog(for date: Date) {
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)
        dailyLogs.removeAll { calendar.isDate($0.date, inSameDayAs: targetDate) }
        saveLogs()
    }
    
    // MARK: - 删除条目
    func deleteEntry(_ entry: SleepEntry, from date: Date) {
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)
        
        if let index = dailyLogs.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: targetDate) }) {
            dailyLogs[index].entries.removeAll { $0.id == entry.id }
            if dailyLogs[index].entries.isEmpty {
                dailyLogs.remove(at: index)
            }
            saveLogs()
        }
    }
    
    var todayLog: DailySleepLog? {
        let today = Calendar.current.startOfDay(for: Date())
        return dailyLogs.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }
    /// 新增或更新指定日期的 DailySleepLog 的 mood 和 notes
    func upsertLog(for date: Date, mood: Mood, notes: String) {
        let day = Calendar.current.startOfDay(for: date)
        if let index = dailyLogs.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: day) }) {
            // 已有，更新
            dailyLogs[index].mood = mood
            dailyLogs[index].notes = notes
        } else {
            // 没有，新增
            let newLog = DailySleepLog(date: day, entries: [], mood: mood, notes: notes)
            dailyLogs.append(newLog)
        }
        saveLogs()
        objectWillChange.send()
    }
    
}
