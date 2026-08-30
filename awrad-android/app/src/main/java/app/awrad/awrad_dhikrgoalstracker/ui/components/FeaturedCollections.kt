package app.awrad.awrad_dhikrgoalstracker.ui.components

import androidx.annotation.DrawableRes
import androidx.annotation.StringRes
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory
import app.awrad.awrad_dhikrgoalstracker.ui.screens.library.LibraryFeaturedCollection
import app.awrad.awrad_dhikrgoalstracker.ui.theme.isAwradDarkTheme

enum class FeaturedCollectionTone {
    YourDhikrs,
    AsmaUlHusna,
    Daily,
    Swalaths,
    Dhikrs,
    Evening,
    Prayer,
}

data class FeaturedCollectionUiModel(
    val title: String,
    val collection: LibraryFeaturedCollection,
    val count: Int,
    val tone: FeaturedCollectionTone,
)

@Composable
fun rememberFeaturedCollections(
    categoryCounts: Map<DhikrCategory, Int>,
    customCount: Int = 0,
): List<FeaturedCollectionUiModel> {
    return listOf(
        FeaturedCollectionUiModel(
            title = stringResource(R.string.collection_your_dhikrs),
            collection = LibraryFeaturedCollection.YOUR_DHIKRS,
            count = LibraryFeaturedCollection.YOUR_DHIKRS.countFrom(categoryCounts, customCount),
            tone = FeaturedCollectionTone.YourDhikrs,
        ),
        FeaturedCollectionUiModel(
            title = stringResource(R.string.category_asma_ul_husna),
            collection = LibraryFeaturedCollection.ASMA_UL_HUSNA,
            count = LibraryFeaturedCollection.ASMA_UL_HUSNA.countFrom(categoryCounts, customCount),
            tone = FeaturedCollectionTone.AsmaUlHusna,
        ),
        FeaturedCollectionUiModel(
            title = stringResource(R.string.collection_daily_essentials),
            collection = LibraryFeaturedCollection.DAILY_ESSENTIALS,
            count = LibraryFeaturedCollection.DAILY_ESSENTIALS.countFrom(categoryCounts, customCount),
            tone = FeaturedCollectionTone.Daily,
        ),
        FeaturedCollectionUiModel(
            title = stringResource(R.string.collection_swalaths),
            collection = LibraryFeaturedCollection.SWALATHS,
            count = LibraryFeaturedCollection.SWALATHS.countFrom(categoryCounts, customCount),
            tone = FeaturedCollectionTone.Swalaths,
        ),
        FeaturedCollectionUiModel(
            title = stringResource(R.string.collection_dhikrs),
            collection = LibraryFeaturedCollection.DHIKRS,
            count = LibraryFeaturedCollection.DHIKRS.countFrom(categoryCounts, customCount),
            tone = FeaturedCollectionTone.Dhikrs,
        ),
        FeaturedCollectionUiModel(
            title = stringResource(R.string.collection_evening_dhikrs),
            collection = LibraryFeaturedCollection.EVENING_DHIKRS,
            count = LibraryFeaturedCollection.EVENING_DHIKRS.countFrom(categoryCounts, customCount),
            tone = FeaturedCollectionTone.Evening,
        ),
        FeaturedCollectionUiModel(
            title = stringResource(R.string.collection_after_prayer),
            collection = LibraryFeaturedCollection.AFTER_PRAYER,
            count = LibraryFeaturedCollection.AFTER_PRAYER.countFrom(categoryCounts, customCount),
            tone = FeaturedCollectionTone.Prayer,
        ),
    )
}

@Composable
fun FeaturedCollectionsSection(
    categoryCounts: Map<DhikrCategory, Int>,
    onCollectionClick: (LibraryFeaturedCollection) -> Unit,
    modifier: Modifier = Modifier,
    onViewAll: (() -> Unit)? = null,
    customCount: Int = 0,
    isLoading: Boolean = false,
    @StringRes titleRes: Int = R.string.featured_collections,
) {
    val collections = rememberFeaturedCollections(categoryCounts, customCount)
        .filter { it.count > 0 }

    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = stringResource(titleRes),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface,
            )
            if (onViewAll != null) {
                Text(
                    text = stringResource(R.string.home_view_all),
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.primary,
                    modifier = Modifier
                        .clip(RoundedCornerShape(12.dp))
                        .clickable { onViewAll() }
                        .padding(horizontal = 8.dp, vertical = 6.dp),
                )
            }
        }

        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            contentPadding = PaddingValues(horizontal = 20.dp),
        ) {
            if (isLoading) {
                items(3) {
                    RitualSkeleton(
                        modifier = Modifier
                            .width(154.dp)
                            .height(154.dp),
                        shape = RoundedCornerShape(22.dp),
                    )
                }
            } else {
                items(collections, key = { it.collection }) { collection ->
                    FeaturedCollectionCard(
                        collection = collection,
                        onClick = { onCollectionClick(collection.collection) },
                    )
                }
            }
        }
    }
}

@Composable
private fun FeaturedCollectionCard(
    collection: FeaturedCollectionUiModel,
    onClick: () -> Unit,
) {
    val isDark = isAwradDarkTheme()
    val shape = RoundedCornerShape(22.dp)

    Box(
        modifier = Modifier
            .width(154.dp)
            .height(154.dp)
            .clip(shape)
            .background(MaterialTheme.colorScheme.surfaceContainerHigh)
            .clickable { onClick() },
    ) {
        Image(
            painter = painterResource(collectionImageRes(collection.tone, isDark)),
            contentDescription = null,
            modifier = Modifier.fillMaxSize(),
            contentScale = ContentScale.Crop,
        )
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(collectionScrim(isDark)),
        )
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(14.dp),
        ) {
            Text(
                text = collection.title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = collectionTitleColor(isDark),
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = stringResource(R.string.collection_count, collection.count),
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
            )
            Spacer(modifier = Modifier.weight(1f))
            Surface(
                modifier = Modifier
                    .align(Alignment.End)
                    .size(30.dp),
                shape = CircleShape,
                color = collectionActionColor(isDark),
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                        contentDescription = null,
                        tint = Color.White,
                        modifier = Modifier.size(19.dp),
                    )
                }
            }
        }
    }
}

@DrawableRes
private fun collectionImageRes(
    tone: FeaturedCollectionTone,
    isDark: Boolean,
): Int = when (tone) {
    FeaturedCollectionTone.YourDhikrs -> if (isDark) {
        R.drawable.collection_your_dhikrs_dark
    } else {
        R.drawable.collection_your_dhikrs_light
    }
    FeaturedCollectionTone.Dhikrs -> if (isDark) {
        R.drawable.collection_dhikrs_dark
    } else {
        R.drawable.collection_dhikrs_light
    }
    FeaturedCollectionTone.AsmaUlHusna -> if (isDark) {
        R.drawable.collection_asma_ul_husna_dark
    } else {
        R.drawable.collection_asma_ul_husna_light
    }
    FeaturedCollectionTone.Daily -> if (isDark) {
        R.drawable.collection_daily_essentials_dark
    } else {
        R.drawable.collection_daily_essentials_light
    }
    FeaturedCollectionTone.Swalaths -> if (isDark) {
        R.drawable.collection_swalaths_dark
    } else {
        R.drawable.collection_swalaths_light
    }
    FeaturedCollectionTone.Evening -> if (isDark) {
        R.drawable.collection_evening_dhikrs_dark
    } else {
        R.drawable.collection_evening_dhikrs_light
    }
    FeaturedCollectionTone.Prayer -> if (isDark) {
        R.drawable.collection_after_prayer_dark
    } else {
        R.drawable.collection_after_prayer_light
    }
}

private fun collectionScrim(isDark: Boolean): Brush =
    Brush.verticalGradient(
        colors = if (isDark) {
            listOf(
                Color(0x99000000),
                Color(0x44000000),
                Color(0x11000000),
            )
        } else {
            listOf(
                Color(0xB8FFFFFF),
                Color(0x55FFFFFF),
                Color(0x00FFFFFF),
            )
        },
    )

private fun collectionTitleColor(
    isDark: Boolean,
): Color = if (isDark) {
    Color(0xFFF8FAF4)
} else {
    Color(0xFF103C1D)
}

private fun collectionActionColor(
    isDark: Boolean,
): Color = if (isDark) {
    Color(0xE60F5B38)
} else {
    Color(0xE62F7D3F)
}
