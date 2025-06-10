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
                        "选择日期",
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
                        Text("暂无睡眠数据")
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
            .navigationBarTitle("睡眠记录", displayMode: .inline)
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
            Text("睡眠概览")
                .font(.headline)
            
            HStack(spacing: 24) {
                VStack {
                    Text("\(formatDuration(sleepData.totalSleepDuration))")
                        .font(.title2)
                        .bold()
                    Text("总睡眠时长")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text(sleepData.sleepQuality)
                        .font(.title2)
                        .bold()
                    Text("睡眠质量")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(sleepData.deepSleepPercentage)%")
                        .font(.title2)
                        .bold()
                    Text("深睡比例")
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
        return "\(hours)小时\(remainingMinutes)分钟"
    }
}

struct SleepStageChart: View {
    let sleepData: SleepData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("睡眠阶段")
                .font(.headline)
                .padding(.horizontal)
            
            Chart {
                ForEach(sleepData.sleepStages) { stage in
                    BarMark(
                        x: .value("阶段", stage.name),
                        y: .value("时长", stage.duration)
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
        switch stageName {
        case "深睡":
            return .blue
        case "浅睡":
            return .green
        case "REM":
            return .purple
        case "清醒":
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
            Text("心率趋势")
                .font(.headline)
                .padding(.horizontal)
            
            Chart {
                ForEach(sleepData.heartRateData) { data in
                    LineMark(
                        x: .value("时间", data.timestamp),
                        y: .value("心率", data.heartRate)
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
