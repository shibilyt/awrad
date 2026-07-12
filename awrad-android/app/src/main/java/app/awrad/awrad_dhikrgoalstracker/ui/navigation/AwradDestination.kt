package app.awrad.awrad_dhikrgoalstracker.ui.navigation

sealed class AwradDestination(val route: String) {
    data object Home : AwradDestination("home")
    data object Goals : AwradDestination("goals")
    data object Library : AwradDestination("library")
    data object Settings : AwradDestination("settings")
    data object Onboarding : AwradDestination("onboarding")
    data object CreateGoal : AwradDestination("create_goal?dhikrId={dhikrId}") {
        fun createRoute(dhikrId: Long? = null) =
            if (dhikrId != null) "create_goal?dhikrId=$dhikrId" else "create_goal"
    }
    data object Category : AwradDestination("category/{category}") {
        fun createRoute(category: String) = "category/$category"
    }
    data object Counting : AwradDestination("counting/{goalId}?slotId={slotId}") {
        fun createRoute(goalId: Long, slotId: Long? = null) =
            if (slotId != null) "counting/$goalId?slotId=$slotId" else "counting/$goalId"
    }
    data object GoalDetail : AwradDestination("goal_detail/{goalId}") {
        fun createRoute(goalId: Long) = "goal_detail/$goalId"
    }
    data object EditGoal : AwradDestination("edit_goal/{goalId}") {
        fun createRoute(goalId: Long) = "edit_goal/$goalId"
    }
    data object EditGoalSchedule : AwradDestination("edit_goal_schedule/{goalId}") {
        fun createRoute(goalId: Long) = "edit_goal_schedule/$goalId"
    }
    data object EditGoalReminders : AwradDestination("edit_goal_reminders/{goalId}") {
        fun createRoute(goalId: Long) = "edit_goal_reminders/$goalId"
    }
    data object DhikrDetail : AwradDestination("dhikr_detail/{dhikrId}") {
        fun createRoute(dhikrId: Long) = "dhikr_detail/$dhikrId"
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
    data object CreateDhikr : AwradDestination("create_dhikr")
    data object Community : AwradDestination("community")
    data object Login : AwradDestination("login")
    data object Signup : AwradDestination("signup")
    data object ForgotPassword : AwradDestination("forgot_password")
}
