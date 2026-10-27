package app.awrad.feature.library

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.navigation.NavGraphBuilder
import androidx.navigation.compose.composable
import androidx.navigation.toRoute
import app.awrad.core.designsystem.motion.AwradPage
import kotlinx.serialization.Serializable

/**
 * The library's pages pushed over the main tabs: one collection's dhikrs, or one dhikr. The Library tab itself
 * ([LibraryTab]) and Home's featured row ([FeaturedCollections]) live inside the app's tab shell, so they're
 * composables rather than destinations.
 */
@Serializable
public sealed interface LibraryDestination {
    /** The dhikrs of the collection with catalog key [key], in order. */
    @Serializable
    public data class Collection(public val key: String) : LibraryDestination

    /** The dhikr with catalog key [key]. */
    @Serializable
    public data class Dhikr(public val key: String) : LibraryDestination
}

/**
 * The feature's pages: [onNavigate] opens another library page (a collection's dhikr), [onBack] leaves one.
 */
public fun NavGraphBuilder.libraryScreen(onNavigate: (LibraryDestination) -> Unit, onBack: () -> Unit) {
    composable<LibraryDestination.Collection> { entry ->
        val key = entry.toRoute<LibraryDestination.Collection>().key
        AwradPage(scope = this, key = entry) {
            CollectionRoute(
                collectionKey = key,
                onOpenDhikr = { onNavigate(LibraryDestination.Dhikr(it)) },
                onBack = onBack,
            )
        }
    }
    composable<LibraryDestination.Dhikr> { entry ->
        val key = entry.toRoute<LibraryDestination.Dhikr>().key
        AwradPage(scope = this, key = entry) { DhikrDetailRoute(dhikrKey = key, onBack = onBack) }
    }
}

/**
 * The Library tab: a large "Library" header, search, the collection tiles and every dhikr; while searching, only
 * the results. Tapping a tile or a dhikr goes through [onNavigate].
 */
@Composable
public fun LibraryTab(onNavigate: (LibraryDestination) -> Unit, modifier: Modifier = Modifier) {
    LibraryRoute(onNavigate = onNavigate, modifier = modifier)
}

/**
 * Home's "Featured dhikr collections": the section title with "View all" ([onViewAll], the Library tab), then a
 * row of collection tiles that open their collection through [onNavigate].
 */
@Composable
public fun FeaturedCollections(
    onNavigate: (LibraryDestination) -> Unit,
    onViewAll: () -> Unit,
    modifier: Modifier = Modifier,
) {
    FeaturedCollectionsRoute(onNavigate = onNavigate, onViewAll = onViewAll, modifier = modifier)
}
