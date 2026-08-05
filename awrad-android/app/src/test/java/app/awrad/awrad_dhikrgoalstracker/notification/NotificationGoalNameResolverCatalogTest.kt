package app.awrad.awrad_dhikrgoalstracker.notification

import app.awrad.awrad_dhikrgoalstracker.data.database.BuiltInDhikrs
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class NotificationGoalNameResolverCatalogTest {
    @Test
    fun `every current built-in key is mapped or intentionally persisted`() {
        val builtInKeys = BuiltInDhikrs.dhikrs.mapNotNull { it.catalogKey }.toSet()
        val mappedKeys = AndroidNotificationGoalNameResolver.resourceIdsByCatalogKey.keys
        val intentionallyPersistedKeys = builtInKeys - mappedKeys

        assertTrue(mappedKeys.all { it in builtInKeys })
        assertEquals(builtInKeys, mappedKeys + intentionallyPersistedKeys)
        assertEquals(13, mappedKeys.size)
        assertEquals(100, intentionallyPersistedKeys.size)
    }

    @Test
    fun `unknown catalog key has no resource mapping`() {
        assertNull(AndroidNotificationGoalNameResolver.resourceIdFor("unknown-catalog-key"))
    }
}
