import AwradDomain
import Foundation

/// Strings of the custom dhikr editor, its reference sheet and Manage tags.
extension Strings {
    /// Text the user wrote, for components that take a resource. It's never looked up or translated.
    static func verbatim(_ text: String) -> LocalizedStringResource {
        LocalizedStringResource("\(text)", bundle: bundle)
    }

    // MARK: - Editor

    static let newDhikrTitle = text("library.editor.title.new", "New dhikr")
    static let editDhikrTitle = text("library.editor.title.edit", "Edit dhikr")
    static let arabicField = text("library.editor.arabic", "Arabic text")
    static let kindField = text("library.editor.kind", "Type")
    static let titleField = text("library.editor.title_label", "Title")
    static let arabicBlank = text("library.editor.error.arabic_blank", "Enter the Arabic text.")
    static let titleRequired = text(
        "library.editor.error.title_required", "Give it a title in at least one language.")
    static let referenceInvalid = text("library.editor.error.reference_invalid", "Check this reference.")

    static func tooManyReferences(_ limit: Int) -> LocalizedStringResource {
        LocalizedStringResource(
            "library.editor.error.too_many_references", defaultValue: "Limit reached: \(limit) references.",
            bundle: bundle)
    }

    static func kindName(_ kind: DhikrKind) -> LocalizedStringResource {
        switch kind {
        case .quran: text("library.kind.quran", "Qur'an")
        case .dhikr: text("library.kind.dhikr", "Dhikr")
        case .dua: text("library.kind.dua", "Dua")
        case .salawat: text("library.kind.salawat", "Salawat")
        case .nameOfAllah: text("library.kind.name_of_allah", "Name of Allah")
        }
    }

    /// A language by its own name, the same in every app language.
    static func languageName(_ language: CatalogLanguage) -> LocalizedStringResource {
        switch language {
        case .en: text("library.editor.language.en", "English")
        case .ar: text("library.editor.language.ar", "العربية")
        case .ml: text("library.editor.language.ml", "മലയാളം")
        }
    }

    // MARK: - References

    static let references = text("library.editor.references", "References")
    static let addReference = text("library.editor.reference.add", "Add reference")
    static let removeReference = text("library.editor.reference.remove", "Remove reference")
    static let referenceTypeField = text("library.reference.type", "Type")

    static func referenceKind(_ kind: ReferenceDraft.Kind) -> LocalizedStringResource {
        switch kind {
        case .quran: text("library.reference.type.quran", "Qur'an")
        case .hadith: text("library.reference.type.hadith", "Hadith")
        case .book: text("library.reference.type.book", "Book")
        case .shaykh: text("library.reference.type.shaykh", "Shaykh")
        case .other: text("library.reference.type.other", "Other")
        }
    }

    static func surahField(_ range: ClosedRange<Int>) -> LocalizedStringResource {
        LocalizedStringResource(
            "library.reference.field.surah", defaultValue: "Surah (\(range.lowerBound)–\(range.upperBound))",
            bundle: bundle)
    }

    static func referenceField(_ field: ReferenceDraft.Field) -> LocalizedStringResource {
        switch field {
        case .surah: surahField(ReferenceDraft.surahs)
        case .ayahStart: text("library.reference.field.ayah_start", "First ayah")
        case .ayahEnd: text("library.reference.field.ayah_end", "Last ayah (optional)")
        case .collection: text("library.reference.field.collection", "Collection")
        case .bookTitle: text("library.reference.field.book_title", "Title")
        case .name: text("library.reference.field.name", "Name")
        case .text: text("library.reference.field.text", "Text")
        case .link: text("library.reference.field.link", "Link (optional)")
        }
    }

    static let hadithNumber = text("library.reference.field.number", "Number (optional)")
    static let narrator = text("library.reference.field.narrator", "Narrator (optional)")
    static let grade = text("library.reference.field.grade", "Grade (optional)")
    static let author = text("library.reference.field.author", "Author (optional)")
    static let volume = text("library.reference.field.volume", "Volume (optional)")
    static let page = text("library.reference.field.page", "Page (optional)")
    static let note = text("library.reference.field.note", "Note (optional)")

    static func referenceProblem(_ problem: ReferenceDraft.Problem) -> LocalizedStringResource {
        switch problem {
        case .required:
            text("library.reference.problem.required", "This is required.")
        case .surahRange:
            LocalizedStringResource(
                "library.reference.problem.surah_range",
                defaultValue:
                    "Enter a surah from \(ReferenceDraft.surahs.lowerBound) to \(ReferenceDraft.surahs.upperBound).",
                bundle: bundle)
        case .ayahNumber:
            text("library.reference.problem.ayah_number", "Enter an ayah number.")
        case .ayahOrder:
            text("library.reference.problem.ayah_order", "The last ayah can't come before the first.")
        case .link:
            text("library.reference.problem.link", "Enter a full link, like https://example.org.")
        }
    }

    // MARK: - Recording

    static let recording = text("library.editor.audio", "Recording")
    static let addRecording = text("library.editor.audio.add", "Add recording")
    static let replaceRecording = text("library.editor.audio.replace", "Replace")
    static let removeRecording = text("library.editor.audio.remove", "Remove")
    static let audioHint = LocalizedStringResource(
        "library.editor.audio.hint", defaultValue: "MP3 or M4A, up to \(10) MB", bundle: bundle)

    // MARK: - Tags

    static let noTagsYet = text("library.tags.none_yet", "You have no tags yet.")
    static let chooseTags = text("library.tags.choose", "Choose tags")
    static let newTagField = text("library.tags.new", "New tag")
    static let tagsEmpty = text("library.tags.empty", "You have no tags yet. Add one above.")
    static let editTags = text("library.tags.edit", "Edit tags")
    static let renameTag = text("library.tags.rename", "Rename")
    static let renameTagTitle = text("library.tags.rename.title", "Rename tag")
    static let tagName = text("library.tags.name", "Name")
    static let deleteTagTitle = text("library.tags.delete.title", "Delete this tag?")
    static let deleteTagMessage = text("library.tags.delete.message", "It's removed from every dhikr it's on.")
}
