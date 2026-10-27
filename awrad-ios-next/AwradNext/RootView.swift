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
        // Onboarding and home swap in place with the `contentSwap` fade.
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
                        .awradSheet()
                }
            case nil:
                AwradColors.background.ignoresSafeArea()
            }
        }
        .awradContentSwap(value: destination)
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
        VStack(spacing: AwradSpacing.rowGap) {
            Text("home.placeholder.title")
                .awradTextStyle(.title)
                .foregroundStyle(AwradColors.onSurface)
            Text("home.placeholder.body")
                .awradTextStyle(.body)
                .foregroundStyle(AwradColors.onSurfaceVariant)
                .multilineTextAlignment(.center)
            AwradPrimaryButton("home.placeholder.account", action: onShowAccount)
                .padding(.top, AwradSpacing.xl2)
            Button("home.placeholder.restart", action: onRestartOnboarding)
                .tint(AwradColors.accent)
                .padding(.top, AwradSpacing.md)
        }
        .padding(AwradSpacing.pageMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AwradColors.background)
    }
}
