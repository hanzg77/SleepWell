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
                    "datePicker.selectDate.label".localized,
                    selection: $tempDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding()
            }
            .navigationTitle("datePicker.selectDate.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.confirm".localized) {
                        onDateSelected(tempDate)
                        dismiss()
                    }
                }
            }
        }
    }
} 