import Foundation
import AppIntents
import SwiftUI
import WidgetKit
#if canImport(ActivityKit)
import ActivityKit
#endif

@main
struct AwradWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayFocusWidget()
        DailyWirdWidget()
        #if canImport(ActivityKit)
        if #available(iOS 16.1, *) {
            CountingLiveActivity()
        }
        #endif
    }
}

#if canImport(ActivityKit)
@available(iOS 16.1, *)
struct CountingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AwradCountingActivityAttributes.self) { context in
            // Lock Screen / banner presentation.
            HStack(spacing: 12) {
                Image(systemName: context.state.isPlaying ? "waveform" : "hands.sparkles.fill")
                    .font(.title3)
                    .foregroundStyle(AwradWidgetPalette.gold)
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.attributes.dhikrTitle)
                        .font(.headline)
                        .foregroundStyle(AwradWidgetPalette.ink)
                        .lineLimit(1)
                    ProgressView(value: context.state.progress)
                        .tint(AwradWidgetPalette.sage)
                    Text(Self.countText(context.state))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(AwradWidgetPalette.ink.opacity(0.7))
                }
            }
            .padding()
            .activityBackgroundTint(AwradWidgetPalette.background)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.isPlaying ? "waveform" : "hands.sparkles.fill")
                        .foregroundStyle(AwradWidgetPalette.gold)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(Self.countText(context.state))
                        .font(.caption.monospacedDigit().weight(.semibold))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.attributes.dhikrTitle)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        ProgressView(value: context.state.progress)
                            .tint(AwradWidgetPalette.sage)
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isPlaying ? "waveform" : "hands.sparkles.fill")
                    .foregroundStyle(AwradWidgetPalette.gold)
            } compactTrailing: {
                Text("\(context.state.currentCount)")
                    .font(.caption2.monospacedDigit())
            } minimal: {
                Image(systemName: "hands.sparkles.fill")
                    .foregroundStyle(AwradWidgetPalette.gold)
            }
        }
    }

    private static func countText(_ state: AwradCountingActivityAttributes.ContentState) -> String {
        state.targetCount > 0 ? "\(state.currentCount) / \(state.targetCount)" : "\(state.currentCount)"
    }
}
#endif

private enum AwradWidgetPalette {
    static let background = Color(red: 0.95, green: 0.97, blue: 0.93)
    static let ink = Color(red: 0.13, green: 0.20, blue: 0.16)
    static let sage = Color(red: 0.32, green: 0.49, blue: 0.39)
    static let mint = Color(red: 0.77, green: 0.88, blue: 0.76)
    static let gold = Color(red: 0.76, green: 0.58, blue: 0.25)
}

private enum AwradWidgetSharedConfiguration {
    static let appGroupID = "group.app.awrad.awrad"
    static let snapshotKey = "AwradWidgetSnapshot"
}

private enum AwradWidgetSnapshotStore {
    static func load() -> AwradWidgetMutationSnapshot {
        guard let defaults = UserDefaults(suiteName: AwradWidgetSharedConfiguration.appGroupID),
              let data = defaults.data(forKey: AwradWidgetSharedConfiguration.snapshotKey),
              let snapshot = try? JSONDecoder().decode(AwradWidgetMutationSnapshot.self, from: data) else {
            return .fallback
        }
        if let projection = try? SharedAwradWidgetProjection.load(from: defaults) {
            return snapshot.merging(projection)
        }
        return snapshot
    }
}

struct IncrementTodayAwradWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "Count Today's Awrad"
    static var description = IntentDescription("Add one count to the current Awrad focus goal.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let defaults = UserDefaults(suiteName: AwradWidgetSharedConfiguration.appGroupID) else {
            return .result()
        }
        var result = try SharedAwradWidgetMutationCoordinator.incrementFocusCount(
            appGroupID: AwradWidgetSharedConfiguration.appGroupID,
            displaySnapshotKey: AwradWidgetSharedConfiguration.snapshotKey,
            defaults: defaults
        )
        if case .requiresConfirmation(let status) = result {
            try await requestConfirmation(
                actionName: .add,
                dialog: confirmationDialog(for: status)
            )
            // Re-open and re-check the live aggregate after the user confirms;
            // no state captured before the prompt is trusted for the write.
            result = try SharedAwradWidgetMutationCoordinator.incrementFocusCount(
                appGroupID: AwradWidgetSharedConfiguration.appGroupID,
                displaySnapshotKey: AwradWidgetSharedConfiguration.snapshotKey,
                defaults: defaults,
                outsideSlotConfirmed: true
            )
        }
        if result.shouldReloadWidget {
            WidgetCenter.shared.reloadAllTimelines()
        }
        return .result()
    }

    private func confirmationDialog(for status: SharedAwradSlotTimeStatus) -> IntentDialog {
        switch status {
        case .upcoming:
            IntentDialog(LocalizedStringResource(
                "widget_count_before_slot_confirmation",
                defaultValue: "This slot has not started yet. Add one count anyway?"
            ))
        case .ended:
            IntentDialog(LocalizedStringResource(
                "widget_count_after_slot_confirmation",
                defaultValue: "This slot has ended. Add one count anyway?"
            ))
        case .active, .anytime, .unknown:
            IntentDialog(LocalizedStringResource(
                "widget_count_outside_slot_confirmation",
                defaultValue: "Add one count outside the selected slot time?"
            ))
        }
    }
}

private struct AwradWidgetEntry: TimelineEntry {
    let date: Date
    let title: String
    let subtitle: String
    let detail: String
    let symbol: String
    let progress: Double
    let deepLink: URL?
    let canIncrement: Bool

    static func focus(from snapshot: AwradWidgetMutationSnapshot, date: Date = Date()) -> AwradWidgetEntry {
        AwradWidgetEntry(
            date: date,
            title: snapshot.focusTitle,
            subtitle: snapshot.focusSubtitle,
            detail: snapshot.focusDetail,
            symbol: snapshot.focusSymbol,
            progress: snapshot.focusProgress.clamped01,
            deepLink: snapshot.focusDeepLink.flatMap(URL.init(string:)),
            canIncrement: snapshot.focusCanIncrement
        )
    }

    static func wird(from snapshot: AwradWidgetMutationSnapshot, date: Date = Date()) -> AwradWidgetEntry {
        AwradWidgetEntry(
            date: date,
            title: snapshot.wirdTitle,
            subtitle: snapshot.wirdSubtitle,
            detail: snapshot.wirdDetail,
            symbol: "book.closed.fill",
            progress: snapshot.wirdProgress.clamped01,
            deepLink: snapshot.wirdDeepLink.flatMap(URL.init(string:)),
            canIncrement: false
        )
    }
}

private struct TodayFocusProvider: TimelineProvider {
    func placeholder(in context: Context) -> AwradWidgetEntry {
        AwradWidgetEntry.focus(from: .fallback)
    }

    func getSnapshot(in context: Context, completion: @escaping (AwradWidgetEntry) -> Void) {
        completion(AwradWidgetEntry.focus(from: AwradWidgetSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AwradWidgetEntry>) -> Void) {
        let now = Date()
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: now) ?? now.addingTimeInterval(3600)
        let entry = AwradWidgetEntry.focus(from: AwradWidgetSnapshotStore.load(), date: now)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

private struct WirdProvider: TimelineProvider {
    func placeholder(in context: Context) -> AwradWidgetEntry {
        AwradWidgetEntry.wird(from: .fallback)
    }

    func getSnapshot(in context: Context, completion: @escaping (AwradWidgetEntry) -> Void) {
        completion(AwradWidgetEntry.wird(from: AwradWidgetSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AwradWidgetEntry>) -> Void) {
        let now = Date()
        let nextRefresh = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now)
        let entry = AwradWidgetEntry.wird(from: AwradWidgetSnapshotStore.load(), date: now)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct TodayFocusWidget: Widget {
    private let kind = "TodayFocusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayFocusProvider()) { entry in
            AwradWidgetView(entry: entry, style: .goal)
        }
        .configurationDisplayName("Today's Awrad")
        .description("See your Awrad focus and open the app to keep counting.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

struct DailyWirdWidget: Widget {
    private let kind = "DailyWirdWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WirdProvider()) { entry in
            AwradWidgetView(entry: entry, style: .wird)
        }
        .configurationDisplayName("Daily Wird")
        .description("Open today's wird reading from your Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

private enum AwradWidgetStyle {
    case goal
    case wird

    var tint: Color {
        switch self {
        case .goal: AwradWidgetPalette.sage
        case .wird: AwradWidgetPalette.gold
        }
    }

    var fallbackDeepLink: URL? {
        switch self {
        case .goal: URL(string: "awrad://home")
        case .wird: URL(string: "awrad://wirds")
        }
    }
}

private struct AwradWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: AwradWidgetEntry
    private let style: AwradWidgetStyle

    init(entry: AwradWidgetEntry, style: AwradWidgetStyle) {
        self.entry = entry
        self.style = style
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                AccessoryWidgetContent(entry: entry, tint: style.tint)
            case .systemMedium:
                MediumWidgetContent(entry: entry, tint: style.tint)
            default:
                SmallWidgetContent(entry: entry, tint: style.tint)
            }
        }
        .widgetURL(entry.deepLink ?? style.fallbackDeepLink)
    }
}

private struct SmallWidgetContent: View {
    let entry: AwradWidgetEntry
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: entry.symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(AwradWidgetPalette.mint.opacity(0.45), in: Circle())

            Spacer(minLength: 0)

            Text(entry.title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AwradWidgetPalette.ink)
                .lineLimit(2)

            HStack(spacing: 10) {
                ProgressStrip(progress: entry.progress, tint: tint)

                if entry.canIncrement {
                    WidgetIncrementButton(tint: tint, compact: true)
                }
            }
        }
        .widgetSurface()
    }
}

private struct MediumWidgetContent: View {
    let entry: AwradWidgetEntry
    let tint: Color

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .stroke(tint.opacity(0.2), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: entry.progress)
                    .stroke(tint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: entry.symbol)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 74, height: 74)

            VStack(alignment: .leading, spacing: 7) {
                Text(entry.subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .textCase(.uppercase)

                Text(entry.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AwradWidgetPalette.ink)
                    .lineLimit(1)

                Text(entry.detail)
                    .font(.subheadline)
                    .foregroundStyle(AwradWidgetPalette.ink.opacity(0.68))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            if entry.canIncrement {
                WidgetIncrementButton(tint: tint, compact: false)
            }
        }
        .widgetSurface()
    }
}

private struct WidgetIncrementButton: View {
    let tint: Color
    let compact: Bool

    var body: some View {
        Button(intent: IncrementTodayAwradWidgetIntent()) {
            if compact {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 30, height: 30)
            } else {
                Label("Count", systemImage: "plus")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .frame(height: 32)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(tint, in: Capsule())
        .accessibilityLabel("Add one count")
    }
}

private struct AccessoryWidgetContent: View {
    let entry: AwradWidgetEntry
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.symbol)
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.title)
                    .font(.caption.weight(.semibold))
                Text(entry.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ProgressStrip: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(tint.opacity(0.18))
                Capsule()
                    .fill(tint)
                    .frame(width: max(8, proxy.size.width * progress))
            }
        }
        .frame(height: 8)
    }
}

private extension Double {
    var clamped01: Double {
        min(max(self, 0), 1)
    }
}

private extension View {
    func widgetSurface() -> some View {
        self
            .padding(16)
            .containerBackground(for: .widget) {
                AwradWidgetPalette.background
            }
    }
}

#Preview(as: .systemSmall) {
    TodayFocusWidget()
} timeline: {
    AwradWidgetEntry(
        date: Date(),
        title: "Today's Awrad",
        subtitle: "Daily focus",
        detail: "Continue your current goal",
        symbol: "sparkles",
        progress: 0.36,
        deepLink: nil,
        canIncrement: true
    )
}
