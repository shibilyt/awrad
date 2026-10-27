// Generated from contracts/design-tokens/v1/spacing.json. Don't edit by hand:
// regenerate with `./gradlew :core:designsystem:generateAwradTokens`. `verifyAwradTokens` fails the
// build when this file and the contract differ.
@file:Suppress("MagicNumber")

package app.awrad.core.designsystem.theme

import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * Spacing: the scale (`none` to `xl5`; the contract's `2xl` is `xl2`) and the named roles. Prefer a
 * role. Read it through `AwradTheme.spacing`.
 */
public object AwradSpacing {
    /** 0 */
    public val none: Dp = 0.dp

    /** 2 */
    public val xxs: Dp = 2.dp

    /** 4 */
    public val xs: Dp = 4.dp

    /** 8 */
    public val sm: Dp = 8.dp

    /** 12 */
    public val md: Dp = 12.dp

    /** 16 */
    public val lg: Dp = 16.dp

    /** 20 */
    public val xl: Dp = 20.dp

    /** 24 */
    public val xl2: Dp = 24.dp

    /** 32 */
    public val xl3: Dp = 32.dp

    /** 40 */
    public val xl4: Dp = 40.dp

    /** 48 */
    public val xl5: Dp = 48.dp

    /** Left and right margin of a screen: `xl`, 20. */
    public val pageMargin: Dp = xl

    /** Between sections and cards on a screen: `xl`, 20. */
    public val sectionGap: Dp = xl

    /** Inside a card: `lg`, 16. */
    public val cardPadding: Dp = lg

    /** Between rows or items in a group: `md`, 12. */
    public val rowGap: Dp = md

    /** Between an icon and its text, or small inline items: `sm`, 8. */
    public val inlineGap: Dp = sm
}

/** Standard sizes. Read them through `AwradTheme.sizes`. */
public object AwradSizes {
    /** Minimum size of anything tappable: 48. */
    public val touchTarget: Dp = 48.dp

    /** Height of a standard row (goal row, settings row): 56. */
    public val listRow: Dp = 56.dp

    /** Standard icon: 24. */
    public val icon: Dp = 24.dp

    /** Small icon inside text or chips: 20. */
    public val iconSmall: Dp = 20.dp

    /** Progress ring in a goal row: 36. */
    public val ringSmall: Dp = 36.dp

    /** Stroke of small progress rings: 4. */
    public val ringStroke: Dp = 4.dp

    /** Height of buttons and text fields: 56. */
    public val control: Dp = 56.dp

    /** The Awrad logo on welcome and sign-in screens: 148. */
    public val logo: Dp = 148.dp

    /** Widest a page's content column grows (web, tablets): 448. */
    public val contentMaxWidth: Dp = 448.dp

    /** Widest a dialog grows (web, tablets): 384. */
    public val dialogMaxWidth: Dp = 384.dp

    /** Height of the top bar: 56. */
    public val topBar: Dp = 56.dp

    /** Height of the floating bottom bar: 72. */
    public val navBar: Dp = 72.dp

    /** Width of the selected tab's pill: 56. */
    public val navPillWidth: Dp = 56.dp

    /** Height of the selected tab's pill: 32. */
    public val navPillHeight: Dp = 32.dp

    /** Round icon button: the + on My Goals: 48. */
    public val roundButton: Dp = 48.dp

    /** Small round button inside a tile: the collection arrow: 32. */
    public val roundButtonSmall: Dp = 32.dp

    /** Leading circle in an option row (the language 'Aa'): 36. */
    public val avatar: Dp = 36.dp

    /** A checkbox's box: 20. */
    public val checkbox: Dp = 20.dp

    /** Switch track width: 52. */
    public val switchWidth: Dp = 52.dp

    /** Switch track height: 32. */
    public val switchHeight: Dp = 32.dp

    /** Switch thumb: 24. */
    public val switchThumb: Dp = 24.dp

    /** A square in the onboarding step indicator: 8. */
    public val stepDot: Dp = 8.dp

    /** The bar under the selected segmented pill: 24. */
    public val tabIndicatorWidth: Dp = 24.dp

    /** The bar under the selected segmented pill: 4. */
    public val tabIndicatorHeight: Dp = 4.dp

    /** Width and height of a collection tile (Home, Library): 128. */
    public val collectionTile: Dp = 128.dp
}
