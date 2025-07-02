import SwiftUI

struct NetworkStatusView: View {
    @ObservedObject private var networkManager = NetworkManager.shared
    
    var body: some View {
        HStack(spacing: 8) {
            // 网络状态图标
            Image(systemName: networkManager.isNetworkAvailable ? "wifi" : "wifi.slash")
                .foregroundColor(networkManager.isNetworkAvailable ? .green : .red)
            
            // 网络状态文本
            Text(networkManager.isNetworkAvailable ? "网络正常" : "网络不可用")
                .font(.caption)
                .foregroundColor(networkManager.isNetworkAvailable ? .green : .red)
            
            // 网络类型
            if networkManager.isNetworkAvailable {
                Text("(\(networkManager.networkType))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 重试按钮（仅在网络可用且有失败请求时显示）
            if networkManager.isNetworkAvailable && !networkManager.failedRequests.isEmpty {
                Button("重试") {
                    networkManager.retryAllFailedRequests()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    NetworkStatusView()
        .padding()
} 