import Foundation

/// Stable product identity for built-in dhikrs. Content may evolve; these keys and
/// UUIDs do not. Retired entries remain reserved and replacements receive new IDs.
enum BuiltInDhikrRegistry {
    struct Entry: Hashable {
        let catalogKey: String
        let id: UUID
    }

    static let surahIkhlas = entry("surah-ikhlas", "c88b9491-40ad-4b42-a5b8-e07c4b4d31ef")
    static let tahleel = entry("tahleel", "6f04f77e-dcb6-4a29-9dc5-fcd3649c2961")
    static let yaWahhabu = entry("ya-wahhabu", "6abe90a8-abe2-4678-a4bf-3f14323c3e8d")
    static let isthighfar = entry("isthighfar", "3285e014-551b-46a4-aedc-8b6664b59bc7")
    static let swalathAlFathimiyya = entry("swalath-al-fathimiyya", "3daf6738-face-4afc-aeca-2ab62e57a5ea")
    static let swalath = entry("swalath", "f2337cb6-6d46-45fb-a193-b9e231c97bbd")
    static let swalathSayyidina = entry("swalath-sayyidina", "2a65a361-c499-41ff-b441-fc487714eacf")
    static let swalathAlFatih = entry("swalath-al-fatih", "c94229d6-6b24-4280-ae7c-1e618fc4f1fc")
    static let swalathAlNariyya = entry("swalath-al-nariyya", "c2a59b7e-7e64-4bfe-9b0c-2d493fe01537")
    static let swalathForDebt = entry("swalath-for-debt", "9cbb04d9-fb07-4c8f-9235-49e2ce6fc818")
    static let ramadanDhikr = entry("ramadan-dhikr", "82f55daf-9f23-4d53-a10e-b60a5c90b3c8")
    static let ramadanFirstTenNights = entry("ramadan-first-ten-nights", "cebda17e-2ed8-4bd6-b1f3-5dbbb29f9454")
    static let ramadanSecondTenNights = entry("ramadan-second-ten-nights", "b2580d39-140f-463b-a157-697997129b13")

    static let all: [Entry] = [
        surahIkhlas,
        tahleel,
        yaWahhabu,
        isthighfar,
        swalathAlFathimiyya,
        swalath,
        swalathSayyidina,
        swalathAlFatih,
        swalathAlNariyya,
        swalathForDebt,
        ramadanDhikr,
        ramadanFirstTenNights,
        ramadanSecondTenNights,
    ] + AsmaUlHusnaSeed.identities

    private static func entry(_ catalogKey: String, _ uuid: String) -> Entry {
        guard let id = UUID(uuidString: uuid) else {
            preconditionFailure("Invalid built-in dhikr UUID: \(uuid)")
        }
        return Entry(catalogKey: catalogKey, id: id)
    }
}
