package app.awrad.awrad_dhikrgoalstracker.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBarDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController
import androidx.navigation.compose.currentBackStackEntryAsState
import app.awrad.awrad_dhikrgoalstracker.ui.navigation.BottomNavItem
import app.awrad.awrad_dhikrgoalstracker.ui.navigation.bottomNavItems
import app.awrad.awrad_dhikrgoalstracker.ui.navigation.navigateTopLevelSafely

@Composable
fun AwradBottomBar(
    navController: NavController,
    modifier: Modifier = Modifier,
) {
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route
    val navBarBottomInset = WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
    val scrimColor = MaterialTheme.colorScheme.background
    val colorScheme = MaterialTheme.colorScheme
    val isDark = colorScheme.background.luminance() < 0.2f
    val colors = BottomBarColors(
        container = if (isDark) {
            NavigationBarDefaults.containerColor
        } else {
            colorScheme.surfaceContainerLow
        },
        selectedPill = colorScheme.secondaryContainer,
        selectedContent = colorScheme.primary,
        selectedLabel = colorScheme.primary,
        unselectedContent = colorScheme.onSurfaceVariant,
    )

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(navBarBottomInset + 120.dp),
        contentAlignment = Alignment.BottomCenter,
    ) {
        Box(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .height(navBarBottomInset + 48.dp)
                .background(
                    Brush.verticalGradient(
                        colorStops = arrayOf(
                            0f to Color.Transparent,
                            0.36f to scrimColor.copy(alpha = 0.72f),
                            0.68f to scrimColor,
                            1f to scrimColor,
                        ),
                    ),
                ),
        )
        Surface(
            modifier = Modifier
                .fillMaxWidth()
                .padding(
                    start = 20.dp,
                    top = 12.dp,
                    end = 20.dp,
                    bottom = navBarBottomInset,
                ),
            shape = RoundedCornerShape(28.dp),
            color = colors.container,
            shadowElevation = 3.dp,
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 10.dp),
                horizontalArrangement = Arrangement.SpaceEvenly,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                bottomNavItems.forEach { item ->
                    val selected = currentRoute == item.route
                    AwradNavItem(
                        item = item,
                        selected = selected,
                        colors = colors,
                        onClick = {
                            if (currentRoute != item.route) {
                                navController.navigateTopLevelSafely(item.route)
                            }
                        },
                    )
                }
            }
        }
    }
}

@Composable
private fun RowScope.AwradNavItem(
    item: BottomNavItem,
    selected: Boolean,
    colors: BottomBarColors,
    onClick: () -> Unit,
) {
    val iconColor by animateColorAsState(
        targetValue = if (selected) colors.selectedContent else colors.unselectedContent,
        animationSpec = tween(durationMillis = 150),
        label = "iconColor",
    )
    val textColor by animateColorAsState(
        targetValue = if (selected) colors.selectedLabel else colors.unselectedContent,
        animationSpec = tween(durationMillis = 150),
        label = "textColor",
    )

    // Spring-bounce scale: when selected, overshoots 1.12 then settles — creating the
    // scale-up → scale-down micro-animation naturally via medium bouncy spring.
    val iconScale by animateFloatAsState(
        targetValue = if (selected) 1.12f else 1f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessMedium,
        ),
        label = "iconScale",
    )

    // Pill alpha + scale driven by animateFloat to avoid ColumnScope/AnimatedVisibility clash
    val pillAlpha by animateFloatAsState(
        targetValue = if (selected) 1f else 0f,
        animationSpec = tween(durationMillis = 150),
        label = "pillAlpha",
    )
    val pillScale by animateFloatAsState(
        targetValue = if (selected) 1f else 0.7f,
        animationSpec = spring(
            dampingRatio = Spring.DampingRatioMediumBouncy,
            stiffness = Spring.StiffnessLow,
        ),
        label = "pillScale",
    )

    Column(
        modifier = Modifier
            .weight(1f)
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                role = Role.Tab,
                onClick = onClick,
            )
            .padding(vertical = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        // Pill container: 64×32dp holds both pill background and the icon
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier.size(64.dp, 32.dp),
        ) {
            // Pill background — driven by graphicsLayer for alpha+scale
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 4.dp)
                    .graphicsLayer {
                        alpha = pillAlpha
                        scaleX = pillScale
                        scaleY = pillScale
                    }
                    .background(
                        color = colors.selectedPill,
                        shape = RoundedCornerShape(16.dp),
                    ),
            )

            // Icon with spring scale
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .size(48.dp, 24.dp)
                    .graphicsLayer {
                        scaleX = iconScale
                        scaleY = iconScale
                    },
            ) {
                Icon(
                    painter = painterResource(
                        if (selected) item.selectedIcon else item.unselectedIcon
                    ),
                    contentDescription = stringResource(item.labelResId),
                    tint = iconColor,
                    modifier = Modifier.size(22.dp),
                )
            }
        }

        Spacer(Modifier.height(4.dp))

        Text(
            text = stringResource(item.labelResId),
            style = MaterialTheme.typography.labelMedium.copy(
                color = textColor,
                fontSize = 11.sp,
                fontWeight = if (selected) FontWeight.Medium else FontWeight.Normal,
            ),
        )
    }
}

private data class BottomBarColors(
    val container: Color,
    val selectedPill: Color,
    val selectedContent: Color,
    val selectedLabel: Color,
    val unselectedContent: Color,
)
