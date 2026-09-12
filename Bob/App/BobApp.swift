import SwiftUI

@main
struct BobApp: App {
    @State private var model = AppModel.shared
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            RootView(model: model)
                .task(id: phase) {
                    guard phase == .active else { return }
                    while !Task.isCancelled {
                        await model.tick()
                        do { try await Task.sleep(for: .seconds(1)) }
                        catch { return }
                    }
                }
        }
    }
}

struct TestingAppearance: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            content
                .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("--dark-mode") ? .dark : .light)
                .transformEnvironment(\.dynamicTypeSize) { size in
                    if ProcessInfo.processInfo.arguments.contains("--large-text") { size = .accessibility3 }
                }
        } else { content }
        #else
        content
        #endif
    }
}
