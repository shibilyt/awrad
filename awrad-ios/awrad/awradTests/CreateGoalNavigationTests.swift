import Foundation
import Testing

struct CreateGoalNavigationTests {
    @Test func createGoalUsesAnAccessibleLiquidGlassBackButton() throws {
        let source = try createGoalViewSource()

        #expect(source.contains(".navigationBarBackButtonHidden(true)"))
        #expect(source.contains("ToolbarItem(placement: .topBarLeading)"))
        #expect(source.contains(".buttonStyle(.glass)"))
        #expect(source.contains("Image(systemName: \"chevron.backward\")"))
        #expect(source.contains(".accessibilityLabel(\"Back\")"))
        #expect(source.contains(".accessibilityIdentifier(\"goal-create-back-button\")"))
    }

    private func createGoalViewSource() throws -> String {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../awrad/Features/Goals/CreateGoalView.swift")
            .standardizedFileURL
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        return source
            .components(separatedBy: "struct CreateGoalView: View {").last?
            .components(separatedBy: "private enum GoalTypeChoice").first ?? ""
    }
}
