package app.awrad.awrad_dhikrgoalstracker.data.model

data class CountEntry(
    val id: Long = 0,
    val goalId: Long,
    val slotId: Long?,
    val count: Long,
    val date: String,
    val lastUpdated: Long,
)
