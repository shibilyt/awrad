package app.awrad.core.data.sync

import app.awrad.core.data.profile.ProfileManager

/**
 * What the app shell runs: [followAccount] for the app's whole life (sign-ins and sign-outs move between local
 * profiles), and [syncWhileOpen] while the app is started (sync at start, after edits and every 5 minutes).
 */
public class SyncLifecycle internal constructor(
    private val profiles: ProfileManager,
    private val scheduler: SyncScheduler,
) {
    public suspend fun followAccount() {
        profiles.run()
    }

    public suspend fun syncWhileOpen() {
        scheduler.runWhileOpen()
    }
}
