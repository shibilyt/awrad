import Foundation
import Testing

struct CreateDhikrComposerLayoutTests {
    @Test func primarySurfaceIsArabicFirstAndKeepsOptionalFieldsOutOfTheWay() throws {
        let source = try createDhikrViewSource()
        let essentialFields = source
            .components(separatedBy: "private var essentialFields: some View").last?
            .components(separatedBy: "private var optionalDetailsLauncher: some View").first ?? ""

        let arabic = try #require(essentialFields.range(of: "title: \"Arabic text\""))
        let title = try #require(essentialFields.range(of: "title: \"Title\""))

        #expect(arabic.lowerBound < title.lowerBound)
        #expect(!essentialFields.contains("title: \"Transliteration\""))
        #expect(!essentialFields.contains("title: \"Translation\""))
    }

    @Test func secondarySheetOwnsAllEnrichmentControls() throws {
        let source = try createDhikrViewSource()
        let body = source
            .components(separatedBy: "var body: some View").last?
            .components(separatedBy: "private var composerIntro: some View").first ?? ""
        let optionalDetails = source
            .components(separatedBy: "private var optionalDetailsSheet: some View").last?
            .components(separatedBy: "private var optionalTextFields: some View").first ?? ""

        #expect(body.contains(".sheet(isPresented: $isOptionalDetailsPresented)"))
        #expect(body.contains("optionalDetailsSheet"))
        #expect(optionalDetails.contains("optionalTextFields"))
        #expect(optionalDetails.contains("categoryPicker"))
        #expect(optionalDetails.contains("tagsSection"))
        #expect(optionalDetails.contains("audioSection"))
        #expect(optionalDetails.contains(".fileImporter("))
        #expect(optionalDetails.contains(".alert(\"Audio import failed\""))
        #expect(body.contains("importErrorKey != nil && !isOptionalDetailsPresented"))
    }

    @Test func saveStaysStickyAndPreservesArabicOnlyValidation() throws {
        let source = try createDhikrViewSource()
        let body = source
            .components(separatedBy: "var body: some View").last?
            .components(separatedBy: "private var composerIntro: some View").first ?? ""
        let canSave = source
            .components(separatedBy: "private var canSave: Bool").last?
            .components(separatedBy: "private var isEditing: Bool").first ?? ""

        #expect(body.contains(".safeAreaInset(edge: .bottom)"))
        #expect(body.contains("saveButton"))
        #expect(canSave.contains("!arabic.trimmingCharacters"))
        #expect(!canSave.contains("title.trimmingCharacters"))
    }

    @Test func categoryAndTagsUseSearchableMultiSelectSheets() throws {
        let source = try createDhikrViewSource()
        #expect(source.contains("isCategorySelectorPresented"))
        #expect(source.contains("isTagSelectorPresented"))
        #expect(source.contains("Search categories"))
        #expect(source.contains("selectedCategories"))
        #expect(source.contains("toggleCategory"))
        #expect(source.contains("Search or add tags"))
        #expect(source.contains("createAndAssignTag(from: tagSearchQuery)"))
        #expect(!source.contains("newTagName"))
    }

    @Test func navigationUsesAnAccessibleLiquidGlassBackButtonWithoutAContextLabel() throws {
        let source = try createDhikrViewSource()

        #expect(source.contains(".navigationBarBackButtonHidden(true)"))
        #expect(source.contains("ToolbarItem(placement: .topBarLeading)"))
        #expect(source.contains(".buttonStyle(.glass)"))
        #expect(source.contains("Image(systemName: \"chevron.backward\")"))
        #expect(source.contains(".accessibilityLabel(\"Back\")"))
        #expect(source.contains("router.pop(in: store.selectedTab)"))
    }

    private func createDhikrSource() throws -> String {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../awrad/Features/Library/CreateDhikrView.swift")
            .standardizedFileURL
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }

    private func createDhikrViewSource() throws -> String {
        let source = try createDhikrSource()
        return source
            .components(separatedBy: "struct CreateDhikrView: View {").last?
            .components(separatedBy: "private struct DhikrInputField").first ?? ""
    }
}
