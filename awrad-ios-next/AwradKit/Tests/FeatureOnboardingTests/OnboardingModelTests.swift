import AwradTesting
import FeatureOnboarding
import Testing

struct OnboardingModelTests {
    @Test func gettingStartedMarksTheInstallationOnboardedAndFinishes() async {
        let status = FakeOnboardingStatusStore()
        let model = OnboardingModel(status: status)

        await model.send(.getStarted)

        #expect(await status.value)
        #expect(model.state.isFinished)
        #expect(!model.state.isFinishing)
    }
}
