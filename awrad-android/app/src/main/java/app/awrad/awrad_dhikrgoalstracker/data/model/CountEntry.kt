package app.awrad.awrad_dhikrgoalstracker.data.model

data class CountEntry(
    val id: AwradId = newAwradId(),
    val goalId: AwradId,
    val slotId: AwradId,
    val count: Long,
    val date: String,
    val lastUpdated: Long,
)
