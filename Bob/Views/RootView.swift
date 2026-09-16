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
            VStack(alignment: .leading, spacing: 0) {
                BobPortrait(size: 248)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
                    .offset(y: 6)
                    .background(BobTheme.header.ignoresSafeArea(edges: .top))
                VStack(alignment: .leading, spacing: 24) {
                    ModelErrorView(model: model)
                    Text("Meet Bob.")
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text("A plan before bed.\nA challenge when you wake.")
                        .font(.title3)
                        .foregroundStyle(BobTheme.secondaryText)
                    Text("Your plans stay on your iPhone.")
                        .font(.footnote)
                        .foregroundStyle(BobTheme.secondaryText)
                }
                .padding(24)
                .frame(maxWidth: 600, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
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
        .toolbarBackground(BobTheme.header, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}
