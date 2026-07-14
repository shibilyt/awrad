package app.awrad.awrad_dhikrgoalstracker.data.database

import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import java.util.UUID

/** Generated from contracts/progress-model/v1/builtin-dhikrs.json. */
object BuiltInDhikrIds {
    data class Identity(val catalogKey: String, val id: AwradId)

    val SURAH_IKHLAS = identity("surah-ikhlas", "c88b9491-40ad-4b42-a5b8-e07c4b4d31ef")
    val TAHLEEL = identity("tahleel", "6f04f77e-dcb6-4a29-9dc5-fcd3649c2961")
    val YA_WAHHABU = identity("ya-wahhabu", "6abe90a8-abe2-4678-a4bf-3f14323c3e8d")
    val ISTHIGHFAR = identity("isthighfar", "3285e014-551b-46a4-aedc-8b6664b59bc7")
    val SWALATH_AL_FATHIMIYYA = identity("swalath-al-fathimiyya", "3daf6738-face-4afc-aeca-2ab62e57a5ea")
    val SWALATH = identity("swalath", "f2337cb6-6d46-45fb-a193-b9e231c97bbd")
    val SWALATH_SAYYIDINA = identity("swalath-sayyidina", "2a65a361-c499-41ff-b441-fc487714eacf")
    val SWALATH_AL_FATIH = identity("swalath-al-fatih", "c94229d6-6b24-4280-ae7c-1e618fc4f1fc")
    val SWALATH_AL_NARIYYA = identity("swalath-al-nariyya", "c2a59b7e-7e64-4bfe-9b0c-2d493fe01537")
    val SWALATH_FOR_DEBT = identity("swalath-for-debt", "9cbb04d9-fb07-4c8f-9235-49e2ce6fc818")
    val RAMADAN_DHIKR = identity("ramadan-dhikr", "82f55daf-9f23-4d53-a10e-b60a5c90b3c8")
    val RAMADAN_FIRST_TEN_NIGHTS = identity("ramadan-first-ten-nights", "cebda17e-2ed8-4bd6-b1f3-5dbbb29f9454")
    val RAMADAN_SECOND_TEN_NIGHTS = identity("ramadan-second-ten-nights", "b2580d39-140f-463b-a157-697997129b13")

    val all: List<Identity> = listOf(
        SURAH_IKHLAS, TAHLEEL, YA_WAHHABU, ISTHIGHFAR, SWALATH_AL_FATHIMIYYA,
        SWALATH, SWALATH_SAYYIDINA, SWALATH_AL_FATIH, SWALATH_AL_NARIYYA,
        SWALATH_FOR_DEBT, RAMADAN_DHIKR, RAMADAN_FIRST_TEN_NIGHTS,
        RAMADAN_SECOND_TEN_NIGHTS,
    ) + AsmaUlHusnaSeed.identities

    private fun identity(key: String, id: String) = Identity(key, UUID.fromString(id))
}
