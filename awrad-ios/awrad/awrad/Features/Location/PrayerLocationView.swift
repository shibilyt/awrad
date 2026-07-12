import SwiftUI

struct PrayerLocationSetupView: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppServices.self) private var services
    var mode: PrayerLocationSetupMode = .inlineSearch
    var onSelect: (() -> Void)?
    @State private var query = ""
    @State private var results: [CitySearchResult] = []
    @State private var isSearching = false
    @State private var isLocating = false
    @State private var isChangingLocation = false
    @State private var message: String?

    private var language: AppLanguage { store.preferences.appLanguage }
    private var hasSelectedLocation: Bool {
        store.preferences.latitude != nil && store.preferences.longitude != nil
    }
    private var shouldShowLocationControls: Bool {
        mode == .inlineSearch || !hasSelectedLocation || isChangingLocation
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if hasSelectedLocation {
                selectedLocation
            }

            if shouldShowLocationControls {
                locationControls
            }

            if let message {
                Text(message)
                    .font(AwradTheme.bodyFont(.footnote))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var selectedLocation: some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.and.ellipse")
                .foregroundStyle(AwradTheme.sage)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.preferences.cityName.isEmpty ? "Prayer location" : store.preferences.cityName)
                    .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                if let latitude = store.preferences.latitude, let longitude = store.preferences.longitude {
                    Text("\(latitude.formatted(.number.precision(.fractionLength(3)))), \(longitude.formatted(.number.precision(.fractionLength(3))))")
                        .font(AwradTheme.bodyFont(.caption))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if mode == .displayWithChange {
                Button(action: startChangingLocation) {
                    Label("Change", systemImage: "pencil")
                }
                .buttonStyle(.borderless)
                .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                .foregroundStyle(AwradTheme.sage)
                .accessibilityIdentifier("prayer-location-change-button")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AwradTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var locationControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                TextField("Search city", text: $query)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.search)
                    .onSubmit(search)
                    .padding(12)
                    .background(AwradTheme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityLabel(Text("Search city"))
                    .accessibilityIdentifier("prayer-location-search-field")

                Button(action: search) {
                    Image(systemName: "magnifyingglass")
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.bordered)
                .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
            }

            Button(action: useCurrentLocation) {
                Label {
                    Text(LocalizedStringKey(isLocating ? "Locating..." : "Use Current Location"))
                } icon: {
                    Image(systemName: "location.fill")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(AwradTheme.sage)
            .disabled(isLocating)

            if isSearching {
                ProgressView("Searching")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !results.isEmpty {
                VStack(spacing: 8) {
                    ForEach(results) { result in
                        Button {
                            apply(result)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(result.name)
                                        .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                                    Text(result.displayName)
                                        .font(AwradTheme.bodyFont(.caption))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "checkmark.circle")
                                    .foregroundStyle(AwradTheme.sage)
                            }
                            .padding(12)
                            .background(AwradTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func startChangingLocation() {
        query = ""
        results = []
        message = nil
        isChangingLocation = true
    }

    private func search() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSearching = true
        message = nil
        Task {
            let found = await services.locations.searchCity(trimmed)
            await MainActor.run {
                results = found
                isSearching = false
                if found.isEmpty {
                    message = AwradLocalizer.localized("No matching cities found.", language: language)
                }
            }
        }
    }

    private func useCurrentLocation() {
        isLocating = true
        message = nil
        Task {
            do {
                let result = try await services.locations.requestCurrentLocation()
                await MainActor.run {
                    apply(result)
                    isLocating = false
                }
            } catch {
                await MainActor.run {
                    message = error.localizedDescription
                    isLocating = false
                }
            }
        }
    }

    private func apply(_ result: CitySearchResult) {
        store.setPrayerLocation(result)
        results = []
        query = result.name
        isChangingLocation = false
        message = AwradLocalizer.format("Prayer times will use %@.", language: language, result.displayName)
        onSelect?()
    }
}

enum PrayerLocationSetupMode {
    case inlineSearch
    case displayWithChange
}
