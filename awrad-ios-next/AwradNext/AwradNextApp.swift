import AwradDesignSystem
import SwiftUI

@main
struct AwradNextApp: App {
    /// Built once at launch; the only place adapters meet ports (ADR 0001).
    @State private var composition = AppComposition.live()

    init() {
        AwradFonts.register()
        // The native navigation bar's large and inline titles in the interface font.
        AwradNavigationBarAppearance.apply()
    }

    var body: some Scene {
        WindowGroup {
            RootView(composition: composition)
        }
    }
}
