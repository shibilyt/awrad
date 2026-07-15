import AVFoundation
import Foundation
import Testing
@testable import awrad

@MainActor
@Suite("Audio session lifecycle")
struct AudioSessionServiceTests {
    @Test func changingPlaybackSpeedClampsWithoutRecursing() {
        let service = AudioSessionService(notificationCenter: NotificationCenter())

        service.playbackRate = 1.55
        #expect(service.playbackRate == 1.55)

        service.playbackRate = 4
        #expect(service.playbackRate == 3)

        service.playbackRate = 0.5
        #expect(service.playbackRate == 0.75)
    }

    @Test func interruptionBeginningPausesPlayback() {
        let notification = Notification(
            name: AVAudioSession.interruptionNotification,
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue]
        )

        #expect(AudioSessionService.interruptionAction(notification) == .pause)
    }

    @Test func interruptionOnlyResumesWhenTheSystemAllowsIt() {
        let resumable = Notification(
            name: AVAudioSession.interruptionNotification,
            userInfo: [
                AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
                AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.shouldResume.rawValue
            ]
        )
        let nonResumable = Notification(
            name: AVAudioSession.interruptionNotification,
            userInfo: [AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue]
        )

        #expect(AudioSessionService.interruptionAction(resumable) == .resume)
        #expect(AudioSessionService.interruptionAction(nonResumable) == .finishWithoutResuming)
    }

    @Test func unpluggingAnAudioRoutePausesButNormalRouteChangesDoNot() {
        let unplugged = Notification(
            name: AVAudioSession.routeChangeNotification,
            userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue]
        )
        let connected = Notification(
            name: AVAudioSession.routeChangeNotification,
            userInfo: [AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.newDeviceAvailable.rawValue]
        )

        #expect(AudioSessionService.routeChangeRequiresPause(unplugged))
        #expect(!AudioSessionService.routeChangeRequiresPause(connected))
    }

    @Test func malformedSystemNotificationsAreIgnored() {
        #expect(AudioSessionService.interruptionAction(Notification(name: .init("invalid"))) == .ignore)
        #expect(!AudioSessionService.routeChangeRequiresPause(Notification(name: .init("invalid"))))
    }
}
