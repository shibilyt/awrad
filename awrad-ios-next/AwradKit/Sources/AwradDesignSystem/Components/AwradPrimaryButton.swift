import SwiftUI

/// The one full-width call to action per screen. A destructive one (deleting something for
/// good) is drawn in the error colour.
public struct AwradPrimaryButton: View {
    private let title: LocalizedStringResource
    private let isEnabled: Bool
    private let isDestructive: Bool
    private let action: () -> Void

    public init(
        _ title: LocalizedStringResource, isEnabled: Bool = true, isDestructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isEnabled = isEnabled
        self.isDestructive = isDestructive
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            label.foregroundStyle(isDestructive ? AwradColors.onError : AwradColors.onPrimary)
        }
        .buttonStyle(.borderedProminent)
        .tint(isDestructive ? AwradColors.error : AwradColors.primary)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .disabled(!isEnabled)
    }

    private var label: some View {
        Text(title)
            .font(AwradFonts.title())
            .frame(maxWidth: .infinity, minHeight: 56)
    }
}
