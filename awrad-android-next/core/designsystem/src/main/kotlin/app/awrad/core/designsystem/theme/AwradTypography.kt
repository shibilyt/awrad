package app.awrad.core.designsystem.theme

import androidx.compose.material3.Typography

/*
 * Material's type slots, mapped onto the shared styles (AwradType) so Material components inside the app use
 * them too. Screens name an AwradType style (AwradTheme.type) instead of a Material slot. Kept apart from Type.kt
 * so the fonts initialise before AwradType reads them.
 */

/**
 * Every slot is a shared style: display is `counter`; headlines and title large are `title` (dialog titles);
 * title medium `cardTitle`; title small `sectionTitle`; body large `body` (text fields, list rows); body medium
 * `bodySmall` (dialog text, supporting text in rows); body small `caption` (a field's hint); label large `label`
 * (text buttons); label medium and small `navLabel` (the navigation bar).
 */
internal val AwradTypography: Typography = Typography(
    displayLarge = AwradType.counter,
    displayMedium = AwradType.counter,
    displaySmall = AwradType.counter,
    headlineLarge = AwradType.title,
    headlineMedium = AwradType.title,
    headlineSmall = AwradType.title,
    titleLarge = AwradType.title,
    titleMedium = AwradType.cardTitle,
    titleSmall = AwradType.sectionTitle,
    bodyLarge = AwradType.body,
    bodyMedium = AwradType.bodySmall,
    bodySmall = AwradType.caption,
    labelLarge = AwradType.label,
    labelMedium = AwradType.navLabel,
    labelSmall = AwradType.navLabel,
)
