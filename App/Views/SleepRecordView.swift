import SwiftUI
import Charts
/*
struct SleepRecordView: View {
    @State private var selectedDate = Date()
   
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 日期选择器
                    DatePicker(
                        "sleepRecord.selectDate.label".localized,
                        selection: $selectedDate,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .padding()
                    .onChange(of: selectedDate) { newDate in
                        DispatchQueue.main.async {
                            viewModel.loadSleepData(for: newDate)
                        }
                    }
                    
                    // 睡眠概览
                    if let sleepData = viewModel.currentSleepData {
                        SleepOverviewCard(sleepData: sleepData)
                    } else {
                        Text("sleepRecord.noData".localized)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    
                    // 睡眠阶段图表
                    if let sleepData = viewModel.currentSleepData {
                        SleepStageChart(sleepData: sleepData)
                    }
                    
                    // 心率趋势
                    if let sleepData = viewModel.currentSleepData {
                        HeartRateChart(sleepData: sleepData)
                    }
                }
            }
            .navigationBarTitle("sleepRecord.title".localized, displayMode: .inline)
            .onAppear {
                DispatchQueue.main.async {
                    viewModel.loadSleepData(for: selectedDate)
                }
            }
        }
    }
    
}
*/
struct SleepOverviewCard: View {
    let sleepData: SleepData
    
    var body: some View {
        VStack(spacing: 16) {
            Text("sleepRecord.overview.title".localized)
                .font(.headline)
            
            HStack(spacing: 24) {
                VStack {
                    Text("\(formatDuration(sleepData.totalSleepDuration))")
                        .font(.title2)
                        .bold()
                    Text("sleepRecord.overview.totalDuration".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text(sleepData.sleepQuality) // Assuming sleepQuality itself is a localized string or a key
                        .font(.title2)
                        .bold()
                    Text("sleepRecord.overview.quality".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text(String(format: "sleepRecord.overview.deepSleepPercentage.format".localized, sleepData.deepSleepPercentage))
                        .font(.title2)
                        .bold()
                    Text("sleepRecord.overview.deepSleepPercentage.label".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
    
    private func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return String(format: "duration.hoursMinutes".localized, hours, remainingMinutes)
    }
}

struct SleepStageChart: View {
    let sleepData: SleepData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("sleepRecord.stages.title".localized)
                .font(.headline)
                .padding(.horizontal)
            
            Chart {
                ForEach(sleepData.sleepStages) { stage in
                    BarMark(
                        x: .value("sleepRecord.chart.stageAxisLabel".localized, "stage.\(stage.name.lowercased())".localized), // Assuming stage.name is a key like "deep_sleep"
                        y: .value("sleepRecord.chart.durationAxisLabel".localized, stage.duration)
                    )
                    .foregroundStyle(stageColor(for: stage.name))
                }
            }
            .frame(height: 200)
            .padding()
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
    
    private func stageColor(for stageName: String) -> Color {
        // Assuming stageName is a key like "deep_sleep", "light_sleep", etc.
        // Or, if SleepStage has an enum type, switch on that.
        switch stageName.lowercased() { // Example if stageName is a key
        case "deep_sleep":
            return .blue
        case "light_sleep":
            return .green
        case "rem":
            return .purple
        case "awake":
            return .orange
        default:
            return .gray
        }
    }
}

struct HeartRateChart: View {
    let sleepData: SleepData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("sleepRecord.heartRate.title".localized)
                .font(.headline)
                .padding(.horizontal)
            
            Chart {
                ForEach(sleepData.heartRateData) { data in
                    LineMark(
                        x: .value("sleepRecord.chart.timeAxisLabel".localized, data.timestamp),
                        y: .value("sleepRecord.chart.heartRateAxisLabel".localized, data.heartRate)
                    )
                    .foregroundStyle(.red)
                }
            }
            .frame(height: 200)
            .padding()
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
}

#Preview {
   
} 
