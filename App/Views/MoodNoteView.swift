import SwiftUI
/*
 struct MoodNoteView: View {
 let date: Date
 @Environment(\.dismiss) private var dismiss
 @StateObject private var logManager = SleepLogManager.shared
 @StateObject private var guardianController = GuardianController.shared
 
 @State private var selectedMood: Mood?
 @State private var notes: String = ""
 
 var body: some View {
 NavigationView {
 ScrollView {
 VStack(spacing: 24) {
 // 心情选择
 VStack(alignment: .leading, spacing: 12) {
 Text("今天的心情")
 .font(.headline)
 
 LazyVGrid(columns: [
 GridItem(.flexible()),
 GridItem(.flexible()),
 GridItem(.flexible())
 ], spacing: 12) {
 ForEach(Mood.presets) { mood in
 MoodButton(
 mood: mood,
 isSelected: selectedMood?.id == mood.id,
 action: { selectedMood = mood }
 )
 }
 }
 }
 .padding()
 
 // 手记输入
 VStack(alignment: .leading, spacing: 12) {
 Text("写下此刻的心情")
 .font(.headline)
 
 TextEditor(text: $notes)
 .frame(minHeight: 120)
 .padding(8)
 .background(Color(.systemGray6))
 .cornerRadius(12)
 }
 .padding()
 }
 }
 .navigationTitle("睡眠手记")
 .navigationBarTitleDisplayMode(.inline)
 .toolbar {
 ToolbarItem(placement: .cancellationAction) {
 Button("取消") {
 dismiss()
 }
 }
 
 ToolbarItem(placement: .confirmationAction) {
 Button("保存") {
 saveNotes()
 dismiss()
 }
 }
 }
 }
 }
 
 private func saveNotes() {
 // 保存到 GuardianController
 guardianController.currentSessionMood = selectedMood
 guardianController.currentSessionNotes = notes
 
 // 保存到 SleepLogManager
 logManager.updateDailyLog(for: date, mood: selectedMood, notes: notes)
 }
 }
 
 struct MoodButton: View {
 let mood: Mood
 let isSelected: Bool
 let action: () -> Void
 
 var body: some View {
 Button(action: action) {
 VStack(spacing: 8) {
 Text(mood.emoji)
 .font(.system(size: 32))
 Text(mood.description)
 .font(.caption)
 .foregroundColor(.primary)
 }
 .frame(maxWidth: .infinity)
 .padding(.vertical, 12)
 .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
 .cornerRadius(12)
 .overlay(
 RoundedRectangle(cornerRadius: 12)
 .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
 )
 }
 }
 
 }
 */
