import Foundation
import Combine

class SleepDataModel: ObservableObject {
    @Published var currentSleepData: SleepData?
    @Published var isLoading = false
    @Published var error: Error?
    
    private var cancellables = Set<AnyCancellable>()
    private let networkManager = NetworkManager.shared
    
    func loadSleepData(for date: Date) {
        isLoading = true
        error = nil
        
        networkManager.getSleepData(for: date)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.error = error
                }
            } receiveValue: { [weak self] sleepData in
                self?.currentSleepData = sleepData
            }
            .store(in: &cancellables)
    }
}

// MARK: - 数据模型
struct SleepData: Identifiable, Codable {
    let id: String
    let date: Date
    let totalSleepDuration: Int // 分钟
    let sleepQuality: String
    let deepSleepPercentage: Int
    let sleepStages: [SleepStage]
    let heartRateData: [HeartRateData]
}

struct SleepStage: Identifiable, Codable {
    let id: String
    let name: String
    let duration: Int // 分钟
}

struct HeartRateData: Identifiable, Codable {
    let id: String
    let timestamp: Date
    let heartRate: Int
} 