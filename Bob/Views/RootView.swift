import SwiftUI
import BobCore
import BobPlan

struct RootView: View {
    let model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var sheet: HomeSheet?
    @State private var prepareAfterSetup = false

    private enum HomeSheet: String, Identifiable {
        case alarm, preparation
        var id: String { rawValue }
    }

    var body: some View {
        Group {
            if model.morningPresented {
                NavigationStack { MorningView(model: model) }
            } else {
                NavigationStack {
                    Group {
                        if model.setupComplete {
                            HomeView(model: model, onSettings: { sheet = .alarm },
                                     onPrepare: { sheet = .preparation })
                        } else {
                            WelcomeView(model: model) { sheet = .alarm }
                        }
                    }
                }
            }
        }
        .bobScreen()
        .sheet(item: $sheet, onDismiss: {
            if prepareAfterSetup && !model.morningPresented {
                prepareAfterSetup = false
                sheet = .preparation
            }
        }) { destination in
            NavigationStack {
                switch destination {
                case .alarm:
                    AlarmSettingsView(model: model) { wasSetup in
                        prepareAfterSetup = wasSetup
                        sheet = nil
                    }
                case .preparation:
                    PreparationView(model: model)
                }
            }
            .bobScreen()
        }
        .task(id: scenePhase) {
            if scenePhase == .active { await model.refresh() }
        }
        .onChange(of: model.morningPresented) { _, presented in
            if presented {
                sheet = nil
                prepareAfterSetup = false
            }
        }
    }
}

private struct WelcomeView: View {
    let model: AppModel
    let onStart: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                ModelErrorView(model: model)
                BobPortrait(size: 220)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Meet Bob.")
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text("A little company for tonight.\nA small nudge for tomorrow.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                BobPanel {
                    Label("Leave a plan before bed", systemImage: "moon")
                    Label("Wake up to one chosen challenge", systemImage: "sun.max")
                    Label("Keep your intentions close", systemImage: "text.book.closed")
                }
                Text("All on your iPhone. Bob is a homebody.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            Button("Set up my morning", action: onStart)
                .buttonStyle(BobButtonStyle())
                .accessibilityIdentifier("welcome.start")
                .padding(20)
                .background(BobTheme.background)
        }
        .bobScreen()
        .navigationTitle("Bob")
        .navigationBarTitleDisplayMode(.inline)
    }
}
