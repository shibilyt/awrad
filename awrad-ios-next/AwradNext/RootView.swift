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
        #if DEBUG
            // `-AwradGallery YES` opens the component gallery instead, and
            // `-AwradAccountScreenshot settings|devices` a signed-in account screen with sample
            // state (debug builds only).
            if UserDefaults.standard.bool(forKey: "AwradGallery") {
                AwradComponentGallery()
            } else if let page = UserDefaults.standard.string(forKey: "AwradAccountScreenshot")
                .flatMap(AccountScreenshot.Page.init(rawValue:))
            {
                AccountScreenshot(page)
            } else {
                destinations
            }
        #else
            destinations
        #endif
    }

    private var destinations: some View {
        // Onboarding and home swap in place with the `contentSwap` fade.
        Group {
            switch destination {
            case .onboarding:
                OnboardingRoute(status: composition.onboardingStatus) { destination = .home }
            case .home:
                AppShell(
                    composition: composition,
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
