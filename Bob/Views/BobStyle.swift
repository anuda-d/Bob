import SwiftUI
import UIKit
import BobCore

enum BobTheme {
    static let background = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.09, green: 0.12, blue: 0.10, alpha: 1)
            : UIColor(red: 0.97, green: 0.98, blue: 0.96, alpha: 1)
    })
    static let header = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.16, green: 0.25, blue: 0.17, alpha: 1)
            : UIColor(red: 0.78, green: 0.84, blue: 0.71, alpha: 1)
    })
    static let onHeader = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.94, green: 0.96, blue: 0.91, alpha: 1)
            : UIColor(red: 0.10, green: 0.18, blue: 0.11, alpha: 1)
    })
    static let secondaryText = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 174 / 255, green: 185 / 255, blue: 171 / 255, alpha: 1)
            : UIColor(red: 82 / 255, green: 97 / 255, blue: 82 / 255, alpha: 1)
    })
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
    // Custom controls are crisp; system sheets, pickers and switches keep native geometry.
    static let controlRadius: CGFloat = 8
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
            .background(secondary ? Color.clear : BobTheme.green,
                        in: RoundedRectangle(cornerRadius: BobTheme.controlRadius))
            .overlay {
                if secondary {
                    RoundedRectangle(cornerRadius: BobTheme.controlRadius)
                        .strokeBorder(BobTheme.green.opacity(0.55), lineWidth: 1)
                }
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.45)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
            .contentShape(RoundedRectangle(cornerRadius: BobTheme.controlRadius))
    }
}

struct BobSection<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 16)
            .overlay(alignment: .top) { Divider() }
    }
}

enum BobPose: String {
    case resting = "BobResting"
    case listening = "BobListening"
    case pleased = "BobPleased"
}

struct BobPortrait: View {
    var size: CGFloat = 140
    var pose: BobPose = .resting

    var body: some View {
        Image(pose.rawValue)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            // Held illustrations switch with app state, without morphs or idle loops.
            .transaction { $0.animation = nil }
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
                .foregroundStyle(BobTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

struct ModelErrorView: View {
    let model: AppModel

    var body: some View {
        if let message = model.errorMessage {
            BobSection {
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
            .fontDesign(.default)
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
