import SwiftUI

struct DatePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let selectedDate: Date
    let onDateSelected: (Date) -> Void
    @State private var tempDate: Date
    
    init(selectedDate: Date, onDateSelected: @escaping (Date) -> Void) {
        self.selectedDate = selectedDate
        self.onDateSelected = onDateSelected
        self._tempDate = State(initialValue: selectedDate)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "选择日期",
                    selection: $tempDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding()
            }
            .navigationTitle("选择日期")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        onDateSelected(tempDate)
                        dismiss()
                    }
                }
            }
        }
    }
} 