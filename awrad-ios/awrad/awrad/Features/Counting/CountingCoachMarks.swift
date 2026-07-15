import SwiftUI

/// A coach-mark step shown on the first visit to the Counter (PRD §4.7).
/// Conditional steps are filtered out by the parent before building the overlay.
struct CountingCoachStep: Identifiable, Equatable {
    enum Gate: Equatable {
        case none
        case taps(required: Int)
        case audioPlays(required: Int)
    }

    let id: String
    let titleKey: LocalizedStringKey
    let bodyKey: LocalizedStringKey
    let symbol: String
    /// The id of the captured target frame to spotlight (see `View.coachAnchor`).
    var targetID: String
    /// Spotlight as a circle (count button) vs. a rounded rectangle (panels/buttons).
    var circle: Bool = false
    var gate: Gate = .none
}

// MARK: - Target frame capture

/// Collects the frames of coach-mark targets via anchor preferences, keyed by id.
struct CoachAnchorKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

extension View {
    /// Marks this view as a coach-mark spotlight target with the given id.
    func coachAnchor(_ id: String) -> some View {
        anchorPreference(key: CoachAnchorKey.self, value: .bounds) { [id: $0] }
    }
}

// MARK: - Spotlight mask

/// A full-screen scrim with an animated cut-out hole around the active target.
private struct SpotlightMask: Shape {
    var rect: CGRect
    var cornerRadius: CGFloat
    var isCircle: Bool

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(AnimatablePair(rect.minX, rect.minY), AnimatablePair(rect.width, rect.height)) }
        set {
            rect = CGRect(x: newValue.first.first, y: newValue.first.second,
                          width: newValue.second.first, height: newValue.second.second)
        }
    }

    func path(in bounds: CGRect) -> Path {
        var path = Path(bounds)
        guard rect.width > 0, rect.height > 0 else { return path }
        if isCircle {
            path.addEllipse(in: rect)
        } else {
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
        }
        return path
    }
}

/// First-run guide overlay for the Counter. It dims the screen with a spotlight
/// cut-out around the active target, while letting real taps reach the COUNT button
/// (the scrim never captures hits). Gated steps advance only once their tap/play
/// requirement is met. "Skip" always marks the guide as seen.
struct CountingCoachOverlay: View {
    let steps: [CountingCoachStep]
    let language: AppLanguage
    /// Real COUNT taps observed since the overlay appeared.
    let tapProgress: Int
    /// Completed audio plays observed since the overlay appeared.
    let audioProgress: Int
    /// Resolved target frames keyed by `CountingCoachStep.targetID`.
    let targets: [String: CGRect]
    let onFinish: () -> Void

    @State private var stepIndex = 0

    private var step: CountingCoachStep? {
        guard steps.indices.contains(stepIndex) else { return nil }
        return steps[stepIndex]
    }

    private var spotlightRect: CGRect? {
        guard let step, let rect = targets[step.targetID] else { return nil }
        let pad: CGFloat = step.circle ? 14 : 12
        return rect.insetBy(dx: -pad, dy: -pad)
    }

    private var gateSatisfied: Bool {
        switch step?.gate ?? .none {
        case .taps(let required): return tapProgress >= required
        case .audioPlays(let required): return audioProgress >= required
        case .none: return true
        }
    }

    private var gateProgressText: String? {
        switch step?.gate ?? .none {
        case .taps(let required):
            return AwradLocalizer.format("%d of %d", language: language, min(tapProgress, required), required)
        case .audioPlays(let required):
            return AwradLocalizer.format("%d of %d", language: language, min(audioProgress, required), required)
        case .none:
            return nil
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let rect = spotlightRect ?? .zero
            let cardAtBottom = rect.midY < proxy.size.height * 0.5

            ZStack {
                // Dimmed scrim with spotlight hole — never captures hits, so the
                // real COUNT button beneath stays live during gated steps.
                SpotlightMask(rect: rect, cornerRadius: 22, isCircle: step?.circle ?? false)
                    .fill(Color.black.opacity(0.66), style: FillStyle(eoFill: true))
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.4), value: stepIndex)

                VStack {
                    HStack {
                        Spacer()
                        Button(action: onFinish) {
                            Text("Skip")
                                .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .frame(height: 36)
                                .background(.white.opacity(0.18), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("counting-coach-skip")
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, proxy.safeAreaInsets.top + 8)

                    if cardAtBottom { Spacer() }

                    if let step {
                        hintCard(step)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 28)
                            .transition(.opacity)
                    }

                    if !cardAtBottom { Spacer() }
                }
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: stepIndex)
        .onChange(of: tapProgress) { _, _ in advanceIfGateSatisfiedAutomatically() }
        .onChange(of: audioProgress) { _, _ in advanceIfGateSatisfiedAutomatically() }
    }

    @ViewBuilder
    private func hintCard(_ step: CountingCoachStep) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text(step.titleKey).font(AwradTheme.bodyFont(.headline, weight: .semibold))
            } icon: {
                Image(systemName: step.symbol).foregroundStyle(AwradTheme.gold)
            }
            .foregroundStyle(AwradTheme.ink)

            Text(step.bodyKey)
                .font(AwradTheme.bodyFont(.subheadline))
                .foregroundStyle(.secondary)

            if let gateProgressText {
                Text(gateProgressText)
                    .font(AwradTheme.bodyFont(.caption, weight: .bold).monospacedDigit())
                    .foregroundStyle(AwradTheme.sage)
            }

            HStack {
                Text("\(stepIndex + 1) / \(steps.count)")
                    .font(AwradTheme.bodyFont(.caption, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if step.gate == .none {
                    Button(action: advance) {
                        Text(isLastStep ? "Done" : "Next")
                            .font(AwradTheme.bodyFont(.subheadline, weight: .semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AwradTheme.sage)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AwradTheme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 18, y: 8)
    }

    private var isLastStep: Bool {
        stepIndex >= steps.count - 1
    }

    private func advanceIfGateSatisfiedAutomatically() {
        guard let step, step.gate != .none, gateSatisfied else { return }
        advance()
    }

    private func advance() {
        if isLastStep {
            onFinish()
        } else {
            stepIndex += 1
        }
    }
}
