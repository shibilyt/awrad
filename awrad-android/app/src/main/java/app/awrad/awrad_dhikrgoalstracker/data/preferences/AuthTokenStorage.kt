package app.awrad.awrad_dhikrgoalstracker.data.preferences

interface AuthTokenStorage {
    fun getString(key: String): String?
    fun putString(key: String, value: String)
    fun remove(key: String)
}
