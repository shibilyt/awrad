package app.awrad.awrad_dhikrgoalstracker.ui.components

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.os.Build
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.core.view.WindowCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.compose.currentStateAsState
import androidx.navigation.NavBackStackEntry
import androidx.navigation.NavController
import androidx.navigation.compose.currentBackStackEntryAsState
import app.awrad.awrad_dhikrgoalstracker.R

private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}

@Composable
fun AwradStatusBarStyle(
    color: Color = MaterialTheme.colorScheme.background,
    navigationColor: Color? = null,
    useDarkIcons: Boolean = color.luminance() > 0.55f,
    useDarkNavigationIcons: Boolean = navigationColor?.let { it.luminance() > 0.55f } ?: useDarkIcons,
) {
    val view = LocalView.current
    if (view.isInEditMode) return

    SideEffect {
        val window = view.context.findActivity()?.window ?: return@SideEffect
        window.statusBarColor = color.toArgb()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isStatusBarContrastEnforced = false
        }

        WindowCompat.getInsetsController(window, view).run {
            isAppearanceLightStatusBars = useDarkIcons
            if (navigationColor != null) {
                window.navigationBarColor = Color.Transparent.toArgb()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    window.isNavigationBarContrastEnforced = false
                }
                isAppearanceLightNavigationBars = useDarkNavigationIcons
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AwradTopBar(
    title: String,
    modifier: Modifier = Modifier,
    onNavigateBack: (() -> Unit)? = null,
    isScrolled: Boolean = true,
    actions: @Composable RowScope.() -> Unit = {},
) {
    val container = MaterialTheme.colorScheme.surfaceContainerHigh
    val alpha by animateFloatAsState(
        targetValue = if (isScrolled) 1f else 0f,
        animationSpec = tween(durationMillis = 220),
        label = "awradTopBarAlpha",
    )

    AwradStatusBarStyle(color = container)

    TopAppBar(
        modifier = modifier.background(container.copy(alpha = alpha)),
        title = {
            Text(
                text = title,
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        },
        navigationIcon = {
            if (onNavigateBack != null) {
                IconButton(onClick = onNavigateBack) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Rounded.ArrowBack,
                        contentDescription = stringResource(R.string.action_back),
                    )
                }
            }
        },
        actions = actions,
        colors = TopAppBarDefaults.topAppBarColors(
            containerColor = Color.Transparent,
            scrolledContainerColor = Color.Transparent,
        ),
    )
}

@Composable
fun AwradScreenWrapper(
    navController: NavController,
    modifier: Modifier = Modifier,
    mainRootRoutes: Set<String> = emptySet(),
    content: @Composable () -> Unit,
) {
    val lifecycleOwner = LocalLifecycleOwner.current
    val lifecycleState by lifecycleOwner.lifecycle.currentStateAsState()

    val visibleEntries by navController.visibleEntries.collectAsStateWithLifecycle()
    val currentBackStackEntry by navController.currentBackStackEntryAsState()
    val visibleEntryStates = visibleEntries.map { entry ->
        key(entry.id) {
            val state by entry.lifecycle.currentStateAsState()
            entry.id to state
        }
    }.toMap()
    val myEntry = lifecycleOwner as? NavBackStackEntry
    val myIndex = visibleEntries.indexOfFirst { it.id == myEntry?.id }
    val topIndex = visibleEntries.indexOfLast {
        visibleEntryStates[it.id]?.isAtLeast(Lifecycle.State.STARTED) == true
    }
    val isNavigationTarget = myEntry != null && currentBackStackEntry?.id == myEntry.id
    val myRoute = myEntry?.destination?.route
    val isMainRootScreen = myRoute in mainRootRoutes
    val hasVisibleDeepScreen = visibleEntries.any { it.destination.route !in mainRootRoutes }
    val shouldRunDepthEffects = !isMainRootScreen || hasVisibleDeepScreen
    val shouldDim = !isNavigationTarget &&
        myIndex != -1 &&
        topIndex != -1 &&
        myIndex < topIndex &&
        visibleEntryStates[myEntry?.id] != Lifecycle.State.CREATED

    val cornerRadius by animateFloatAsState(
        targetValue = if (shouldRunDepthEffects && !lifecycleState.isAtLeast(Lifecycle.State.RESUMED)) 32f else 0f,
        animationSpec = tween(durationMillis = 400, easing = FastOutSlowInEasing),
        label = "awradScreenCornerRadius",
    )
    val dimAlpha by animateFloatAsState(
        targetValue = if (shouldRunDepthEffects && shouldDim) 0.34f else 0f,
        animationSpec = tween(durationMillis = 400, easing = FastOutSlowInEasing),
        label = "awradScreenDim",
    )

    Box(
        modifier = modifier
            .fillMaxSize()
            .graphicsLayer {
                compositingStrategy = if (shouldRunDepthEffects) {
                    CompositingStrategy.Offscreen
                } else {
                    CompositingStrategy.Auto
                }
                if (shouldRunDepthEffects && cornerRadius > 0.5f) {
                    shape = RoundedCornerShape(cornerRadius.dp)
                    clip = true
                } else {
                    clip = false
                }
            }
            .background(MaterialTheme.colorScheme.background),
    ) {
        content()
        Box(
            modifier = Modifier
                .fillMaxSize()
                .graphicsLayer { alpha = dimAlpha }
                .background(Color.Black),
        )
    }
}
