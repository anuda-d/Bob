import SwiftUI
import UIKit
import BobCore

enum BobTheme {
    static let background = Color(uiColor: .systemGroupedBackground)
    static let panel = Color(uiColor: .secondarySystemGroupedBackground)
    static let field = Color(uiColor: .tertiarySystemGroupedBackground)
    static let green = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.57, green: 0.77, blue: 0.57, alpha: 1)
            : UIColor(red: 0.22, green: 0.39, blue: 0.25, alpha: 1)
    })
    static let onGreen = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.08, green: 0.14, blue: 0.09, alpha: 1)
            : .white
    })
    static let panelRadius: CGFloat = 20
    static let controlRadius: CGFloat = 14
}

struct BobButtonStyle: ButtonStyle {
    var secondary = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(secondary ? BobTheme.green : BobTheme.onGreen)
            .background(secondary ? BobTheme.green.opacity(0.12) : BobTheme.green,
                        in: RoundedRectangle(cornerRadius: BobTheme.controlRadius))
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.45)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
            .contentShape(RoundedRectangle(cornerRadius: BobTheme.controlRadius))
    }
}

struct BobPanel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(BobTheme.panel, in: RoundedRectangle(cornerRadius: BobTheme.panelRadius))
    }
}

struct BobPortrait: View {
    var size: CGFloat = 140

    var body: some View {
        Image("Bob")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct BobNotice: View {
    let title: String
    let message: String
    var symbol = "info.circle"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

struct ModelErrorView: View {
    let model: AppModel

    var body: some View {
        if let message = model.errorMessage {
            BobPanel {
                BobNotice(title: "Something needs attention", message: message,
                          symbol: "exclamationmark.circle")
                Button("Dismiss message") { model.errorMessage = nil }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("error.dismiss")
            }
            .accessibilityIdentifier("app.error")
        }
    }
}

struct BusyLabel: View {
    let title: String
    let busy: Bool

    var body: some View {
        HStack(spacing: 10) {
            if busy { ProgressView().tint(BobTheme.onGreen).accessibilityHidden(true) }
            Text(title)
        }
        .accessibilityLabel(title)
    }
}

extension View {
    func bobField() -> some View {
        padding(14)
            .frame(minHeight: 50)
            .background(BobTheme.field, in: RoundedRectangle(cornerRadius: BobTheme.controlRadius))
    }

    func bobScreen() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BobTheme.background)
            .fontDesign(.rounded)
            .tint(BobTheme.green)
            .modifier(TestingAppearance())
    }
}

enum BobCopy {
    static func challenge(_ kind: ChallengeKind) -> String {
        switch kind {
        case .pushups: "20 seconds of pushups"
        case .puzzle: "Solve a puzzle"
        case .qr: "Scan your QR code"
        }
    }

    static func symbol(_ kind: ChallengeKind) -> String {
        switch kind {
        case .pushups: "figure.strengthtraining.functional"
        case .puzzle: "puzzlepiece.extension"
        case .qr: "qrcode.viewfinder"
        }
    }

    static func difficulty(_ value: PuzzleDifficulty) -> String {
        value == .easy ? "Easy" : "Hard"
    }

    static func challengeDetail(_ configuration: ChallengeConfiguration) -> String {
        if configuration.kind == .puzzle {
            return configuration.difficulty == .easy ? "Easy · one problem" : "Hard · three problems"
        }
        if let fallback = configuration.fallback {
            return "\(difficulty(fallback)) puzzle fallback available"
        }
        return "No puzzle fallback configured"
    }

    static func repeatDays(_ days: Set<Int>) -> String {
        if days.isEmpty { return "Once" }
        if days == Set(1...7) { return "Every day" }
        if days == Set(2...6) { return "Weekdays" }
        if days == Set([1, 7]) { return "Weekends" }
        return orderedWeekdays.filter { days.contains($0) }
            .map { Calendar.current.shortWeekdaySymbols[$0 - 1] }.joined(separator: ", ")
    }

    static var orderedWeekdays: [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { ((first - 1 + $0) % 7) + 1 }
    }

    static func time(_ settings: AlarmSettings) -> Date {
        Calendar.current.date(from: DateComponents(hour: settings.hour, minute: settings.minute)) ?? .now
    }

    static func completion(_ method: CompletionMethod?) -> String {
        switch method {
        case .pushups: "20 seconds of pushup activity verified."
        case .puzzle: "Your puzzle is solved."
        case .qr: "Your registered QR code was scanned."
        case .fallbackEasy: "Completed with your easy puzzle fallback."
        case .fallbackHard: "Completed with your hard puzzle fallback."
        case nil: "Your morning challenge is complete."
        }
    }
}
