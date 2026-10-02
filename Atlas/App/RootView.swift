import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var app
    @State private var router = Router()

    var body: some View {
        Group {
            if app.needsOnboarding {
                OnboardingFlow(start: OnbStep(route: app.pendingRoute) ?? .welcome)
                    .transition(.opacity)
            } else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(Theme.Motion.gentle, value: app.needsOnboarding)
        .environment(router)
        .tint(Theme.Palette.textPrimary)
        .onAppear {
            if app.launch.uiTest { UIView.setAnimationsEnabled(false) }
        }
    }
}
