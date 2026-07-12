package app.awrad.awrad_dhikrgoalstracker.ui.navigation

import androidx.annotation.DrawableRes
import androidx.annotation.StringRes
import app.awrad.awrad_dhikrgoalstracker.R

data class BottomNavItem(
    @StringRes val labelResId: Int,
    val route: String,
    @DrawableRes val selectedIcon: Int,
    @DrawableRes val unselectedIcon: Int,
)

val bottomNavItems = listOf(
    BottomNavItem(
        labelResId = R.string.nav_home,
        route = AwradDestination.Home.route,
        selectedIcon = R.drawable.home_24_rounded_filled,
        unselectedIcon = R.drawable.rounded_home_24,
    ),
    BottomNavItem(
        labelResId = R.string.nav_goals,
        route = AwradDestination.Goals.route,
        selectedIcon = R.drawable.rounded_format_list_bulleted_24,
        unselectedIcon = R.drawable.rounded_format_list_bulleted_24,
    ),
    BottomNavItem(
        labelResId = R.string.nav_library,
        route = AwradDestination.Library.route,
        selectedIcon = R.drawable.rounded_library_music_24,
        unselectedIcon = R.drawable.rounded_library_music_24,
    ),
    BottomNavItem(
        labelResId = R.string.nav_community,
        route = AwradDestination.Community.route,
        selectedIcon = R.drawable.rounded_groups_24_filled,
        unselectedIcon = R.drawable.rounded_groups_24,
    ),
)
