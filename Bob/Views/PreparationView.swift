import SwiftUI

struct PreparationView: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var inputFocused: Bool
    @State private var input: String
    @State private var isSaving = false
    @State private var saveFailed = false

    init(model: AppModel) {
        self.model = model
        _input = State(initialValue: model.planText)
    }

    private var hasGoals: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Your goals for the morning")
                    .font(.title2.bold())
                    .accessibilityAddTraits(.isHeader)

                TextField("This morning, I want to…", text: $input, axis: .vertical)
                    .lineLimit(5...12)
                    .textInputAutocapitalization(.sentences)
                    .focused($inputFocused)
                    .bobField()
                    .accessibilityLabel("Morning goals and objectives")
                    .accessibilityIdentifier("plan.input")

                if saveFailed {
                    BobNotice(title: "Couldn't save your goals",
                              message: model.errorMessage ?? "Please try again.",
                              symbol: "exclamationmark.circle")
                }
            }
            .padding(20)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: save) {
                BusyLabel(title: isSaving ? "Saving…" : "Done", busy: isSaving)
            }
            .buttonStyle(BobButtonStyle())
            .disabled(!hasGoals || isSaving || model.isBusy)
            .accessibilityIdentifier("plan.done")
            .padding(20)
            .background(BobTheme.background)
        }
        .scrollDismissesKeyboard(.interactively)
        .bobScreen()
        .navigationTitle("Plan my morning")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
                    .frame(minHeight: 44)
                    .disabled(isSaving)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done typing") { inputFocused = false }
                    .frame(minHeight: 44)
            }
        }
        .interactiveDismissDisabled(isSaving)
        .task {
            inputFocused = true
        }
    }

    private func save() {
        guard hasGoals, !isSaving, !model.isBusy else { return }
        inputFocused = false
        isSaving = true
        saveFailed = false
        model.errorMessage = nil
        Task {
            let saved = await model.savePlan(input)
            isSaving = false
            if saved {
                dismiss()
            } else {
                saveFailed = true
            }
        }
    }
}
