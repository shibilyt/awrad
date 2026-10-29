import AwradDesignSystem
import AwradDomain
import SwiftUI

/// Stateful entry point: owns the model. It's pushed inside the caller's `NavigationStack` (the
/// account sheet), so its own pages push with `navigationDestination(isPresented:)`.
public struct PracticeSettingsRoute: View {
    @State private var model: PracticeSettingsModel

    public init(services: PracticeSettingsServices) {
        _model = State(initialValue: PracticeSettingsModel(services: services))
    }

    public var body: some View {
        PracticeSettingsScreen(state: model.state) { action in
            // Typing and navigation apply synchronously; saving and searching run in a task.
            if !model.apply(action) { Task { await model.send(action) } }
        }
        .task { await model.send(.appeared) }
        .task { await model.observeSettings() }
    }
}

/// Stateless: the settings and the today preview, and the pages they open.
struct PracticeSettingsScreen: View {
    let state: PracticeSettingsModel.State
    let send: (PracticeSettingsModel.Action) -> Void

    var body: some View {
        PracticePage(title: Strings.title) {
            TodayCard(today: state.today, hasLocation: state.location != nil)
            DayResetSection(state: state, send: send)
            ValueRow(title: Strings.location, value: locationName) { send(.open(.location)) }
            ValueRow(title: Strings.method, value: Text(Strings.methodName(state.policy.calculationMethod))) {
                send(.open(.method))
            }
            PillsSection(
                title: Strings.madhab, note: Strings.madhabNote,
                selection: Binding(get: { state.policy.madhab }, set: { send(.madhabChanged($0)) }),
                options: [.init(.shafi, title: Strings.madhabStandard), .init(.hanafi, title: Strings.madhabHanafi)])
            PillsSection(
                title: Strings.weekStart, note: nil,
                selection: Binding(get: { state.policy.weekStart }, set: { send(.weekStartChanged($0)) }),
                options: WeekStart.allCases.map { .init($0, title: Strings.weekday($0)) })
            ValueRow(
                title: Strings.hijri, value: Text(state.today?.hijri.map(Strings.hijriDate) ?? Strings.outsideCalendar)
            ) {
                send(.open(.hijri))
            }
        }
        .navigationDestination(isPresented: isShowing(.location)) { LocationPage(state: state, send: send) }
        .navigationDestination(isPresented: isShowing(.method)) { MethodPage(state: state, send: send) }
        .navigationDestination(isPresented: isShowing(.hijri)) { HijriPage(state: state, send: send) }
        .awradDialog(
            isPresented: Binding(get: { state.saveFailed }, set: { if !$0 { send(.dismissSaveFailed) } }),
            title: Strings.saveFailed
        ) {
            AwradButton(Strings.ok, variant: .text, layout: .row) { send(.dismissSaveFailed) }
        }
        // A sync merge kept the other device's Hijri corrections (`hijri_corrections_replaced`).
        .awradDialog(
            isPresented: Binding(
                get: { state.correctionsReplaced }, set: { if !$0 { send(.dismissCorrectionsReplaced) } }),
            title: Strings.correctionsReplacedTitle, message: Strings.correctionsReplacedBody
        ) {
            AwradButton(Strings.ok, variant: .text, layout: .row) { send(.dismissCorrectionsReplaced) }
        }
    }

    /// The chosen place's name as written (from data), "My location" for GPS, or "Not set".
    private var locationName: Text {
        guard let location = state.location else { return Text(Strings.locationNotSet) }
        guard let name = location.name else { return Text(Strings.currentLocation) }
        return Text(verbatim: Strings.isolated(name))
    }

    private func isShowing(_ page: PracticeSettingsModel.Page) -> Binding<Bool> {
        Binding(get: { state.page == page }, set: { if !$0, state.page == page { send(.pageChanged(nil)) } })
    }
}

/// When the day resets, with the hint when Maghrib can't be used now.
private struct DayResetSection: View {
    let state: PracticeSettingsModel.State
    let send: (PracticeSettingsModel.Action) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AwradSpacing.sm) {
            PillsSection(
                title: Strings.dayReset, note: Strings.dayResetNote,
                selection: Binding(get: { state.policy.dayReset }, set: { send(.dayResetChanged($0)) }),
                options: [.init(.midnight, title: Strings.midnight), .init(.maghrib, title: Strings.maghrib)])
            if let fallback = state.maghribFallback {
                Hint(fallback == .noLocation ? Strings.maghribWithoutLocation : Strings.maghribWithoutSunset)
                    .awradExpandingContent()
            }
        }
        .awradExpand(value: state.maghribFallback)
    }
}

/// Today's Hijri date and Maghrib.
private struct TodayCard: View {
    let today: PracticeToday?
    let hasLocation: Bool

    var body: some View {
        AwradCard {
            VStack(alignment: .leading, spacing: AwradSpacing.sm) {
                Text(Strings.today)
                    .awradTextStyle(.label)
                    .foregroundStyle(AwradColors.onSurfaceVariant)
                Text(today?.hijri.map(Strings.hijriDate) ?? Strings.outsideCalendar)
                    .awradTextStyle(.cardTitle)
                    .foregroundStyle(AwradColors.onSurface)
                if let maghrib = today?.maghrib {
                    HStack(spacing: AwradSpacing.inlineGap) {
                        Text(Strings.maghribLabel)
                        Text(maghrib, format: .dateTime.hour().minute())
                    }
                    .awradTextStyle(.body)
                    .foregroundStyle(AwradColors.onSurface)
                    .accessibilityElement(children: .combine)
                } else {
                    Text(hasLocation ? Strings.maghribNone : Strings.maghribNeedsLocation)
                        .awradTextStyle(.body)
                        .foregroundStyle(AwradColors.onSurfaceVariant)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
