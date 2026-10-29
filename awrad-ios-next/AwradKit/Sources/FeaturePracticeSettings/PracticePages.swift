import AwradDesignSystem
import AwradDomain
import SwiftUI

/// Choosing where the device is: one reading of its position, or a city from the bundled list
/// (offline), then the platform's own places under their own heading when online.
struct LocationPage: View {
    let state: PracticeSettingsModel.State
    let send: (PracticeSettingsModel.Action) -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        PracticePage(title: Strings.location) {
            Note(Strings.locationNote)
            VStack(alignment: .leading, spacing: AwradSpacing.sm) {
                AwradButton(Strings.useMyLocation, variant: .secondary, isLoading: state.isLocating) {
                    send(.useMyLocation)
                }
                .disabled(state.isLocating)
                if let error = state.locationError {
                    Hint(
                        error == .denied ? Strings.locationDenied : Strings.locationUnavailable, tint: AwradColors.error
                    )
                    .awradExpandingContent()
                }
            }
            .awradExpand(value: state.locationError)
            if state.location != nil {
                AwradButton(Strings.removeLocation, variant: .text, role: .destructive) { send(.removeLocation) }
            }
            VStack(alignment: .leading, spacing: AwradSpacing.sm) {
                Text(Strings.searchLabel)
                    .awradTextStyle(.label)
                    .foregroundStyle(AwradColors.onSurface)
                    .accessibilityHidden(true)
                CitySearchField(query: state.query) { send(.queryChanged($0)) }
            }
            results
            if let attribution = state.attribution {
                // The city list's licence (CC BY 4.0) asks for this line wherever it's used.
                Text(verbatim: attribution)
                    .awradTextStyle(.caption)
                    .foregroundStyle(AwradColors.onSurfaceVariant)
            }
        }
    }

    @ViewBuilder private var results: some View {
        if !CitySearchKey.key(state.query).isEmpty {
            VStack(alignment: .leading, spacing: AwradSpacing.rowGap) {
                SectionHeading(Strings.cities)
                if state.cities.isEmpty {
                    Note(Strings.noCities)
                }
                ForEach(state.cities) { city in
                    PlaceRow(name: city.name, detail: detail(region: city.region, country: countryName(city.country))) {
                        send(.chooseCity(city))
                    }
                }
            }
        }
        if !state.places.isEmpty {
            VStack(alignment: .leading, spacing: AwradSpacing.rowGap) {
                SectionHeading(Strings.morePlaces)
                ForEach(state.places) { place in
                    PlaceRow(name: place.name, detail: detail(region: place.region, country: place.country)) {
                        send(.choosePlace(place))
                    }
                }
            }
        }
    }

    /// The country's name in the app language, from the platform's locale data.
    private func countryName(_ code: String) -> String {
        locale.localizedString(forRegionCode: code) ?? code
    }

    private func detail(region: String?, country: String?) -> Text? {
        switch (region, country) {
        case (let region?, let country?): Text(Strings.placeDetail(region: region, country: country))
        case (let only?, nil), (nil, let only?): Text(verbatim: Strings.isolated(only))
        case (nil, nil): nil
        }
    }
}

/// The search field: the `search` icon, the text, and a clear button while there's text.
private struct CitySearchField: View {
    let query: String
    let onChange: (String) -> Void

    var body: some View {
        HStack(spacing: AwradSpacing.sm) {
            AwradIconImage(.search, size: AwradSize.iconSmall)
                .foregroundStyle(AwradColors.onSurfaceVariant)
            TextField(
                text: Binding(get: { query }, set: { onChange($0) }),
                prompt: Text(Strings.searchPrompt).foregroundStyle(AwradColors.onSurfaceVariant)
            ) { Text(Strings.searchLabel) }
            .submitLabel(.search)
            .autocorrectionDisabled()
            #if os(iOS)
                .textInputAutocapitalization(.words)
            #endif
            if !query.isEmpty {
                Button {
                    onChange("")
                } label: {
                    AwradIconImage(.close, size: AwradSize.iconSmall)
                        .foregroundStyle(AwradColors.onSurfaceVariant)
                        .frame(width: AwradSize.touchTarget, height: AwradSize.touchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.awradPress(.button))
                .accessibilityLabel(Text(Strings.clearSearch))
            }
        }
        .awradField()
    }
}

/// The ten calculation methods, by adhan's names in the frozen apps' order.
struct MethodPage: View {
    let state: PracticeSettingsModel.State
    let send: (PracticeSettingsModel.Action) -> Void

    var body: some View {
        PracticePage(title: Strings.method) {
            Note(Strings.methodNote)
            VStack(spacing: AwradSpacing.rowGap) {
                ForEach(CalculationMethod.allCases, id: \.self) { method in
                    AwradOptionRow(Strings.methodName(method), isSelected: state.policy.calculationMethod == method) {
                        send(.methodChanged(method))
                    }
                }
            }
        }
    }
}

/// Today's Hijri date, "Adjust this month" (and next month near the end of one), and the earlier
/// corrections with Remove. Only the offsets the rules allow are offered.
struct HijriPage: View {
    let state: PracticeSettingsModel.State
    let send: (PracticeSettingsModel.Action) -> Void

    var body: some View {
        PracticePage(title: Strings.hijri) {
            Text(state.today?.hijri.map(Strings.hijriDate) ?? Strings.outsideCalendar)
                .awradTextStyle(.cardTitle)
                .foregroundStyle(AwradColors.onSurface)
            Note(Strings.hijriNote)
            if let month = state.thisMonth {
                MonthSection(title: Strings.adjustThisMonth, adjustment: month, send: send)
            }
            if let month = state.nextMonth {
                MonthSection(title: Strings.adjustNextMonth, adjustment: month, send: send)
            }
            if !state.earlierCorrections.isEmpty {
                VStack(alignment: .leading, spacing: AwradSpacing.rowGap) {
                    SectionHeading(Strings.earlierCorrections)
                    ForEach(state.earlierCorrections) { listed in
                        CorrectionRow(listed: listed) {
                            send(.removeCorrection(year: listed.correction.year, month: listed.correction.month))
                        }
                    }
                }
            }
        }
    }
}

private struct MonthSection: View {
    let title: LocalizedStringResource
    let adjustment: MonthAdjustment
    let send: (PracticeSettingsModel.Action) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AwradSpacing.rowGap) {
            VStack(alignment: .leading, spacing: AwradSpacing.xxs) {
                SectionHeading(title)
                Text(Strings.hijriMonth(year: adjustment.year, month: adjustment.month))
                    .awradTextStyle(.bodySmall)
                    .foregroundStyle(AwradColors.onSurfaceVariant)
            }
            ForEach(adjustment.offsets, id: \.self) { offset in
                AwradOptionRow(Strings.offset(offset), isSelected: adjustment.selected == offset) {
                    send(.adjustMonth(year: adjustment.year, month: adjustment.month, offset: offset))
                }
            }
        }
    }
}

private struct CorrectionRow: View {
    let listed: ListedCorrection
    let onRemove: () -> Void

    var body: some View {
        AwradCard(AwradRadius.tile) {
            VStack(alignment: .leading, spacing: AwradSpacing.sm) {
                HStack(spacing: AwradSpacing.lg) {
                    VStack(alignment: .leading, spacing: AwradSpacing.xxs) {
                        Text(Strings.hijriMonth(year: listed.correction.year, month: listed.correction.month))
                            .awradTextStyle(.rowTitle)
                            .foregroundStyle(AwradColors.onSurface)
                        Text(Strings.offset(listed.correction.offsetDays))
                            .awradTextStyle(.bodySmall)
                            .foregroundStyle(AwradColors.onSurfaceVariant)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                    AwradButton(Strings.remove, variant: .text, layout: .row, role: .destructive, action: onRemove)
                        .disabled(!listed.canRemove)
                }
                if !listed.canRemove {
                    Note(Strings.removeBlocked)
                }
            }
        }
    }
}
