
import SwiftUI
struct AdminView: View {
    @Environment(\.dismiss) private var dismiss
    let resource: Resource
    
    @State private var showTagSelection = false
    @State private var showDeleteConfirmation = false
    @State private var selectedTags: Set<String> = []
    
    // 假设这些是所有可用的标签
    let availableTags = ["白噪声", "冥想", "故事", "音乐", "自然", "放松", "睡眠"]
    
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
                Section(header: Text("标签")) {
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
                            Text(tag)
                        }
                    } else {
                        Text("暂无标签")
                            .foregroundColor(.gray)
                    }
                }
                
                // MARK: - 危险操作
                Section {
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        HStack {
                            Text("删除资源")
                                .foregroundColor(.red)
                            Spacer()
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationTitle("资源管理")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("完成") {
                dismiss()
            })
            // MARK: - 弹窗与表单
            .confirmationDialog(
                "确认删除",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("删除", role: .destructive) {
                    performDelete() // 调用抽离出的方法
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("确定要删除资源 \"\(resource.name)\" 吗？此操作无法撤销。")
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
                // 已选中的标签区域
                Section(header: Text("当前标签")) {
                    ForEach(Array(selectedTags).sorted(), id: \.self) { tag in
                        Button(action: {
                            selectedTags.remove(tag)
                        }) {
                            HStack {
                                Text(tag)
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

                // 可添加的标签区域
                Section(header: Text("可用标签")) {
                    let unselectedTags = availableTags.filter { !selectedTags.contains($0) }
                    ForEach(unselectedTags, id: \.self) { tag in
                        Button(action: {
                            selectedTags.insert(tag)
                        }) {
                             HStack {
                                Text(tag)
                                Spacer()
                                Image(systemName: "plus.circle")
                            }
                            .foregroundColor(.accentColor)
                        }
                    }
                }
            }
            .navigationTitle("管理标签")
            .navigationBarItems(
                leading: Button("取消") {
                    showTagSelection = false
                },
                trailing: Button("保存") {
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

