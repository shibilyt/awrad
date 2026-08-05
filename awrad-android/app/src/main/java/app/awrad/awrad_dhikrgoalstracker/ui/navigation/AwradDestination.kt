package app.awrad.awrad_dhikrgoalstracker.ui.navigation

import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId

sealed class AwradDestination(val route: String) {
    data object Home : AwradDestination("home")
    data object Goals : AwradDestination("goals")
    data object Library : AwradDestination("library")
    data object Settings : AwradDestination("settings")
    data object Onboarding : AwradDestination("onboarding")
    data object CreateGoal : AwradDestination("create_goal?dhikrId={dhikrId}") {
        fun createRoute(dhikrId: AwradId? = null) =
            if (dhikrId != null) "create_goal?dhikrId=$dhikrId" else "create_goal"
    }
    data object Category : AwradDestination("category/{category}") {
        fun createRoute(category: String) = "category/$category"
    }
    data object Counting : AwradDestination("counting/{goalId}?slotId={slotId}") {
        fun createRoute(goalId: AwradId, slotId: AwradId? = null) =
            if (slotId != null) "counting/$goalId?slotId=$slotId" else "counting/$goalId"
    }
    data object GoalDetail : AwradDestination("goal_detail/{goalId}") {
        fun createRoute(goalId: AwradId) = "goal_detail/$goalId"
    }
    data object EditGoal : AwradDestination("edit_goal/{goalId}") {
        fun createRoute(goalId: AwradId) = "edit_goal/$goalId"
    }
    data object EditGoalSchedule : AwradDestination("edit_goal_schedule/{goalId}") {
        fun createRoute(goalId: AwradId) = "edit_goal_schedule/$goalId"
    }
    data object EditGoalReminders : AwradDestination("edit_goal_reminders/{goalId}") {
        fun createRoute(goalId: AwradId) = "edit_goal_reminders/$goalId"
    }
    data object DhikrDetail : AwradDestination("dhikr_detail/{dhikrId}") {
        fun createRoute(dhikrId: AwradId) = "dhikr_detail/$dhikrId"
    }
    data object QuranDhikrReader : AwradDestination("quran_reader/{dhikrId}?goalId={goalId}&slotId={slotId}") {
        fun createRoute(dhikrId: AwradId, goalId: AwradId? = null, slotId: AwradId? = null): String {
            val query = buildList {
                goalId?.let { add("goalId=$it") }
                slotId?.let { add("slotId=$it") }
            }
            return "quran_reader/$dhikrId" + query.takeIf { it.isNotEmpty() }
                ?.joinToString(separator = "&", prefix = "?").orEmpty()
        }
    }
    data object WirdList : AwradDestination("wird_list")
    data object WirdDetail : AwradDestination("wird_detail/{wirdId}") {
        fun createRoute(wirdId: String) = "wird_detail/$wirdId"
    }
    data object WirdReader : AwradDestination("wird_reader/{wirdId}/{partId}") {
        fun createRoute(wirdId: String, partId: String) = "wird_reader/$wirdId/$partId"
    }
    data object WirdCreate : AwradDestination("wird_create")
    data object WirdEdit : AwradDestination("wird_edit/{wirdId}") {
        fun createRoute(wirdId: String) = "wird_edit/$wirdId"
    }
    data object CreateDhikr : AwradDestination("create_dhikr?dhikrId={dhikrId}") {
        fun createRoute(dhikrId: AwradId? = null) =
            if (dhikrId != null) "create_dhikr?dhikrId=$dhikrId" else "create_dhikr"
    }
    data object ManageTags : AwradDestination("manage_tags/{dhikrId}") {
        fun createRoute(dhikrId: AwradId) = "manage_tags/$dhikrId"
    }
    data object Community : AwradDestination("community")
    data object CommunityStats : AwradDestination("community/stats")
    data object CommunityChallenges : AwradDestination("community/challenges")
    data object CommunityCircles : AwradDestination("community/circles")
    data object CommunitySaved : AwradDestination("community/saved")
    data object CommunityProfile : AwradDestination("community/profile")
    data object CommunityPostDetail : AwradDestination("community/post")
    data object CommunityMessages : AwradDestination("community/messages")
    data object CommunityNotifications : AwradDestination("community/notifications")
    data object Login : AwradDestination("login?email={email}&origin={origin}") {
        fun createRoute(email: String? = null, origin: String? = null): String {
            val query = buildList {
                email?.takeIf { it.isNotBlank() }?.let { add("email=${android.net.Uri.encode(it)}") }
                origin?.takeIf { it.isNotBlank() }?.let { add("origin=${android.net.Uri.encode(it)}") }
            }
            return "login" + query.takeIf { it.isNotEmpty() }
                ?.joinToString(separator = "&", prefix = "?").orEmpty()
        }
    }
    data object Signup : AwradDestination("signup")
    data object VerifyEmail : AwradDestination("verify_email?token={token}") {
        fun createRoute(token: String? = null) =
            token?.takeIf { it.isNotBlank() }?.let { "verify_email?token=${android.net.Uri.encode(it)}" }
                ?: "verify_email"
    }
    data object ForgotPassword : AwradDestination("forgot_password")
}
