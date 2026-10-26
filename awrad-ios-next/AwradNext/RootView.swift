import AwradDesignSystem
import FeatureAccount
import FeatureOnboarding
import SwiftUI

/// Decides where the app starts and switches between top-level destinations.
struct RootView: View {
    let composition: AppComposition
    @State private var destination: Destination?
    @State private var showsAccount = false

    enum Destination {
        case onboarding
        case home
    }

    var body: some View {
        Group {
            switch destination {
            case .onboarding:
                OnboardingRoute(status: composition.onboardingStatus) { destination = .home }
            case .home:
                HomePlaceholderView(
                    onShowAccount: { showsAccount = true },
                    onRestartOnboarding: {
                        Task {
                            await composition.onboardingStatus.reset()
                            destination = .onboarding
                        }
                    }
                )
                .sheet(isPresented: $showsAccount) {
                    AccountRoute(service: composition.account) { showsAccount = false }
                }
            case nil:
                AwradColors.background.ignoresSafeArea()
            }
        }
        .task {
            destination = await composition.onboardingStatus.isOnboarded() ? .home : .onboarding
        }
    }
}

/// Stand-in until the first real home feature module exists.
struct HomePlaceholderView: View {
    let onShowAccount: () -> Void
    let onRestartOnboarding: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("home.placeholder.title")
                .font(AwradFonts.headline())
                .foregroundStyle(AwradColors.primary)
            Text("home.placeholder.body")
                .font(AwradFonts.body())
                .foregroundStyle(AwradColors.onSurfaceVariant)
                .multilineTextAlignment(.center)
            AwradPrimaryButton("home.placeholder.account", action: onShowAccount)
                .padding(.top, 24)
            Button("home.placeholder.restart", action: onRestartOnboarding)
                .tint(AwradColors.primary)
                .padding(.top, 12)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AwradColors.background)
    }
}
