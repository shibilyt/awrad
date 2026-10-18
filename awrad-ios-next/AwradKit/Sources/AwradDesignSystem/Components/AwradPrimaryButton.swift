import SwiftUI

/// The one full-width call to action per screen.
public struct AwradPrimaryButton: View {
    private let title: LocalizedStringResource
    private let isEnabled: Bool
    private let action: () -> Void

    public init(_ title: LocalizedStringResource, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.isEnabled = isEnabled
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(AwradFonts.title())
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.borderedProminent)
        .tint(AwradColors.primary)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .disabled(!isEnabled)
    }
}
