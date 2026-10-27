import AwradDesignSystem
import AwradDomain
import SwiftUI

/// Every place the account is signed in, this device first. Any other one can be signed out,
/// or all of them at once; this device signs out from the overview.
struct DevicesView: View {
    let state: AccountModel.State
    let send: (AccountModel.Action) -> Void

    var body: some View {
        AccountForm(title: DeviceStrings.title, message: DeviceStrings.body, feedback: state.feedback) {
            switch state.sessions {
            case .loading:
                ProgressView()
                    .tint(AwradColors.progress)
                    .frame(maxWidth: .infinity, minHeight: 80)
            case .unavailable:
                AccountLinkButton(title: DeviceStrings.retry, isEnabled: !state.isWorking) { send(.devicesAppeared) }
            case .loaded(let sessions):
                // Rows in a card are separated by spacing, not divider lines.
                VStack(spacing: 8) {
                    ForEach(sessions) { session in
                        SessionRow(session: session, isEnabled: !state.isWorking) { send(.revokeTapped(session)) }
                    }
                }
                .padding(.vertical, 4)
                .awradCard()
            }
        } actions: {
            if case .loaded(let sessions) = state.sessions, sessions.contains(where: { !$0.isCurrent }) {
                AccountLinkButton(title: DeviceStrings.signOutOthers, isEnabled: !state.isWorking, isDestructive: true)
                {
                    send(.revokeOthersTapped)
                }
            }
        }
        .task { send(.devicesAppeared) }
        .confirmationDialog(
            Text(confirmationTitle), isPresented: isAsking, titleVisibility: .visible, presenting: state.confirmation
        ) { confirmation in
            Button(role: .destructive) {
                switch confirmation {
                case .revokeSession(let session): send(.revokeConfirmed(session.id))
                default: send(.revokeOthersConfirmed)
                }
            } label: {
                Text(confirmation == .revokeOtherSessions ? DeviceStrings.signOutOthersConfirm : DeviceStrings.revoke)
            }
            Button(role: .cancel) {
                send(.confirmationDismissed)
            } label: {
                Text(Strings.cancel)
            }
        } message: { confirmation in
            Text(
                confirmation == .revokeOtherSessions ? DeviceStrings.signOutOthersMessage : DeviceStrings.revokeMessage)
        }
    }

    private var isAsking: Binding<Bool> {
        Binding(
            get: {
                switch state.confirmation {
                case .revokeSession, .revokeOtherSessions: true
                case .deleteAccount, nil: false
                }
            },
            set: { if !$0 { send(.confirmationDismissed) } })
    }

    private var confirmationTitle: LocalizedStringResource {
        switch state.confirmation {
        case .revokeSession(let session): DeviceStrings.revokeTitle(DeviceStrings.name(of: session))
        default: DeviceStrings.signOutOthersTitle
        }
    }
}

/// One session: what it is, where it runs, and when it was last used.
struct SessionRow: View {
    let session: AccountSession
    let isEnabled: Bool
    let onRevoke: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: DeviceStrings.symbol(for: session))
                .frame(width: 20)
                .foregroundStyle(AwradColors.accent)
            VStack(alignment: .leading, spacing: 2) {
                name
                    .font(AwradFonts.title(16))
                    .foregroundStyle(AwradColors.onSurface)
                Text(DeviceStrings.platform(session.platform))
                    .font(AwradFonts.body(14))
                    .foregroundStyle(AwradColors.onSurfaceVariant)
                if session.isCurrent {
                    Text(DeviceStrings.thisDevice)
                        .font(AwradFonts.body(14))
                        .foregroundStyle(AwradColors.accent)
                } else {
                    Text(DeviceStrings.lastUsed(lastUsed))
                        .font(AwradFonts.body(14))
                        .foregroundStyle(AwradColors.onSurfaceVariant)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !session.isCurrent {
                Button(action: onRevoke) {
                    Text(DeviceStrings.revoke)
                        .font(AwradFonts.body(15))
                }
                .tint(AwradColors.error)
                .disabled(!isEnabled)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    /// The server's name as written, or a generic label when it couldn't tell.
    @ViewBuilder private var name: some View {
        if let name = session.name {
            Text(verbatim: Strings.isolated(name))
        } else {
            Text(DeviceStrings.unnamed(session))
        }
    }

    /// "5 minutes ago", in the locale's words and digits like every other number on the screen.
    private var lastUsed: String {
        session.lastSeenAt.formatted(Date.RelativeFormatStyle(presentation: .named, locale: locale))
    }
}

/// The devices screen's strings.
enum DeviceStrings {
    static let title = Strings.text("account.devices.title")
    static let body = Strings.text("account.devices.body")
    static let retry = Strings.text("account.devices.retry")
    static let thisDevice = Strings.text("account.devices.this_device")
    static let revoke = Strings.text("account.devices.revoke")
    static let revokeMessage = Strings.text("account.devices.revoke_confirm.message")
    static let signOutOthers = Strings.text("account.devices.sign_out_others")
    static let signOutOthersTitle = Strings.text("account.devices.sign_out_others_confirm.title")
    static let signOutOthersMessage = Strings.text("account.devices.sign_out_others_confirm.message")
    static let signOutOthersConfirm = Strings.text("account.devices.sign_out_others_confirm.button")

    static func lastUsed(_ relative: String) -> LocalizedStringResource {
        Strings.text("account.devices.last_used \(relative)")
    }

    /// The name is isolated: it may be written in another direction than the sentence.
    static func revokeTitle(_ name: String) -> LocalizedStringResource {
        Strings.text("account.devices.revoke_confirm.title \(Strings.isolated(name))")
    }

    static func name(of session: AccountSession) -> String {
        session.name ?? String(localized: unnamed(session))
    }

    /// The label for a session the server couldn't name: a browser, or a device.
    static func unnamed(_ session: AccountSession) -> LocalizedStringResource {
        session.kind == .browser || session.platform == .web
            ? Strings.text("account.devices.web_browser") : Strings.text("account.devices.unknown_device")
    }

    static func platform(_ platform: AccountSession.Platform) -> LocalizedStringResource {
        switch platform {
        case .android: Strings.text("account.devices.platform.android")
        case .ios: Strings.text("account.devices.platform.ios")
        case .web: Strings.text("account.devices.platform.web")
        case .other: Strings.text("account.devices.platform.other")
        }
    }

    static func symbol(for session: AccountSession) -> String {
        switch (session.kind, session.platform) {
        case (.browser, _), (_, .web): "globe"
        case (_, .ios): "iphone"
        case (_, .android): "candybarphone"
        default: "questionmark.circle"
        }
    }
}

#Preview("Devices") {
    var state = AccountModel.State()
    state.sessions = .loaded(PreviewSessions.all)
    return DevicesView(state: state) { _ in }
}

#Preview("Devices, Arabic") {
    var state = AccountModel.State()
    state.sessions = .loaded(PreviewSessions.all)
    state.feedback = .sessionSignedOut
    return DevicesView(state: state) { _ in }
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Devices, offline") {
    var state = AccountModel.State()
    state.sessions = .unavailable
    state.feedback = .network
    return DevicesView(state: state) { _ in }
}

#Preview("Devices, dark") {
    var state = AccountModel.State()
    state.sessions = .loaded(PreviewSessions.all)
    state.feedback = .sessionSignedOut
    return NavigationStack { DevicesView(state: state) { _ in } }
        .preferredColorScheme(.dark)
}

private enum PreviewSessions {
    static let all = [
        session("iPhone 16 Pro", .device, .ios, minutesAgo: 0, isCurrent: true),
        session("Pixel 9", .device, .android, minutesAgo: 90),
        session("Firefox on Windows", .browser, .web, minutesAgo: 60 * 26),
        session(nil, .browser, .web, minutesAgo: 60 * 24 * 9),
    ]

    static func session(
        _ name: String?, _ kind: AccountSession.Kind, _ platform: AccountSession.Platform, minutesAgo: Double,
        isCurrent: Bool = false
    ) -> AccountSession {
        AccountSession(
            id: .random(), kind: kind, name: name, platform: platform, createdAt: .now.addingTimeInterval(-86_400 * 40),
            lastSeenAt: .now.addingTimeInterval(-60 * minutesAgo), isCurrent: isCurrent)
    }
}
