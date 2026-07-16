//
//  awradApp.swift
//  awrad
//
//  Created by FAO on 30/05/26.
//

import SwiftUI
import UIKit

@main
struct AwradApp: App {
    @State private var store = AwradStore()
    @State private var router = AppRouter()
    @State private var services = AppServices()
    @State private var pendingURL: URL?

    init() {
        guard #unavailable(iOS 26.0) else { return }

        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.shadowColor = UIColor(AwradTheme.outline)

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(pendingURL: $pendingURL)
                .environment(store)
                .environment(router)
                .environment(services)
                .environment(\.locale, Locale(identifier: store.preferences.appLanguage.localeIdentifier))
                .environment(\.layoutDirection, store.preferences.appLanguage.layoutDirection)
                .modifier(AwradAppTypography(language: store.preferences.appLanguage))
                .preferredColorScheme(store.preferences.colorScheme)
                .task {
                    await store.bootstrap(
                        persistence: services.persistence,
                        initializationError: services.persistenceInitializationError
                    )
                }
                .onOpenURL { url in
                    pendingURL = url
                }
        }
    }
}

private struct AwradAppTypography: ViewModifier {
    let language: AppLanguage

    // A single structural branch so changing language doesn't reset view identity
    // (which would tear down in-progress screens like onboarding).
    func body(content: Content) -> some View {
        content.font(font)
    }

    private var font: Font {
        switch language {
        case .arabic: AwradTheme.arabicFont(.body)
        case .english, .malayalam: AwradTheme.bodyFont(.body)
        }
    }
}
