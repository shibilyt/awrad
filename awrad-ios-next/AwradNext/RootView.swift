import AwradData
import AwradDesignSystem
import FeatureAccount
import FeatureOnboarding
import FeaturePracticeSettings
import SwiftUI

/// Decides where the app starts and switches between top-level destinations.
struct RootView: View {
    let composition: AppComposition
    @State private var destination: Destination?
    @State private var showsAccount = false
    @Environment(\.scenePhase) private var scenePhase

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
                    AccountRoute(
                        service: composition.account, profiles: composition.profiles,
                        practiceSettings: { AnyView(PracticeSettingsRoute(services: composition.practice)) },
                        onClose: { showsAccount = false }
                    )
                    .awradSheet()
                    // The account-deleted question also shows over the account sheet.
                    .awradProfilePrompts(composition.profiles)
                }
            case nil:
                AwradColors.background.ignoresSafeArea()
            }
        }
        .awradContentSwap(value: destination)
        .awradProfilePrompts(composition.profiles)
        .task {
            #if DEBUG
                await SampleLaunchState.seedIfAsked(composition.profiles)
            #endif
            await composition.profiles.start()
            destination = await composition.onboardingStatus.isOnboarded() ? .home : .onboarding
        }
        // Sync at launch and on returning to the foreground, then every 5 minutes while active.
        .onChange(of: scenePhase, initial: true) { _, phase in
            Task { await composition.profiles.setAppActive(phase == .active) }
        }
    }
}
