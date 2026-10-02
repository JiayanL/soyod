import SwiftUI
import SwiftData

@main
struct AtlasApp: App {
    @State private var appState: AppState

    init() {
        let state = AppState()
        _appState = State(initialValue: state)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .onOpenURL { url in
                    if let route = LaunchRoute(url: url) {
                        appState.pendingRoute = route
                    }
                }
                .task {
                    await appState.importHealth()
                }
        }
        .modelContainer(appState.container)
    }
}
