import SwiftUI
import BobCore

struct PlanCard: View {
    let plan: MorningPlan
    var title = "Your morning plan"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title3.bold()).accessibilityAddTraits(.isHeader)
            if !plan.originalIntent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(plan.originalIntent)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("plan.text")
            } else {
                // Plans saved by older app versions may only have step data.
                Text(plan.steps.joined(separator: "\n"))
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .accessibilityIdentifier("plan.text")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
