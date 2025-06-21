import SwiftUI
struct AdminView: View {
    @Environment(\.dismiss) private var dismiss
    let resource: Resource
    
    @State private var showTagSelection = false
    @State private var showDeleteConfirmation = false
    @State private var selectedTags: Set<String> = []
    
    // 假设这些是所有可用的标签
  //  let availableTags = ["白噪声", "冥想", "故事", "音乐", "自然", "放松", "睡眠"]
    let availableTags = ["white_noise", "meditation", "story", "music", "nature"]
    var body: some View {
        NavigationView {
            List {
                // MARK: - 资源信息
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(resource.name)
                            .font(.headline)
                        Text("ID: \(resource.id)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }
                
                // MARK: - 标签管理
                Section(header: Text("adminView.section.tags".localized)) {
                    Button(action: {
                        selectedTags = Set(resource.tags)
                        showTagSelection = true
                    }) {
                        HStack {
                            Text("管理标签")
                            Spacer()
                            Image(systemName: "tag")
                        }
                    }
                        
                    // 显示当前资源的标签
                    if !resource.tags.isEmpty {
                        ForEach(resource.tags, id: \.self) { tag in
                            Text("tag.\(tag)".localized) // 本地化标签显示
                        }
                    } else {
                        Text("adminView.noTags".localized)
                            .foregroundColor(.gray)
                    }
                }
                
                // MARK: - 危险操作
                Section {
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        HStack {
                            Text("adminView.deleteResource.button".localized)
                                .foregroundColor(.red)
                            Spacer()
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("adminView.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("action.done".localized) {
                dismiss()
            })
            // MARK: - 弹窗与表单
            .confirmationDialog(
                "adminView.deleteConfirm.title".localized,
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("adminView.deleteResource.button".localized, role: .destructive) { // 使用与按钮文本相同的键
                    performDelete() // 调用抽离出的方法
                }
                Button("action.cancel".localized, role: .cancel) {}
            } message: {
                Text(String(format: "adminView.deleteConfirm.message".localized, resource.name))
            }
            .sheet(isPresented: $showTagSelection) {
                tagSelectionView
            }
        }
    }
    
    // MARK: - 标签选择视图 (作为计算属性，保持 body 清洁)
    private var tagSelectionView: some View {
        NavigationView {
            List {
                // 已选中的标签区域 (Section header)
                Section(header: Text("adminView.tagSelection.currentTags".localized)) {
                    ForEach(Array(selectedTags).sorted(), id: \.self) { tag in
                        Button(action: {
                            selectedTags.remove(tag)
                        }) {
                            HStack {
                                Text("tag.\(tag)".localized) // 本地化标签显示
                                Spacer()
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .foregroundColor(.primary)
                        }
                    }
                    .onDelete { indexSet in
                        let tagsToRemove = indexSet.map { Array(selectedTags).sorted()[$0] }
                        for tag in tagsToRemove {
                            selectedTags.remove(tag)
                        }
                    }
                }

                // 可添加的标签区域 (Section header)
                Section(header: Text("adminView.tagSelection.availableTags".localized)) {
                    let unselectedTags = availableTags.filter { !selectedTags.contains($0) }
                    ForEach(unselectedTags, id: \.self) { tag in
                        Button(action: {
                            selectedTags.insert(tag)
                        }) {
                             HStack {
                                Text("tag.\(tag)".localized) // 本地化标签显示
                                Spacer()
                                Image(systemName: "plus.circle")
                            }
                            .foregroundColor(.accentColor)
                        }
                    }
                }
            }
            .navigationTitle("adminView.manageTags.title".localized)
            .navigationBarItems(
                leading: Button("action.cancel".localized) {
                    showTagSelection = false
                },
                trailing: Button("action.save".localized) {
                    saveTagChanges() // 调用抽离出的方法
                }
            )
        }
    }
    
    // MARK: - 逻辑处理方法
    
    /// 保存对标签的更改
    private func saveTagChanges() {
        let originalTags = Set(resource.tags)
        
        let tagsToAdd = selectedTags.subtracting(originalTags)
        let tagsToRemove = originalTags.subtracting(selectedTags)
        
        // 调用 API 添加新标签
        if !tagsToAdd.isEmpty {
            NetworkManager.shared.addTags(to: resource.id, tags: Array(tagsToAdd)) { result in
                if case .failure(let error) = result {
                    print("添加标签失败: \(error.localizedDescription)")
                    if let networkError = error as? NetworkError {
                        print("错误类型: \(networkError)")
                        print("错误描述: \(networkError.errorDescription ?? "未知错误")")
                        print("失败原因: \(networkError.failureReason ?? "未知原因")")
                    } else {
                        print("其他错误: \(error)")
                    }
                    // 这里可以添加用户提示，例如弹出一个 Alert
                } else {
                    print("成功添加标签: \(tagsToAdd)")
                    // 成功后可以在这里更新本地数据模型
                }
            }
        }
        
        // 调用 API 移除旧标签
        if !tagsToRemove.isEmpty {
            NetworkManager.shared.removeTags(from: resource.id, tags: Array(tagsToRemove)) { result in
                if case .failure(let error) = result {
                    print("移除标签失败: \(error.localizedDescription)")
                    if let networkError = error as? NetworkError {
                        print("错误类型: \(networkError)")
                        print("错误描述: \(networkError.errorDescription ?? "未知错误")")
                        print("失败原因: \(networkError.failureReason ?? "未知原因")")
                    } else {
                        print("其他错误: \(error)")
                    }
                    // 这里可以添加用户提示
                } else {
                     print("成功移除标签: \(tagsToRemove)")
                    // 成功后可以在这里更新本地数据模型
                }
            }
        }
        
        // 关闭 sheet
        showTagSelection = false
    }
    
    /// 执行删除资源的操作
    private func performDelete() {
        Task { @MainActor in
            do {
                print("🗑️ 开始删除资源: \(resource.name) (ID: \(resource.resourceId))")
                let response = try await NetworkManager.shared.deleteResource(resourceId: resource.resourceId)
                print("📦 服务端返回内容: \(response)")
                
                if response.success {
                    // 从本地列表中移除
                    print("📋 从本地列表中移除资源")
                } else {
                    print("❌ 删除失败: \(response.message)")
                }
            } catch {
                print("❌ 删除资源失败: \(error)")
               
            }
        }
    }
}
