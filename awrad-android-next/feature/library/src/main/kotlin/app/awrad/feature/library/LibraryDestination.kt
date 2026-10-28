package app.awrad.feature.library

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.navigation.NavGraphBuilder
import androidx.navigation.compose.composable
import androidx.navigation.toRoute
import app.awrad.core.designsystem.motion.AwradPage
import kotlinx.serialization.Serializable

/**
 * The library's pages pushed over the main tabs: one collection's dhikrs, the user's own dhikrs, one dhikr, the
 * custom dhikr editor and the tags. The Library tab itself ([LibraryTab]) and Home's featured row
 * ([FeaturedCollections]) live inside the app's tab shell, so they're composables rather than destinations.
 */
@Serializable
public sealed interface LibraryDestination {
    /** The dhikrs of the collection with catalog key [key], in order. */
    @Serializable
    public data class Collection(public val key: String) : LibraryDestination

    /** "Your dhikrs": the user's own dhikrs, newest first. */
    @Serializable
    public data object YourDhikrs : LibraryDestination

    /** The dhikr with ID [id], built-in or the user's own. */
    @Serializable
    public data class Dhikr(public val id: String) : LibraryDestination

    /** The custom dhikr editor: a new dhikr when [id] is null, else the one with that ID. */
    @Serializable
    public data class Editor(public val id: String? = null) : LibraryDestination

    /** "Manage tags": create, rename and delete tags. */
    @Serializable
    public data object ManageTags : LibraryDestination
}

/**
 * The feature's pages: [onNavigate] opens another library page, [onBack] leaves one.
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
    composable<LibraryDestination.YourDhikrs> { entry ->
        AwradPage(scope = this, key = entry) {
            YourDhikrsRoute(onNavigate = onNavigate, onBack = onBack)
        }
    }
    composable<LibraryDestination.Dhikr> { entry ->
        val id = entry.toRoute<LibraryDestination.Dhikr>().id
        AwradPage(scope = this, key = entry) {
            DhikrDetailRoute(dhikrId = id, onNavigate = onNavigate, onBack = onBack)
        }
    }
    composable<LibraryDestination.Editor> { entry ->
        val id = entry.toRoute<LibraryDestination.Editor>().id
        AwradPage(scope = this, key = entry) { CustomDhikrEditorRoute(dhikrId = id, onClose = onBack) }
    }
    composable<LibraryDestination.ManageTags> { entry ->
        AwradPage(scope = this, key = entry) { ManageTagsRoute(onBack = onBack) }
    }
}

/**
 * The Library tab: a large "Library" header with a + to create a dhikr, search, the tag filter, the collection
 * tiles (with "Your dhikrs" first once there are any) and every dhikr; while searching or filtering, only the
 * results. Tapping a tile or a dhikr goes through [onNavigate].
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
