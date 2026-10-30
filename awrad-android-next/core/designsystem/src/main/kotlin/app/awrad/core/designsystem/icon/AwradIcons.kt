// Generated from contracts/design-tokens/v1/icons.json. Don't edit by hand:
// regenerate with `./gradlew :core:designsystem:generateAwradIcons`. `verifyAwradIcons` fails the
// build when this file, the awrad_ic_* drawables and the contract differ.

package app.awrad.core.designsystem.icon

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.vectorResource
import app.awrad.core.designsystem.R

/**
 * The shared icons (contracts/design-tokens/v1/icons.json): Material Symbols Rounded, outline, weight
 * 300. Use one by name; never a platform icon set. The colour comes from the component (`Icon`'s
 * tint). Icons marked as mirrored flip in right-to-left layouts (`autoMirrored`).
 */
public object AwradIcons {
    /** Bottom bar: Home. */
    public val Home: ImageVector
        @Composable get() = ImageVector.vectorResource(R.drawable.awrad_ic_home)

    /** Bottom bar: Goals. */
    public val Goals: ImageVector
        @Composable get() = ImageVector.vectorResource(R.drawable.awrad_ic_goals)

    /** Bottom bar: Library. */
    public val Library: ImageVector
        @Composable get() = ImageVector.vectorResource(R.drawable.awrad_ic_library)

    /** Bottom bar: Community. */
    public val Community: ImageVector
        @Composable get() = ImageVector.vectorResource(R.drawable.awrad_ic_community)

    /** Round + button. */
    public val Add: ImageVector
        @Composable get() = ImageVector.vectorResource(R.drawable.awrad_ic_add)

    /** Round arrow on a tile. Flips in right-to-left layouts. */
    public val Forward: ImageVector
        @Composable get() = ImageVector.vectorResource(R.drawable.awrad_ic_forward)

    /** Back button. Flips in right-to-left layouts. */
    public val Back: ImageVector
        @Composable get() = ImageVector.vectorResource(R.drawable.awrad_ic_back)

    /** Three-dot menu. */
    public val More: ImageVector
        @Composable get() = ImageVector.vectorResource(R.drawable.awrad_ic_more)

    /** Selected option row, checkbox tick. */
    public val Check: ImageVector
        @Composable get() = ImageVector.vectorResource(R.drawable.awrad_ic_check)

    /** Notifications. */
    public val Notifications: ImageVector
        @Composable get() = ImageVector.vectorResource(R.drawable.awrad_ic_notifications)

    /** Show password. */
    public val Show: ImageVector
        @Composable get() = ImageVector.vectorResource(R.drawable.awrad_ic_show)

    /** Hide password. */
    public val Hide: ImageVector
        @Composable get() = ImageVector.vectorResource(R.drawable.awrad_ic_hide)

    /** Close a sheet or dialog. */
    public val Close: ImageVector
        @Composable get() = ImageVector.vectorResource(R.drawable.awrad_ic_close)

    /** Expand a section (rotates 180° when open). */
    public val Expand: ImageVector
        @Composable get() = ImageVector.vectorResource(R.drawable.awrad_ic_expand)

    /** Streak. */
    public val Streak: ImageVector
        @Composable get() = ImageVector.vectorResource(R.drawable.awrad_ic_streak)

    /** Signed-in devices. */
    public val Devices: ImageVector
        @Composable get() = ImageVector.vectorResource(R.drawable.awrad_ic_devices)

    /** A phone; data kept on this device. */
    public val Phone: ImageVector
        @Composable get() = ImageVector.vectorResource(R.drawable.awrad_ic_phone)

    /** Language setting. */
    public val Language: ImageVector
        @Composable get() = ImageVector.vectorResource(R.drawable.awrad_ic_language)

    /** Email address, change email. */
    public val Email: ImageVector
        @Composable get() = ImageVector.vectorResource(R.drawable.awrad_ic_email)

    /** Password, change password. */
    public val Password: ImageVector
        @Composable get() = ImageVector.vectorResource(R.drawable.awrad_ic_password)

    /** Delete account and other destructive actions. */
    public val Delete: ImageVector
        @Composable get() = ImageVector.vectorResource(R.drawable.awrad_ic_delete)

    /** Trailing chevron on a row that opens a page. Flips in right-to-left layouts. */
    public val Chevron: ImageVector
        @Composable get() = ImageVector.vectorResource(R.drawable.awrad_ic_chevron)

    /** Error message beside a form or feedback line. */
    public val Error: ImageVector
        @Composable get() = ImageVector.vectorResource(R.drawable.awrad_ic_error)

    /** Play audio. */
    public val Play: ImageVector
        @Composable get() = ImageVector.vectorResource(R.drawable.awrad_ic_play)

    /** Pause audio. */
    public val Pause: ImageVector
        @Composable get() = ImageVector.vectorResource(R.drawable.awrad_ic_pause)

    /** Search field. */
    public val Search: ImageVector
        @Composable get() = ImageVector.vectorResource(R.drawable.awrad_ic_search)

    /** Settings: Practice settings. */
    public val Practice: ImageVector
        @Composable get() = ImageVector.vectorResource(R.drawable.awrad_ic_practice)

    /** Practice settings: Use my location. */
    public val Location: ImageVector
        @Composable get() = ImageVector.vectorResource(R.drawable.awrad_ic_location)

    /** Every icon by its name in icons.json, in the contract's order (the component gallery). */
    public val all: List<Pair<String, ImageVector>>
        @Composable get() = listOf(
            "home" to Home,
            "goals" to Goals,
            "library" to Library,
            "community" to Community,
            "add" to Add,
            "forward" to Forward,
            "back" to Back,
            "more" to More,
            "check" to Check,
            "notifications" to Notifications,
            "show" to Show,
            "hide" to Hide,
            "close" to Close,
            "expand" to Expand,
            "streak" to Streak,
            "devices" to Devices,
            "phone" to Phone,
            "language" to Language,
            "email" to Email,
            "password" to Password,
            "delete" to Delete,
            "chevron" to Chevron,
            "error" to Error,
            "play" to Play,
            "pause" to Pause,
            "search" to Search,
            "practice" to Practice,
            "location" to Location,
        )
}
