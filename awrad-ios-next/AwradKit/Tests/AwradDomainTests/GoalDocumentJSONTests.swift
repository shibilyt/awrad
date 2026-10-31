import AwradDomain
import AwradTesting
import Foundation
import Testing

/// The `goal` sync document's wire codec: every valid document in the goal-model fixtures reads
/// into a `GoalDocument` and writes the same JSON back.
@Suite("goal document JSON")
struct GoalDocumentJSONTests {
    static func documents() throws -> [AwradJSON] {
        let directory = try FixtureLoader.fixturesDirectory(model: "goal-model")
        var documents: [AwradJSON] = []
        for rule in ["goal_version_on_day", "goal_validity"] {
            let data = try Data(contentsOf: directory.appending(path: "\(rule).json"))
            let root = try JSONDecoder().decode(AwradJSON.self, from: data)
            for item in root["cases"]?.arrayValue ?? [] {
                guard let document = item["given"]?["document"] else { continue }
                // goal_validity's documents are valid exactly when the case expects no errors.
                if item["expect"]?["valid"] == .bool(false) { continue }
                documents.append(document)
            }
        }
        return documents
    }

    @Test(arguments: try documents())
    func validDocumentsRoundTrip(_ json: AwradJSON) throws {
        let document = try GoalDocument(json: json)
        #expect(document.json == json)
        #expect(try SyncDocument(type: .goal, json: json) == .goal(document))
    }

    @Test func invalidDocumentsAreRefused() throws {
        let directory = try FixtureLoader.fixturesDirectory(model: "goal-model")
        let data = try Data(contentsOf: directory.appending(path: "goal_validity.json"))
        let root = try JSONDecoder().decode(AwradJSON.self, from: data)
        let invalid = (root["cases"]?.arrayValue ?? []).compactMap { item -> AwradJSON? in
            item["expect"]?["valid"] == .bool(false) ? item["given"]?["document"] : nil
        }
        #expect(!invalid.isEmpty)
        for json in invalid {
            #expect(throws: SyncDocumentError.self) { try GoalDocument(json: json) }
        }
    }

    @Test func goalOrderRoundTripsAndRefusesRepeats() throws {
        let id = "0192f300-0000-7000-8000-000000000001"
        let json = AwradJSON.object(["goal_ids": .array([.string(id)])])
        #expect(try GoalOrder(json: json).json == json)
        let repeated = AwradJSON.object(["goal_ids": .array([.string(id), .string(id)])])
        #expect(throws: SyncDocumentError.self) { try GoalOrder(json: repeated) }
    }
}
