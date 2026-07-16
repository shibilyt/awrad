import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

enum WirdReaderGeometry {
    static let finalCompletionThreshold: CGFloat = 0.10

    static func finalSegmentHasReachedCompletion(
        segmentBottom: CGFloat,
        viewportHeight: CGFloat
    ) -> Bool {
        guard viewportHeight > 0 else { return false }
        return segmentBottom <= viewportHeight * finalCompletionThreshold
    }

    static func trailingSpacerHeight(viewportHeight: CGFloat) -> CGFloat {
        max(viewportHeight * (1 - finalCompletionThreshold), 0)
    }
}

/// Continuous, scroll-driven Wird reader. Counts and resume position remain owned by `AwradStore`.
struct WirdReaderView: View {
    private static let readingAnchor = UnitPoint(x: 0.5, y: 0.34)
    private static let endMarkerID = UUID(uuidString: "80125F7E-A3A1-4C08-97F0-7028DA28B52C")!

    @Environment(AwradStore.self) private var store
    @Environment(AppRouter.self) private var router
    let wirdID: AwradID
    let partID: AwradID

    @State private var activeIndex = 0
    @State private var scrollPosition = ScrollPosition(idType: AwradID.self)
    @State private var didInitialize = false
    @State private var isProgrammaticScroll = false
    @State private var showCompletion = false
    @State private var showRepeatGateHint = false
    @State private var repeatGateGeneration = 0

    private var language: AppLanguage { store.preferences.appLanguage }
    private var wird: Wird? { store.wird(id: wirdID) }
    private var part: WirdPart? { wird?.part(id: partID) }
    private var occasionKey: String {
        guard let wird, let part else { return "anytime" }
        return store.occasionKey(for: part, in: wird)
    }

    var body: some View {
        ZStack {
            WirdReaderBackground().ignoresSafeArea()

            if let wird, let part, !part.segments.isEmpty {
                let session = currentSession(wird: wird, part: part)
                let summary = store.progressSummary(
                    for: part,
                    wirdID: wird.id,
                    occasionKey: occasionKey
                )

                VStack(spacing: 10) {
                    topBar(wird: wird, part: part, session: session)
                    readerSurface(wird: wird, part: part, session: session, summary: summary)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)

                if showCompletion {
                    let continuation = continuationPart(in: wird)
                    WirdReaderCompletionOverlay(
                        wird: wird,
                        streak: store.wirdStreak(for: wird),
                        language: language,
                        nextPartTitle: continuation?.displayTitle(language: language),
                        onContinue: continuation.map { destination in
                            { navigate(to: destination, in: wird) }
                        },
                        onDone: close,
                        onReadAgain: { restart(part: part, wird: wird) }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 1.03)))
                }
            } else {
                missing
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: setupInitialPosition)
        .onChange(of: partID) { _, _ in resetForPartChange() }
    }

    private func topBar(wird: Wird, part: WirdPart, session: WirdSession?) -> some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: close) {
                    Image(systemName: "chevron.backward")
                        .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                        .foregroundStyle(AwradTheme.ink)
                        .frame(width: 40, height: 40)
                        .background(AwradTheme.surface.opacity(0.86), in: Circle())
                }
                .accessibilityLabel(Text(LocalizedStringKey("Close")))
                .accessibilityIdentifier("wird.reader.close")

                Spacer()
                VStack(spacing: 2) {
                    Text(part.displayTitle(language: language))
                        .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                        .foregroundStyle(AwradTheme.ink)
                        .lineLimit(1)
                    Text("\(min(activeIndex + 1, part.segments.count)) / \(part.segments.count)")
                        .font(AwradTheme.bodyFont(.caption2, weight: .semibold))
                        .foregroundStyle(AwradTheme.sage)
                        .accessibilityIdentifier("wird.reader.position")
                }
                Spacer()
                Color.clear.frame(width: 40, height: 40)
            }

            ProgressView(value: repetitionProgress(for: part, session: session))
                .tint(AwradTheme.sage)
                .accessibilityLabel(Text(LocalizedStringKey("Reading progress")))

            HStack {
                if let previous = WirdLifecycleLogic.adjacentPart(
                    in: wird.parts,
                    currentPartID: part.id,
                    direction: .previous
                ) {
                    Button { navigate(to: previous, in: wird) } label: {
                        Label("Previous section", systemImage: "chevron.backward")
                    }
                }
                Spacer()
                if let next = WirdLifecycleLogic.adjacentPart(
                    in: wird.parts,
                    currentPartID: part.id,
                    direction: .next
                ) {
                    Button { navigate(to: next, in: wird) } label: {
                        Label("Next section", systemImage: "chevron.forward")
                    }
                }
            }
            .font(AwradTheme.bodyFont(.caption, weight: .semibold))
            .foregroundStyle(AwradTheme.subdued)
        }
    }

    private func readerSurface(
        wird: Wird,
        part: WirdPart,
        session: WirdSession?,
        summary: WirdProgressSummary
    ) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(AwradTheme.sage.opacity(0.07))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(AwradTheme.outline.opacity(0.45), lineWidth: 1)
                    }

                ScrollView {
                    LazyVStack(spacing: 0) {
                        Color.clear.frame(height: geometry.size.height * Self.readingAnchor.y)

                        ForEach(Array(part.segments.enumerated()), id: \.element.id) { index, segment in
                            WirdReaderLine(
                                segment: segment,
                                language: language,
                                count: session?.count(for: segment.id) ?? 0,
                                target: AwradStore.effectiveTarget(for: segment, in: part),
                                isActive: index == activeIndex,
                                isPassed: index < activeIndex
                            )
                            .id(segment.id)
                            .onWirdReadingAnchorChange(
                                anchorY: geometry.size.height * Self.readingAnchor.y
                            ) {
                                handleUserScroll(
                                    to: segment.id,
                                    wird: wird,
                                    part: part,
                                    session: currentSession(wird: wird, part: part)
                                )
                            }
                            .onWirdFinalSegmentCompletionChange(
                                isFinalSegment: index == part.segments.index(before: part.segments.endIndex),
                                viewportHeight: geometry.size.height
                            ) {
                                handleUserScroll(
                                    to: Self.endMarkerID,
                                    wird: wird,
                                    part: part,
                                    session: currentSession(wird: wird, part: part)
                                )
                            }
                        }

                        Color.clear
                            .frame(height: 1)
                            .id(Self.endMarkerID)
                        Color.clear.frame(
                            height: WirdReaderGeometry.trailingSpacerHeight(
                                viewportHeight: geometry.size.height
                            )
                        )
                    }
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .scrollPosition($scrollPosition, anchor: Self.readingAnchor)
                .onScrollPhaseChange { _, phase in
                    if phase == .idle { isProgrammaticScroll = false }
                }
                .simultaneousGesture(
                    TapGesture().onEnded {
                        reciteActiveSegment(in: part, wird: wird)
                    }
                )
                .accessibilityIdentifier("wird.reader.surface")

                readerControls(
                    part: part,
                    session: session,
                    summary: summary,
                    onCount: { reciteActiveSegment(in: part, wird: wird) }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
    }

    @ViewBuilder
    private func readerControls(
        part: WirdPart,
        session: WirdSession?,
        summary: WirdProgressSummary,
        onCount: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 10) {
            if showRepeatGateHint {
                Text(LocalizedStringKey("Complete the count to continue"))
                    .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                    .foregroundStyle(AwradTheme.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AwradTheme.surface.opacity(0.94), in: Capsule())
                    .accessibilityIdentifier("wird.reader.repeat-gate")
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            if summary.isComplete {
                Button {
                    withAnimation(.spring(duration: 0.35)) { showCompletion = true }
                } label: {
                    Label("Finish section", systemImage: "checkmark.seal.fill")
                        .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AwradTheme.sage, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("wird.reader.finish")
            } else if part.segments.indices.contains(activeIndex) {
                let segment = part.segments[activeIndex]
                let target = AwradStore.effectiveTarget(for: segment, in: part)
                let count = min(session?.count(for: segment.id) ?? 0, target)
                if segment.isCountable, target > 1, count < target {
                    Button(action: onCount) {
                        HStack(spacing: 12) {
                            Image(systemName: "hand.tap.fill")
                            Text(LocalizedStringKey("Tap anywhere to count"))
                            Spacer()
                            Text("\(count)/\(target)")
                                .font(AwradTheme.bodyFont(.headline, weight: .bold))
                                .contentTransition(.numericText())
                        }
                        .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(AwradTheme.sage, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("wird.reader.count")
                    .accessibilityValue(Text("\(count) of \(target)"))
                } else {
                    Text(LocalizedStringKey("Scroll to continue"))
                        .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                        .foregroundStyle(AwradTheme.subdued)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AwradTheme.surface.opacity(0.9), in: Capsule())
                }
            }
        }
    }

    private var missing: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(AwradTheme.bodyFont(.largeTitle))
                .foregroundStyle(AwradTheme.subdued)
            Text(LocalizedStringKey("This reading is no longer available."))
                .foregroundStyle(AwradTheme.ink)
            Button(LocalizedStringKey("Close"), action: close)
                .foregroundStyle(AwradTheme.sage)
        }
    }

    private func currentSession(wird: Wird, part: WirdPart) -> WirdSession? {
        store.session(wirdID: wird.id, partID: part.id, occasionKey: occasionKey)
    }

    private func handleUserScroll(
        to segmentID: AwradID,
        wird: Wird,
        part: WirdPart,
        session: WirdSession?
    ) {
        guard didInitialize, !isProgrammaticScroll else { return }
        let requestedIndex: Int
        if segmentID == Self.endMarkerID {
            requestedIndex = part.segments.count
        } else if let index = part.segments.firstIndex(where: { $0.id == segmentID }) {
            requestedIndex = index
        } else {
            return
        }
        guard requestedIndex != activeIndex else { return }

        let transition = WirdLifecycleLogic.readerTransition(
            in: part,
            session: session,
            from: activeIndex,
            requestedIndex: requestedIndex
        )
        guard part.segments.indices.contains(transition.targetIndex) else { return }
        let activeSegmentID = part.segments[transition.targetIndex].id
        guard store.recordWirdReadingAdvance(
            wirdID: wird.id,
            partID: part.id,
            occasionKey: occasionKey,
            completedSegmentIDs: transition.completedSegmentIDs,
            activeSegmentID: activeSegmentID
        ) else {
            scroll(to: activeIndex, in: part, animated: true)
            return
        }

        activeIndex = transition.targetIndex
        if transition.wasClamped {
            showRepeatGate()
            scroll(to: transition.targetIndex, in: part, animated: true)
        } else if !transition.reachedEnd, requestedIndex != transition.targetIndex {
            scroll(to: transition.targetIndex, in: part, animated: true)
        }
    }

    private func reciteActiveSegment(in part: WirdPart, wird: Wird) {
        guard part.segments.indices.contains(activeIndex) else { return }
        let segment = part.segments[activeIndex]
        let target = AwradStore.effectiveTarget(for: segment, in: part)
        guard segment.isCountable, target > 1 else { return }
        let previous = currentSession(wird: wird, part: part)?.count(for: segment.id) ?? 0
        guard previous < target else { return }

        let newCount = store.incrementSegment(
            wirdID: wird.id,
            partID: part.id,
            occasionKey: occasionKey,
            segmentID: segment.id,
            target: target
        )
        guard newCount > previous else { return }
        if newCount >= target {
            playCompletionHaptic()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                moveToNextActionable(after: activeIndex, in: part, wird: wird)
            }
        } else {
            playTapHaptic()
        }
    }

    private func moveToNextActionable(after index: Int, in part: WirdPart, wird: Wird) {
        guard let next = part.segments.indices.dropFirst(index + 1).first(where: {
            part.segments[$0].kind != .heading
        }) else { return }
        let activeSegmentID = part.segments[next].id
        guard store.recordWirdReadingAdvance(
            wirdID: wird.id,
            partID: part.id,
            occasionKey: occasionKey,
            completedSegmentIDs: [],
            activeSegmentID: activeSegmentID
        ) else { return }
        activeIndex = next
        scroll(to: next, in: part, animated: true)
    }

    private func showRepeatGate() {
        repeatGateGeneration += 1
        let generation = repeatGateGeneration
        withAnimation(.easeOut(duration: 0.2)) { showRepeatGateHint = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            guard repeatGateGeneration == generation else { return }
            withAnimation(.easeIn(duration: 0.2)) { showRepeatGateHint = false }
        }
    }

    private func scroll(to index: Int, in part: WirdPart, animated: Bool) {
        guard part.segments.indices.contains(index) else { return }
        isProgrammaticScroll = true
        let segmentID = part.segments[index].id
        if animated {
            withAnimation(.easeInOut(duration: 0.3)) {
                scrollPosition.scrollTo(id: segmentID, anchor: Self.readingAnchor)
            }
        } else {
            scrollPosition.scrollTo(id: segmentID, anchor: Self.readingAnchor)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (animated ? 0.4 : 0.1)) {
            isProgrammaticScroll = false
        }
    }

    private func setupInitialPosition() {
        guard !didInitialize, let wird, let part, !part.segments.isEmpty else { return }
        didInitialize = true
        let session = currentSession(wird: wird, part: part)
        activeIndex = WirdLifecycleLogic.resumeIndex(in: part, session: session)
        showCompletion = false
        let activeSegmentID = part.segments[activeIndex].id
        _ = store.recordWirdReadingAdvance(
            wirdID: wird.id,
            partID: part.id,
            occasionKey: occasionKey,
            completedSegmentIDs: [],
            activeSegmentID: activeSegmentID
        )
        DispatchQueue.main.async { scroll(to: activeIndex, in: part, animated: false) }
    }

    private func resetForPartChange() {
        didInitialize = false
        activeIndex = 0
        showCompletion = false
        showRepeatGateHint = false
        scrollPosition = ScrollPosition(idType: AwradID.self)
        setupInitialPosition()
    }

    private func restart(part: WirdPart, wird: Wird) {
        guard store.resetSession(
            wirdID: wird.id,
            partID: part.id,
            occasionKey: occasionKey
        ) else { return }
        showCompletion = false
        activeIndex = WirdLifecycleLogic.nearestActionableIndex(in: part, to: 0) ?? 0
        let activeSegmentID = part.segments[activeIndex].id
        _ = store.recordWirdReadingAdvance(
            wirdID: wird.id,
            partID: part.id,
            occasionKey: occasionKey,
            completedSegmentIDs: [],
            activeSegmentID: activeSegmentID
        )
        scroll(to: activeIndex, in: part, animated: true)
    }

    private func repetitionProgress(for part: WirdPart, session: WirdSession?) -> Double {
        let targets = part.countableSegments.map { segment in
            (segment, AwradStore.effectiveTarget(for: segment, in: part))
        }
        let total = targets.reduce(0) { $0 + $1.1 }
        guard total > 0 else { return 0 }
        let completed = targets.reduce(0) { partial, item in
            partial + min(session?.count(for: item.0.id) ?? 0, item.1)
        }
        return min(Double(completed) / Double(total), 1)
    }

    private func continuationPart(in wird: Wird) -> WirdPart? {
        let effectiveToday = WirdLifecycleLogic.date(from: store.todayKey) ?? Date()
        let activeParts = store.todayParts(for: wird, now: effectiveToday)
        return activeParts.first(where: { candidate in
            guard candidate.id != partID else { return false }
            let key = store.occasionKey(for: candidate, in: wird)
            return !store.progressSummary(for: candidate, wirdID: wird.id, occasionKey: key).isComplete
        })
    }

    private func navigate(to destination: WirdPart, in wird: Wird) {
        router.replaceLast(
            with: .wirdReader(wirdID: wird.id, partID: destination.id),
            in: store.selectedTab
        )
    }

    private func close() {
        router.pop(in: store.selectedTab)
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

private extension View {
    func onWirdReadingAnchorChange(
        anchorY: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        onGeometryChange(for: Bool.self) { geometry in
            let frame = geometry.frame(in: .scrollView(axis: .vertical))
            return frame.minY <= anchorY && frame.maxY > anchorY
        } action: { intersectsReadingAnchor in
            guard intersectsReadingAnchor else { return }
            action()
        }
    }

    func onWirdFinalSegmentCompletionChange(
        isFinalSegment: Bool,
        viewportHeight: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        onGeometryChange(for: Bool.self) { geometry in
            guard isFinalSegment else { return false }
            let frame = geometry.frame(in: .scrollView(axis: .vertical))
            return WirdReaderGeometry.finalSegmentHasReachedCompletion(
                segmentBottom: frame.maxY,
                viewportHeight: viewportHeight
            )
        } action: { hasReachedCompletion in
            guard hasReachedCompletion else { return }
            action()
        }
    }
}

private struct WirdReaderLine: View {
    let segment: WirdSegment
    let language: AppLanguage
    let count: Int
    let target: Int
    let isActive: Bool
    let isPassed: Bool

    private var isRead: Bool {
        segment.isCountable ? count >= target : isPassed
    }

    var body: some View {
        Group {
            if segment.kind == .heading {
                ZStack(alignment: .topLeading) {
                    Text(segment.headingText(language: language) ?? "")
                        .font(AwradTheme.displayFont(26))
                        .foregroundStyle(AwradTheme.sage)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 44)
                        .padding(.vertical, 20)
                        .opacity(isActive ? 1 : 0.55)

                    if isRead {
                        WirdReadMarker()
                            .padding(.top, 22)
                            .accessibilityLabel(Text(LocalizedStringKey("Read")))
                            .accessibilityIdentifier("wird.reader.read.\(segment.id.uuidString)")
                    }
                }
            } else {
                recitationLine
                    .opacity(isActive ? 1 : 0.35)
                    .animation(.easeInOut(duration: 0.25), value: isActive)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(
            isActive
                ? "wird.reader.active.\(segment.id.uuidString)"
                : "wird.reader.line.\(segment.id.uuidString)"
        )
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private var recitationLine: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 12) {
                if segment.kind == .instruction {
                    Label {
                        Text(segment.headingText(language: language) ?? "")
                            .multilineTextAlignment(.center)
                    } icon: {
                        Image(systemName: "info.circle")
                    }
                    .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                    .foregroundStyle(AwradTheme.subdued)
                } else {
                    if let quran = segment.quranRef {
                        Text(quran.displayText())
                            .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                            .foregroundStyle(AwradTheme.sage)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(AwradTheme.sage.opacity(0.13), in: Capsule())
                    } else if segment.hasAudio {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(AwradTheme.bodyFont(.caption))
                            .foregroundStyle(AwradTheme.sage)
                    }

                    WirdReaderArabicText(segment: segment)

                    if isActive, let transliteration = segment.transliterationText(language: language) {
                        Text(transliteration)
                            .font(AwradTheme.bodyFont(.headline, weight: .medium))
                            .foregroundStyle(AwradTheme.sage)
                            .multilineTextAlignment(.center)
                    }
                    if isActive, let translation = segment.translationText(language: language) {
                        Text(translation)
                            .font(AwradTheme.bodyFont(.body))
                            .foregroundStyle(AwradTheme.ink.opacity(0.84))
                            .multilineTextAlignment(.center)
                    }
                    if isActive, let fadl = segment.fadlText(language: language) {
                        Text(fadl)
                            .font(AwradTheme.bodyFont(.footnote))
                            .italic()
                            .foregroundStyle(AwradTheme.subdued)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 44)
            .padding(.vertical, 14)

            if isRead {
                WirdReadMarker()
                    .padding(.top, 18)
                    .accessibilityLabel(Text(LocalizedStringKey("Read")))
                    .accessibilityIdentifier("wird.reader.read.\(segment.id.uuidString)")
            } else if segment.isCountable, target > 1 {
                Text("\(min(count, target))/\(target)")
                    .font(AwradTheme.bodyFont(.caption2, weight: .bold))
                    .foregroundStyle(AwradTheme.ink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AwradTheme.sage.opacity(0.17), in: Capsule())
                    .padding(.top, 18)
            }
        }
    }
}

private struct WirdReaderArabicText: View {
    let segment: WirdSegment

    var body: some View {
        let split = segment.kind == .quran
            ? QuranDhikrReadingPolicy.splitBismillah(segment.arabic)
            : (bismillah: nil, body: segment.arabic)

        VStack(spacing: 10) {
            if let bismillah = split.bismillah {
                Text(bismillah)
                    .font(AwradTheme.arabicFont(24))
                    .lineSpacing(10)
            }
            if !split.body.isEmpty {
                Text(split.body)
                    .font(AwradTheme.arabicFont(32))
                    .lineSpacing(14)
            }
        }
        .foregroundStyle(AwradTheme.ink)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .environment(\.layoutDirection, .rightToLeft)
        .accessibilityLabel(segment.arabic)
    }
}

private struct WirdReadMarker: View {
    var body: some View {
        Image(systemName: "checkmark")
            .font(AwradTheme.bodyFont(.caption2, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 20, height: 20)
            .background(AwradTheme.sage, in: Circle())
    }
}

private struct WirdReaderBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                AwradTheme.background,
                AwradTheme.surface.opacity(0.78),
                AwradTheme.background
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(alignment: .top) {
            RadialGradient(
                colors: [AwradTheme.mint.opacity(0.28), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 460
            )
        }
    }
}

private struct WirdReaderCompletionOverlay: View {
    let wird: Wird
    let streak: Int
    let language: AppLanguage
    let nextPartTitle: String?
    let onContinue: (() -> Void)?
    let onDone: () -> Void
    let onReadAgain: () -> Void

    var body: some View {
        ZStack {
            WirdReaderBackground().ignoresSafeArea()
            VStack(spacing: 22) {
                Image(systemName: "checkmark.seal.fill")
                    .font(AwradTheme.bodyFont(68, weight: .semibold))
                    .foregroundStyle(AwradTheme.sage)
                Text(LocalizedStringKey("Section Complete"))
                    .font(AwradTheme.displayFont(.title, weight: .bold))
                    .foregroundStyle(AwradTheme.ink)
                Text(wird.displayName(language: language))
                    .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                    .foregroundStyle(AwradTheme.subdued)
                if streak > 0 {
                    Label(AwradLocalizer.wirdStreak(streak, language: language), systemImage: "flame.fill")
                        .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                        .foregroundStyle(AwradTheme.sage)
                }

                VStack(spacing: 12) {
                    if let nextPartTitle, let onContinue {
                        Button(action: onContinue) {
                            VStack(spacing: 2) {
                                Text(LocalizedStringKey("Continue to next section"))
                                Text(nextPartTitle)
                                    .font(AwradTheme.bodyFont(.caption, weight: .medium))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AwradTheme.sage, in: Capsule())
                        }
                    }
                    Button(action: onDone) {
                        Text(LocalizedStringKey("Done"))
                            .font(AwradTheme.bodyFont(.headline, weight: .semibold))
                            .foregroundStyle(AwradTheme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AwradTheme.surface, in: Capsule())
                    }
                    Button(action: onReadAgain) {
                        Label("Read again", systemImage: "arrow.counterclockwise")
                            .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                            .foregroundStyle(AwradTheme.subdued)
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                .padding(.horizontal, 40)
            }
            .padding(30)
        }
    }
}
