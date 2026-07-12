import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Shared helpers

enum WirdDisplay {
    static func occasionLabel(_ occasion: WirdOccasion, language: AppLanguage) -> String {
        switch occasion {
        case .anytime:
            return AwradLocalizer.localized("Anytime", language: language)
        case .afterPrayer(let prayer):
            return AwradLocalizer.format("After %@", language: language, AwradLocalizer.localized(prayer.title, language: language))
        case .morning:
            return AwradLocalizer.localized("Morning", language: language)
        case .evening:
            return AwradLocalizer.localized("Evening", language: language)
        case .beforeSleep:
            return AwradLocalizer.localized("Before sleep", language: language)
        case .timeWindow(let start, let end):
            return "\(minuteLabel(start)) – \(minuteLabel(end))"
        }
    }

    static func cadenceLabel(_ cadence: WirdCadence, language: AppLanguage) -> String {
        switch cadence {
        case .everyDay:
            return AwradLocalizer.localized("Every day", language: language)
        case .rotation:
            return AwradLocalizer.localized("Rotating", language: language)
        case .daysOfWeek(let days):
            let names = days.sorted().compactMap { weekdaySymbol($0) }
            return names.isEmpty ? AwradLocalizer.localized("Every day", language: language) : names.joined(separator: ", ")
        case .interval(let n, _):
            return AwradLocalizer.format("Every %d days", language: language, n)
        }
    }

    static func weekdaySymbol(_ weekday: Int) -> String? {
        let symbols = Calendar.current.shortWeekdaySymbols // index 0 = Sunday
        let index = weekday - 1
        guard symbols.indices.contains(index) else { return nil }
        return symbols[index]
    }

    private static func minuteLabel(_ minutes: Int) -> String {
        let hour = (minutes / 60) % 24
        let minute = minutes % 60
        return String(format: "%02d:%02d", hour, minute)
    }
}

// MARK: - List

struct WirdListView: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(AppServices.self) private var services
    private var language: AppLanguage { store.preferences.appLanguage }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if !store.customWirds.isEmpty {
                    Text(LocalizedStringKey("Your wirds"))
                        .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                        .foregroundStyle(.secondary)
                    ForEach(store.customWirds) { wird in
                        wirdButton(wird, isCustom: true)
                    }
                    Text(LocalizedStringKey("Library"))
                        .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                }
                ForEach(store.libraryWirds) { wird in
                    wirdButton(wird, isCustom: false)
                }
            }
            .padding(20)
            .padding(.bottom, 96)
        }
        .background(AwradTheme.background)
        .navigationTitle("Wirds")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.navigate(.createWird, in: store.selectedTab)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(Text(LocalizedStringKey("Create wird")))
            }
        }
    }

    @ViewBuilder
    private func wirdButton(_ wird: Wird, isCustom: Bool) -> some View {
        let todayPart = store.todayPrimaryPart(for: wird)
        let summary = store.progressSummary(for: wird)
        Button {
            router.navigate(.wirdDetail(wird.id), in: store.selectedTab)
        } label: {
            WirdCollectionCard(wird: wird, todayPart: todayPart, summary: summary, language: language)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if isCustom {
                Button {
                    router.navigate(.editWird(wird.id), in: store.selectedTab)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    services.cancelWirdReminders(wirdID: wird.id)
                    store.deleteWird(wird.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

// MARK: - Detail

struct WirdDetailView: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(AppServices.self) private var services
    let wirdID: AwradID
    private var language: AppLanguage { store.preferences.appLanguage }

    var body: some View {
        ScrollView {
            if let wird = store.wird(id: wirdID) {
                let activeParts = store.todayParts(for: wird)
                let todayPart = activeParts.first
                let summary = store.progressSummary(for: wird)
                let streak = store.wirdStreak(for: wird)
                VStack(alignment: .leading, spacing: 18) {
                    WirdDetailHeader(
                        wird: wird,
                        todayPart: todayPart,
                        summary: summary,
                        streak: streak,
                        language: language
                    ) {
                        guard let todayPart else { return }
                        openReader(wird: wird, part: todayPart)
                    }

                    ForEach(wird.parts) { part in
                        let occasionKey = store.occasionKey(for: part, in: wird)
                        let partSummary = store.progressSummary(for: part, wirdID: wird.id, occasionKey: occasionKey)
                        Button {
                            openReader(wird: wird, part: part)
                        } label: {
                            WirdPartRow(
                                wird: wird,
                                part: part,
                                summary: partSummary,
                                isToday: activeParts.contains(where: { $0.id == part.id }),
                                language: language
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                .padding(.bottom, 96)
                .toolbar {
                    if wird.isCustom {
                        ToolbarItem(placement: .topBarTrailing) {
                            Menu {
                                Button {
                                    router.navigate(.editWird(wird.id), in: store.selectedTab)
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    services.cancelWirdReminders(wirdID: wird.id)
                                    store.deleteWird(wird.id)
                                    router.pop(in: store.selectedTab)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                        }
                    }
                }
            } else {
                EmptyStateView(symbol: "book.closed", title: "Wird Missing", message: "This collection is no longer available.")
                    .padding(20)
            }
        }
        .background(AwradTheme.background)
        .navigationTitle("Wird")
    }

    private func openReader(wird: Wird, part: WirdPart) {
        router.navigate(.wirdReader(wirdID: wird.id, partID: part.id), in: store.selectedTab)
    }
}

// MARK: - Reader

/// Full-screen, one-dhikr-per-page cinematic reader. Tap to count; on reaching a
/// segment's target the reader auto-advances to the next segment. Finishing the last
/// segment reveals a completion screen.
struct WirdReaderView: View {
    @Environment(AwradStore.self) private var store
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    let wirdID: AwradID
    let partID: AwradID

    @State private var page = 0
    @State private var finished = false
    @State private var didInit = false

    private var language: AppLanguage { store.preferences.appLanguage }
    private var wird: Wird? { store.wird(id: wirdID) }
    private var part: WirdPart? { wird?.part(id: partID) }
    private var occasionKey: String {
        guard let wird, let part else { return "anytime" }
        return store.occasionKey(for: part, in: wird)
    }

    var body: some View {
        ZStack {
            CinematicBackground().ignoresSafeArea()

            if let wird, let part, !part.segments.isEmpty {
                let summary = store.progressSummary(for: part, wirdID: wird.id, occasionKey: occasionKey)
                let session = store.session(wirdID: wird.id, partID: part.id, occasionKey: occasionKey)

                pager(wird: wird, part: part, session: session)

                VStack {
                    topBar(wird: wird, part: part, summary: summary)
                    Spacer()
                }

                if finished {
                    CinematicCompletionView(
                        wird: wird,
                        streak: store.wirdStreak(for: wird),
                        language: language,
                        onClose: close,
                        onRepeat: { restart(part: part, wird: wird) }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 1.05)))
                }
            } else {
                missing
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden(true)
        .onAppear(perform: setupInitialPage)
    }

    private func pager(wird: Wird, part: WirdPart, session: WirdSession?) -> some View {
        TabView(selection: $page) {
            ForEach(Array(part.segments.enumerated()), id: \.element.id) { index, segment in
                CinematicSegmentPage(
                    segment: segment,
                    part: part,
                    language: language,
                    count: session?.count(for: segment.id) ?? 0,
                    target: AwradStore.effectiveTarget(for: segment, in: part)
                ) {
                    tap(segment: segment, index: index, in: part, wird: wird)
                }
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
        .onChange(of: page) { _, newValue in
            if let segment = part.segments[safe: newValue] {
                store.updateWirdReadingPosition(
                    wirdID: wird.id, partID: part.id, occasionKey: occasionKey, segmentID: segment.id
                )
            }
        }
    }

    private func topBar(wird: Wird, part: WirdPart, summary: WirdProgressSummary) -> some View {
        VStack(spacing: 10) {
            HStack {
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(AwradTheme.bodyFont(.subheadline, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 38, height: 38)
                        .background(.white.opacity(0.12), in: Circle())
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(part.displayTitle(language: language))
                        .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Text("\(min(page + 1, part.segments.count)) / \(part.segments.count)")
                        .font(AwradTheme.bodyFont(.caption2, weight: .semibold))
                        .foregroundStyle(AwradTheme.gold)
                }
                Spacer()
                Color.clear.frame(width: 38, height: 38)
            }
            ProgressView(value: summary.progress)
                .tint(AwradTheme.gold)
                .scaleEffect(x: 1, y: 0.8)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }

    private var missing: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed").font(AwradTheme.bodyFont(.largeTitle)).foregroundStyle(.white.opacity(0.6))
            Text(LocalizedStringKey("This reading is no longer available."))
                .foregroundStyle(.white.opacity(0.8))
            Button(LocalizedStringKey("Close"), action: close)
                .foregroundStyle(AwradTheme.gold)
        }
    }

    // MARK: Interaction

    private func tap(segment: WirdSegment, index: Int, in part: WirdPart, wird: Wird) {
        guard segment.isCountable else {
            advance(from: index, total: part.segments.count)
            return
        }
        let target = AwradStore.effectiveTarget(for: segment, in: part)
        let previous = store.session(wirdID: wird.id, partID: part.id, occasionKey: occasionKey)?.count(for: segment.id) ?? 0
        let newCount = store.incrementSegment(
            wirdID: wird.id, partID: part.id, occasionKey: occasionKey,
            segmentID: segment.id, target: target
        )
        if previous < target && newCount >= target {
            playCompletionHaptic()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                advance(from: index, total: part.segments.count)
            }
        } else {
            playTapHaptic()
        }
    }

    private func advance(from index: Int, total: Int) {
        if index + 1 < total {
            withAnimation(.easeInOut(duration: 0.4)) { page = index + 1 }
        } else {
            withAnimation(.spring(duration: 0.4)) { finished = true }
        }
    }

    private func restart(part: WirdPart, wird: Wird) {
        store.resetSession(wirdID: wird.id, partID: part.id, occasionKey: occasionKey)
        withAnimation { finished = false; page = 0 }
    }

    private func close() {
        router.pop(in: store.selectedTab)
        dismiss()
    }

    private func setupInitialPage() {
        guard !didInit, let wird, let part else { return }
        didInit = true
        let session = store.session(wirdID: wird.id, partID: part.id, occasionKey: occasionKey)
        // Resume at the first not-yet-complete segment.
        if let firstIncomplete = part.segments.firstIndex(where: { segment in
            guard segment.isCountable else { return false }
            let target = AwradStore.effectiveTarget(for: segment, in: part)
            return (session?.count(for: segment.id) ?? 0) < target
        }) {
            page = firstIncomplete
        } else {
            page = max(part.segments.count - 1, 0)
        }
    }

    private func playCompletionHaptic() {
        guard store.preferences.vibrateOnCount else { return }
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    private func playTapHaptic() {
        guard store.preferences.vibrateOnCount else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Cards

private struct WirdCollectionCard: View {
    let wird: Wird
    let todayPart: WirdPart?
    let summary: WirdProgressSummary
    let language: AppLanguage

    var body: some View {
        AwradCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 16) {
                    AwradBundleImage(name: "collection_daily_essentials_light")
                        .scaledToFill()
                        .frame(width: 76, height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(wird.displayName(language: language))
                            .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                            .foregroundStyle(AwradTheme.ink)
                        if !wird.arabicName.isEmpty {
                            Text(wird.arabicName)
                                .font(AwradTheme.arabicFont(22))
                                .foregroundStyle(AwradTheme.sageDark)
                                .lineLimit(1)
                        }
                        Text(wird.displayDescription(language: language))
                            .font(AwradTheme.bodyFont(.caption))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(AwradTheme.bodyFont(.caption, weight: .bold))
                        .foregroundStyle(.secondary)
                }

                if let todayPart {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            StatusPill(title: "Today", symbol: "calendar", tint: AwradTheme.gold)
                            StatusPill(
                                titleText: WirdDisplay.occasionLabel(wird.occasion(for: todayPart), language: language),
                                symbol: "clock",
                                tint: AwradTheme.sage
                            )
                            if summary.isComplete {
                                StatusPill(title: "Complete", symbol: "checkmark.circle.fill", tint: AwradTheme.sage)
                            }
                            Spacer(minLength: 0)
                        }
                        Text(todayPart.displayTitle(language: language))
                            .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                            .foregroundStyle(AwradTheme.ink)
                            .lineLimit(1)
                        AwradProgressBar(value: summary.progress, height: 7)
                        Text(AwradLocalizer.readingProgress(
                            completed: summary.completedItems,
                            total: summary.totalItems,
                            language: language
                        ))
                        .font(AwradTheme.bodyFont(.caption))
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct WirdDetailHeader: View {
    let wird: Wird
    let todayPart: WirdPart?
    let summary: WirdProgressSummary
    let streak: Int
    let language: AppLanguage
    let startAction: () -> Void

    var body: some View {
        AwradCard {
            VStack(alignment: .leading, spacing: 14) {
                if !wird.arabicName.isEmpty {
                    Text(wird.arabicName)
                        .font(AwradTheme.arabicFont(32))
                        .foregroundStyle(AwradTheme.sageDark)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .environment(\.layoutDirection, .rightToLeft)
                }
                Text(wird.displayName(language: language))
                    .font(AwradTheme.displayFont(26))
                Text(wird.displayDescription(language: language))
                    .font(AwradTheme.bodyFont(.subheadline))
                    .foregroundStyle(.secondary)
                if let source = wird.sourceAttribution, !source.isEmpty {
                    Text(source)
                        .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                        .foregroundStyle(AwradTheme.gold)
                } else if !wird.author.isEmpty {
                    Text(wird.author)
                        .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                        .foregroundStyle(AwradTheme.gold)
                }
                HStack(spacing: 12) {
                    Label {
                        Text(AwradLocalizer.wirdStreak(streak, language: language))
                    } icon: {
                        Image(systemName: "flame.fill")
                    }
                    .foregroundStyle(AwradTheme.sage)
                    Label {
                        Text(WirdDisplay.cadenceLabel(wird.schedule.cadence, language: language))
                    } icon: {
                        Image(systemName: "calendar")
                    }
                    .foregroundStyle(.secondary)
                }
                .font(AwradTheme.bodyFont(.caption, weight: .semibold))

                if let todayPart {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(LocalizedStringKey("Today's section"))
                                    .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Text(todayPart.displayTitle(language: language))
                                    .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                                    .foregroundStyle(AwradTheme.ink)
                            }
                            Spacer()
                            if summary.isComplete {
                                StatusPill(title: "Complete", symbol: "checkmark.circle.fill", tint: AwradTheme.sage)
                            }
                        }
                        AwradProgressBar(value: summary.progress, height: 9)
                        Text(AwradLocalizer.readingProgress(
                            completed: summary.completedItems,
                            total: summary.totalItems,
                            language: language
                        ))
                        .font(AwradTheme.bodyFont(.caption))
                        .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)

                    Button(action: startAction) {
                        Label("Start Reading", systemImage: "book.pages.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .awradPrimaryButton()
                }
            }
        }
    }
}

private struct WirdPartRow: View {
    let wird: Wird
    let part: WirdPart
    let summary: WirdProgressSummary
    let isToday: Bool
    let language: AppLanguage

    var body: some View {
        AwradCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(part.displayTitle(language: language))
                            .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                            .foregroundStyle(AwradTheme.ink)
                        Text(part.displaySubtitle(language: language)
                             ?? WirdDisplay.occasionLabel(wird.occasion(for: part), language: language))
                            .font(AwradTheme.bodyFont(.caption))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        if isToday {
                            StatusPill(title: "Today", symbol: "calendar", tint: AwradTheme.gold)
                        }
                        if summary.isComplete {
                            StatusPill(title: "Complete", symbol: "checkmark.circle.fill", tint: AwradTheme.sage)
                        }
                    }
                    Image(systemName: "chevron.right")
                        .font(AwradTheme.bodyFont(.caption, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }

                if summary.totalItems > 0 {
                    AwradProgressBar(value: summary.progress, height: 7)
                    Text(AwradLocalizer.readingProgress(
                        completed: summary.completedItems,
                        total: summary.totalItems,
                        language: language
                    ))
                    .font(AwradTheme.bodyFont(.caption))
                    .foregroundStyle(.secondary)
                }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isToday ? AwradTheme.gold.opacity(0.65) : .clear, lineWidth: 1.5)
        }
    }
}

// MARK: - Cinematic reader components

/// Fixed immersive background (theme-independent so the reader always feels cinematic).
private struct CinematicBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.11, blue: 0.07),
                    Color(red: 0.02, green: 0.05, blue: 0.035),
                    Color(red: 0.01, green: 0.02, blue: 0.015)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [AwradTheme.sage.opacity(0.28), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 460
            )
        }
    }
}

/// One segment, full-screen. Tapping the count ring (or anywhere in the lower half)
/// increments the count.
private struct CinematicSegmentPage: View {
    let segment: WirdSegment
    let part: WirdPart
    let language: AppLanguage
    let count: Int
    let target: Int
    let onTap: () -> Void

    private let cream = Color(red: 0.97, green: 0.96, blue: 0.91)

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 72)
            ScrollView(.vertical, showsIndicators: false) {
                content
                    .padding(.horizontal, 26)
                    .frame(maxWidth: .infinity)
            }
            Spacer(minLength: 8)
            if segment.isCountable {
                CountControl(count: min(count, target), target: target, range: segment.repeatSpec.isRange ? segment.repeatSpec.displayText() : nil, action: onTap)
                    .padding(.bottom, 54)
            } else {
                continueButton
                    .padding(.bottom, 54)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch segment.kind {
        case .heading:
            Text(segment.headingText(language: language) ?? "")
                .font(AwradTheme.displayFont(30))
                .foregroundStyle(AwradTheme.gold)
                .multilineTextAlignment(.center)
        case .instruction:
            VStack(spacing: 14) {
                Image(systemName: "info.circle").font(AwradTheme.bodyFont(.title2)).foregroundStyle(AwradTheme.gold)
                Text(segment.headingText(language: language) ?? "")
                    .font(AwradTheme.bodyFont(.title3))
                    .foregroundStyle(cream.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
        default:
            VStack(spacing: 22) {
                if let quran = segment.quranRef {
                    pill(quran.displayText())
                } else if segment.hasAudio {
                    Image(systemName: "speaker.wave.2.fill").font(AwradTheme.bodyFont(.footnote)).foregroundStyle(AwradTheme.gold)
                }
                if !segment.arabic.isEmpty {
                    Text(segment.arabic)
                        .font(AwradTheme.arabicFont(36))
                        .foregroundStyle(cream)
                        .multilineTextAlignment(.center)
                        .lineSpacing(14)
                        .environment(\.layoutDirection, .rightToLeft)
                        .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
                }
                if let transliteration = segment.transliterationText(language: language) {
                    Text(transliteration)
                        .font(AwradTheme.bodyFont(.title3, weight: .medium))
                        .foregroundStyle(AwradTheme.gold.opacity(0.95))
                        .multilineTextAlignment(.center)
                }
                if let translation = segment.translationText(language: language) {
                    Text(translation)
                        .font(AwradTheme.bodyFont(.body))
                        .foregroundStyle(cream.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                if let fadl = segment.fadlText(language: language) {
                    Text(fadl)
                        .font(AwradTheme.bodyFont(.footnote))
                        .italic()
                        .foregroundStyle(cream.opacity(0.55))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.vertical, 12)
        }
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(AwradTheme.bodyFont(.caption, weight: .semibold))
            .foregroundStyle(AwradTheme.gold)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(AwradTheme.gold.opacity(0.15), in: Capsule())
    }

    private var continueButton: some View {
        Button(action: onTap) {
            Label {
                Text(LocalizedStringKey("Continue"))
            } icon: {
                Image(systemName: "arrow.right")
            }
            .font(AwradTheme.bodyFont(.headline, weight: .semibold))
            .foregroundStyle(Color(red: 0.05, green: 0.11, blue: 0.07))
            .padding(.horizontal, 30)
            .padding(.vertical, 14)
            .background(AwradTheme.gold, in: Capsule())
        }
    }
}

/// Count progress readout sitting on top of a large Count button.
private struct CountControl: View {
    let count: Int
    let target: Int
    let range: String?
    let action: () -> Void

    private var progress: Double { target > 0 ? Double(count) / Double(target) : 0 }
    private var isDone: Bool { count >= target }
    /// A single-recitation item: the tap is a completion gesture, not a tally.
    private var isSingle: Bool { target <= 1 }

    private var buttonTitle: LocalizedStringKey {
        if isDone { return "Recited" }
        return isSingle ? "Mark as recited" : "Recite"
    }

    var body: some View {
        VStack(spacing: 18) {
            // Counter only makes sense for repeated items.
            if !isSingle {
                VStack(spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(count)")
                            .font(AwradTheme.bodyFont(44, weight: .bold))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                            .animation(.snappy(duration: 0.2), value: count)
                        Text("/ \(range ?? "\(target)")")
                            .font(AwradTheme.bodyFont(.title3, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Capsule()
                        .fill(.white.opacity(0.12))
                        .frame(width: 200, height: 6)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(AwradTheme.gold)
                                .frame(width: 200 * progress, height: 6)
                                .animation(.snappy(duration: 0.25), value: progress)
                        }
                }
            }

            // The recite button.
            Button(action: action) {
                Group {
                    if isDone {
                        Label { Text(buttonTitle) } icon: { Image(systemName: "checkmark") }
                    } else {
                        Text(buttonTitle)
                    }
                }
                .font(AwradTheme.bodyFont(.headline, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(isDone ? AwradTheme.gold : Color(red: 0.05, green: 0.11, blue: 0.07))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    Capsule().fill(isDone ? Color.white.opacity(0.12) : AwradTheme.gold)
                )
                .overlay(
                    Capsule().stroke(AwradTheme.gold.opacity(isDone ? 0.6 : 0), lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(buttonTitle)
        .accessibilityValue(isSingle ? Text("") : Text("\(count) of \(target)"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default, action)
    }
}

/// Shown after the final segment is completed.
private struct CinematicCompletionView: View {
    let wird: Wird
    let streak: Int
    let language: AppLanguage
    let onClose: () -> Void
    let onRepeat: () -> Void

    var body: some View {
        ZStack {
            CinematicBackground().ignoresSafeArea()
            VStack(spacing: 22) {
                Image(systemName: "checkmark.seal.fill")
                    .font(AwradTheme.bodyFont(72, weight: .semibold))
                    .foregroundStyle(AwradTheme.gold)
                    .shadow(color: AwradTheme.gold.opacity(0.5), radius: 20)
                Text(LocalizedStringKey("Section Complete"))
                    .font(AwradTheme.bodyFont(.title, weight: .bold))
                    .foregroundStyle(.white)
                Text(wird.displayName(language: language))
                    .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                if streak > 0 {
                    Label {
                        Text(AwradLocalizer.wirdStreak(streak, language: language))
                    } icon: {
                        Image(systemName: "flame.fill")
                    }
                    .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                    .foregroundStyle(AwradTheme.gold)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.08), in: Capsule())
                }
                VStack(spacing: 12) {
                    Button(action: onClose) {
                        Text(LocalizedStringKey("Done"))
                            .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                            .foregroundStyle(Color(red: 0.05, green: 0.11, blue: 0.07))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(AwradTheme.gold, in: Capsule())
                    }
                    Button(action: onRepeat) {
                        Label {
                            Text(LocalizedStringKey("Read again"))
                        } icon: {
                            Image(systemName: "arrow.counterclockwise")
                        }
                        .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal, 40)
            }
            .padding(30)
        }
    }
}

private struct StatusPill: View {
    let titleKey: String?
    let titleText: String?
    let symbol: String
    let tint: Color

    init(title: String, symbol: String, tint: Color) {
        self.titleKey = title
        self.titleText = nil
        self.symbol = symbol
        self.tint = tint
    }

    init(titleText: String, symbol: String, tint: Color) {
        self.titleKey = nil
        self.titleText = titleText
        self.symbol = symbol
        self.tint = tint
    }

    var body: some View {
        Label {
            if let titleKey {
                Text(LocalizedStringKey(titleKey))
            } else {
                Text(titleText ?? "")
            }
        } icon: {
            Image(systemName: symbol)
        }
        .font(AwradTheme.bodyFont(.caption2, weight: .semibold))
        .lineLimit(1)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .foregroundStyle(tint)
        .background(tint.opacity(0.14), in: Capsule())
    }
}
