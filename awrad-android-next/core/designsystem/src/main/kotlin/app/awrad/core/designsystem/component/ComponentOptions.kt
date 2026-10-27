package app.awrad.core.designsystem.component

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.vector.ImageVector

/*
 * The options components take: variants, sizes, modes and items.
 */

/** A filled button's colours (components.md, "Buttons"). */
public enum class AwradButtonVariant {
    /** The one main action of a screen: a `primary` fill, `onPrimary` content. */
    Main,

    /**
     * Other actions: a `secondaryContainer` fill, `onSecondaryContainer` content; on a `surface` area, a
     * `background` fill and `onSurface` content.
     */
    Secondary,

    /** Destructive confirmations, such as deleting the account: an `error` fill, `onError` content. */
    Error,
}

/** The two round button sizes (components.md, "Round button"). */
public enum class AwradRoundButtonSize {
    /** `roundButton` (48) with an `icon` (24): the + on My Goals. */
    Regular,

    /** `roundButtonSmall` (32) with an `iconSmall` (20), in a 48 touch target: the arrow on a collection tile. */
    Small,
}

/** A card's corners (components.md, "Card"). */
public enum class AwradCardSize {
    /** `card` (24): grouped content, such as Today's goals. */
    Card,

    /** `tile` (16): a list item, such as a goal on My Goals. */
    Tile,
}

/** How a list of option rows lets the user choose. */
public enum class AwradSelectionMode {
    /** One option: each row is announced as a radio button. */
    Single,

    /** Any number: each row is announced as a checkbox. */
    Multiple,
}

/**
 * One destination of the bottom bar: its [label] and its outline [icon] (from `AwradIcons`). The icon is the same
 * selected or not; the pill behind it shows the selection.
 */
@Immutable
public class AwradBottomBarItem(
    public val label: String,
    public val icon: ImageVector,
)
