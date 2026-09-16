import SwiftUI
import BobCore

struct PlanCard: View {
    let plan: MorningPlan
    var title = "Your morning plan"
    var compact = true

    private var visibleSteps: [String] {
        compact ? Array(plan.steps.prefix(3)) : plan.steps
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.title3.bold()).accessibilityAddTraits(.isHeader)
                Text("Confirmed \(plan.confirmedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(BobTheme.secondaryText)
                    .accessibilityIdentifier("plan.confirmedDate")
            }
            if !plan.reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(plan.reason).font(.body).fixedSize(horizontal: false, vertical: true)
            }
            steps(visibleSteps, startingAt: 1)
            if compact && plan.steps.count > 3 {
                DisclosureGroup {
                    steps(Array(plan.steps.dropFirst(3)), startingAt: 4)
                        .padding(.top, 8)
                } label: {
                    Text("\(plan.steps.count - 3) more steps").frame(minHeight: 44)
                }
            }
            if !plan.originalIntent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                DisclosureGroup {
                    Text(plan.originalIntent)
                        .foregroundStyle(BobTheme.secondaryText)
                        .textSelection(.enabled)
                        .padding(.top, 8)
                } label: {
                    Text("In your words").font(.subheadline).frame(minHeight: 44)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func steps(_ values: [String], startingAt number: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("\(index + number)")
                        .font(.subheadline.monospacedDigit().bold())
                        .foregroundStyle(BobTheme.green)
                        .frame(minWidth: 20)
                        .accessibilityHidden(true)
                    Text(step).fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Step \(index + number). \(step)")
            }
        }
    }
}
