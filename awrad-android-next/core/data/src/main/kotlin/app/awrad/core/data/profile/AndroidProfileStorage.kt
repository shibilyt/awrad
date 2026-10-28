package app.awrad.core.data.profile

import android.content.Context
import androidx.room.Room
import app.awrad.core.database.AwradDatabase
import app.awrad.core.domain.AwradId
import java.io.File

/** Each profile is its own database file and its own folder under the app's private files. */
internal class AndroidProfileStorage(private val context: Context) : ProfileStorage {

    override fun open(profileId: AwradId): AwradDatabase =
        Room.databaseBuilder(context, AwradDatabase::class.java, AwradDatabase.fileName(profileId.value)).build()

    override fun filesDir(profileId: AwradId): File = File(context.filesDir, "profiles/${profileId.value}")

    override fun release(database: AwradDatabase) {
        database.close()
    }

    override fun delete(profileId: AwradId) {
        context.deleteDatabase(AwradDatabase.fileName(profileId.value))
        filesDir(profileId).deleteRecursively()
    }
}
