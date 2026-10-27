import AwradDesignSystem
import AwradDomain
import SwiftUI

/// The audio player bar at the bottom of the Arabic card (components.md, "Audio player bar"): the
/// round play/pause button (a progress indicator while loading), a progress line and the time,
/// "0:14 / 0:26", or the elapsed time alone until the length is known. The button keeps its place
/// whatever the time shows. A failure shows its message under the bar.
struct DhikrAudioBar: View {
    let audio: DhikrDetailModel.Audio
    let action: () -> Void

    private var position: PlaybackPosition {
        audio.position ?? PlaybackPosition(elapsed: .zero)
    }

    var body: some View {
        VStack(spacing: AwradSpacing.sm) {
            HStack(spacing: AwradSpacing.md) {
                AwradRoundButton(
                    icon: audio.isActive ? .pause : .play, label: audio.isActive ? Strings.pause : Strings.play,
                    isLoading: audio == .loading, action: action)
                PlaybackProgressLine(fraction: position.fraction)
                time
                    .awradTextStyle(.caption)
                    .monospacedDigit()
                    .foregroundStyle(AwradColors.onSurfaceVariant)
                    .fixedSize()
            }
            if audio == .failed {
                Text(Strings.audioFailed)
                    .awradTextStyle(.caption)
                    .foregroundStyle(AwradColors.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var time: Text {
        let elapsed = Self.format(position.elapsed)
        guard let duration = position.duration else { return Text(verbatim: elapsed) }
        return Text(Strings.audioProgress(elapsed: elapsed, duration: Self.format(duration)))
    }

    private static func format(_ duration: Duration) -> String {
        duration.formatted(.time(pattern: .minuteSecond))
    }
}

/// A `ringStroke`-high, fully rounded line: the `outline` track with the `progress` fill from the
/// start. Hidden from VoiceOver: the time says the same.
private struct PlaybackProgressLine: View {
    let fraction: Double

    var body: some View {
        Capsule()
            .fill(AwradColors.outline)
            .overlay {
                GeometryReader { proxy in
                    Capsule()
                        .fill(AwradColors.progress)
                        .frame(width: proxy.size.width * fraction)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(height: AwradSize.ringStroke)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }
}
