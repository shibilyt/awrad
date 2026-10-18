import AwradDesignSystem
import AwradDomain
import Foundation
import SwiftUI

/// Stateful entry point: owns the model and the exit callback, nothing else.
public struct OnboardingRoute: View {
    @State private var model: OnboardingModel
    private let onFinish: () -> Void

    public init(status: any OnboardingStatusStore, onFinish: @escaping () -> Void) {
        _model = State(initialValue: OnboardingModel(status: status))
        self.onFinish = onFinish
    }

    public var body: some View {
        OnboardingScreen(state: model.state) { action in
            Task { await model.send(action) }
        }
        .onChange(of: model.state.isFinished) { _, isFinished in
            if isFinished { onFinish() }
        }
    }
}

/// Stateless: renders `state` and reports every user intent through `send`.
struct OnboardingScreen: View {
    let state: OnboardingModel.State
    let send: (OnboardingModel.Action) -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            AwradLogoMark()
                .frame(width: 148, height: 148)
            Text(Strings.title)
                .font(AwradFonts.headline())
                .foregroundStyle(AwradColors.primary)
                .multilineTextAlignment(.center)
            Spacer()
            AwradPrimaryButton(Strings.getStarted, isEnabled: !state.isFinishing) {
                send(.getStarted)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AwradColors.background)
    }
}

/// This module's strings, from `Resources/Localizable.xcstrings` (en, ar, ml).
enum Strings {
    private static let bundle = LocalizedStringResource.BundleDescription.atURL(Bundle.module.bundleURL)

    static let title = LocalizedStringResource("onboarding.placeholder.title", bundle: bundle)
    static let getStarted = LocalizedStringResource("onboarding.placeholder.get_started", bundle: bundle)
}

#Preview {
    OnboardingScreen(state: .init()) { _ in }
}
