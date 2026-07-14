package app.awrad.awrad_dhikrgoalstracker.ui.screens.wird

import android.view.HapticFeedbackConstants
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.waitForUpOrCancellation
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.NavigateBefore
import androidx.compose.material.icons.automirrored.outlined.MenuBook
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.SwipeUp
import androidx.compose.material.icons.outlined.TouchApp
import androidx.compose.material.icons.outlined.VolunteerActivism
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.nestedscroll.NestedScrollConnection
import androidx.compose.ui.input.nestedscroll.NestedScrollSource
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.ui.components.quran.QuranBodyText
import app.awrad.awrad_dhikrgoalstracker.ui.components.quran.SurahHeader
import app.awrad.awrad_dhikrgoalstracker.ui.components.quran.quranQuoteRanges
import app.awrad.awrad_dhikrgoalstracker.ui.components.quran.splitBismillah
import app.awrad.awrad_dhikrgoalstracker.ui.components.quran.surahName
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.SegmentKind
import app.awrad.awrad_dhikrgoalstracker.data.model.wird.resolve
import app.awrad.awrad_dhikrgoalstracker.ui.theme.NotoNaskhArabicFontFamily
import app.awrad.awrad_dhikrgoalstracker.ui.theme.isAwradDarkTheme
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.launch

/** Fraction of the viewport where the active line rests after an auto-advance. */
private const val READING_FRACTION = 0.25f

/** A line whose top crosses above this fraction of the viewport becomes the active line. */
private const val FOCUS_FRACTION = 0.30f

/**
 * Tall repeat lines may scroll past the reading position until their bottom reaches this fraction,
 * so long passages stay readable while still locked.
 */
private const val FLOOR_FRACTION = 0.85f

/** Pause after a repeat line's count is finished before auto-advancing to the next line. */
private const val ADVANCE_DELAY_MS = 500L

/** Theme-aware background for the immersive reader, mirroring [app.awrad.awrad_dhikrgoalstracker.ui.components.RitualScreen]. */
@Composable
private fun readerBackground(): Brush {
    val colorScheme = MaterialTheme.colorScheme
    return if (isAwradDarkTheme()) {
        Brush.verticalGradient(
            listOf(Color(0xFF020706), Color(0xFF061410), Color(0xFF020807)),
        )
    } else {
        Brush.verticalGradient(
            listOf(
                colorScheme.background,
                colorScheme.surfaceVariant.copy(alpha = 0.42f),
                colorScheme.background,
            ),
        )
    }
}

@Composable
fun WirdReaderScreen(
    onNavigateBack: () -> Unit,
    onNavigateToPart: (String) -> Unit = {},
    viewModel: WirdReaderViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    Box(
        Modifier
            .fillMaxSize()
            .background(readerBackground()),
    ) {
        if (state.isLoading) {
            CircularProgressIndicator(
                modifier = Modifier.align(Alignment.Center),
            )
            return@Box
        }
        if (state.pages.isEmpty()) {
            IconButton(onClick = onNavigateBack, modifier = Modifier.systemBarsPadding()) {
                Icon(Icons.Filled.Close, contentDescription = null)
            }
            return@Box
        }
        ReaderContent(state, viewModel, onNavigateBack, onNavigateToPart)
    }
}

@Composable
private fun ReaderContent(
    state: WirdReaderUiState,
    viewModel: WirdReaderViewModel,
    onNavigateBack: () -> Unit,
    onNavigateToPart: (String) -> Unit,
) {
    val lang = currentLang()
    val view = LocalView.current
    val scope = rememberCoroutineScope()
    val vibrate by viewModel.vibrateOnCount.collectAsStateWithLifecycle()
    val fontScale by viewModel.readerFontScale.collectAsStateWithLifecycle()
    val pages = state.pages

    var activeIndex by rememberSaveable {
        mutableIntStateOf(nearestActionableAt(state.pages, state.initialPage))
    }
    var interacted by rememberSaveable { mutableStateOf(false) }
    var showContents by remember { mutableStateOf(false) }
    var showCompletion by remember { mutableStateOf(false) }
    var showNudge by remember { mutableStateOf(false) }
    var nudgeRequests by remember { mutableIntStateOf(0) }

    val listState = rememberLazyListState()

    val partTitle = state.part?.localizedTitle?.resolve(lang).orEmpty()
        .ifBlank { state.wird?.displayName(lang).orEmpty() }
    val sectionNumber = (
        state.sections.indexOfFirst { activeIndex in it.startPage..it.endPageInclusive } + 1
        ).coerceAtLeast(1)
    val progressTarget =
        if (state.totalRepetitions == 0) 0f
        else state.completedRepetitions.toFloat() / state.totalRepetitions
    val progress by animateFloatAsState(progressTarget, label = "repProgress")

    LaunchedEffect(nudgeRequests) {
        if (nudgeRequests > 0) {
            showNudge = true
            delay(1600)
            showNudge = false
        }
    }

    Column(
        Modifier
            .fillMaxSize()
            .systemBarsPadding(),
    ) {
        // Top bar: back, tappable title + section counter (opens Contents), text-size cycle.
        Row(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 4.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = onNavigateBack) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null)
            }
            Column(
                Modifier
                    .weight(1f)
                    .clickableNoRipple { showContents = true },
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(
                    text = partTitle,
                    color = MaterialTheme.colorScheme.onSurface,
                    style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold),
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                if (state.sections.size > 1) {
                    Text(
                        text = stringResource(R.string.wird_section_counter, sectionNumber, state.sections.size),
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
            }
            IconButton(onClick = viewModel::cycleFontScale) {
                Text(
                    text = stringResource(R.string.wird_font_size_label),
                    color = MaterialTheme.colorScheme.onSurface,
                    style = MaterialTheme.typography.titleMedium.copy(
                        fontWeight = FontWeight.SemiBold,
                        textDecoration = TextDecoration.Underline,
                    ),
                )
            }
        }

        // Overall progress: completed repetitions over total repetitions.
        LinearProgressIndicator(
            progress = { progress },
            strokeCap = StrokeCap.Round,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .height(4.dp),
        )
        Spacer(Modifier.height(8.dp))

        BoxWithConstraints(
            Modifier
                .weight(1f)
                .fillMaxWidth()
                .padding(start = 12.dp, end = 12.dp, bottom = 10.dp),
        ) {
            val viewportPx = constraints.maxHeight.toFloat()
            val readingY = viewportPx * READING_FRACTION
            val focusY = viewportPx * FOCUS_FRACTION
            val floorY = viewportPx * FLOOR_FRACTION
            var autoScrolling by remember { mutableStateOf(false) }

            suspend fun scrollToLine(pageIndex: Int) {
                autoScrolling = true
                try {
                    listState.animateScrollToItem(pageIndex + 1, -readingY.toInt())
                } finally {
                    autoScrolling = false
                }
            }

            fun activate(index: Int) {
                if (index != activeIndex) {
                    activeIndex = index
                    viewModel.updateReadingPosition(index)
                }
            }

            val advance: () -> Unit = {
                val current = viewModel.uiState.value
                val next = nextActionable(current.pages, activeIndex)
                if (next != null) {
                    activate(next)
                    scope.launch { scrollToLine(next) }
                } else if (current.isPartComplete) {
                    showCompletion = true
                }
            }
            val currentAdvance by rememberUpdatedState(advance)

            // Taps only ever add counts: reading flows by scrolling, so a tap on a plain,
            // complete, or non-countable line is a no-op.
            val onTap: () -> Unit = {
                val page = viewModel.uiState.value.pages.getOrNull(activeIndex)
                if (page != null && page.isCountable && page.count < page.effectiveTarget) {
                    interacted = true
                    viewModel.recite(activeIndex)
                }
            }
            val currentOnTap by rememberUpdatedState(onTap)

            val stepBack: () -> Unit = {
                val current = viewModel.uiState.value
                prevActionable(current.pages, activeIndex)?.let { prev ->
                    activate(prev)
                    scope.launch { scrollToLine(prev) }
                }
            }

            /** Contents-sheet jumps clamp to the scroll lock like everything else. */
            fun jumpToLine(pageIndex: Int) {
                val ps = viewModel.uiState.value.pages
                val lock = firstLockedLine(ps)
                val target = nearestActionableAt(ps, if (lock != null) minOf(pageIndex, lock) else pageIndex)
                activate(target)
                scope.launch { scrollToLine(target) }
            }

            /**
             * A manual scroll moved the focus point onto a new line: plain lines scrolled past are
             * marked complete, then the focused line (clamped to the lock) becomes active.
             */
            fun handleScrollFocus(focusPage: Int) {
                val ps = viewModel.uiState.value.pages
                val lock = firstLockedLine(ps)
                val target = nearestActionableAt(ps, if (lock != null) minOf(focusPage, lock) else focusPage)
                if (target == activeIndex) return
                interacted = true
                if (target > activeIndex) {
                    for (i in activeIndex until target) {
                        val passed = ps.getOrNull(i) ?: continue
                        if (passed.isCountable && !passed.isRepeatLine && passed.count < passed.effectiveTarget) {
                            viewModel.recite(i, silent = true)
                        }
                    }
                }
                activate(target)
            }

            // The scroll lock: forward scrolling is clamped so the first unfinished repeat line
            // never moves past the reading position (or, when taller than the window, past the
            // point where its end is still readable). Programmatic scrolls bypass nested scroll,
            // so auto-advance is unaffected; the settle check below re-verifies afterwards.
            val lockConnection = remember(listState, readingY, floorY) {
                object : NestedScrollConnection {
                    override fun onPreScroll(available: Offset, source: NestedScrollSource): Offset {
                        val delta = available.y
                        if (delta >= 0f) return Offset.Zero
                        val lock = firstLockedLine(viewModel.uiState.value.pages) ?: return Offset.Zero
                        val item = listState.layoutInfo.visibleItemsInfo.firstOrNull { it.index == lock + 1 }
                            ?: return if (listState.firstVisibleItemIndex > lock + 1) {
                                Offset(0f, delta) // somehow already past the lock — freeze until the snap-back
                            } else {
                                Offset.Zero // lock line still far below, free to scroll
                            }
                        val allowance = maxOf(
                            item.offset - readingY,
                            item.offset + item.size - floorY,
                        ).coerceAtLeast(0f)
                        if (-delta <= allowance) return Offset.Zero
                        nudgeRequests++
                        return Offset(0f, delta + allowance)
                    }
                }
            }

            // Manual-scroll activation: the line crossing the focus point becomes active.
            LaunchedEffect(listState, focusY) {
                snapshotFlow {
                    listState.layoutInfo.visibleItemsInfo
                        .lastOrNull { it.index in 1..pages.size && it.offset <= focusY }
                        ?.index?.minus(1)
                }
                    .filterNotNull()
                    .collect { focusPage ->
                        // Only user scrolling moves the active line — layout reflows (e.g. a font
                        // size change) also shift item offsets and must not re-anchor it.
                        if (!autoScrolling && listState.isScrollInProgress) handleScrollFocus(focusPage)
                    }
            }

            // Once any scroll settles, re-verify the lock (flings and programmatic scrolls can
            // overshoot between clamp frames) and snap back if needed.
            LaunchedEffect(listState, readingY, floorY) {
                snapshotFlow { listState.isScrollInProgress }.collect { inProgress ->
                    if (inProgress || autoScrolling) return@collect
                    val lock = firstLockedLine(viewModel.uiState.value.pages) ?: return@collect
                    val item = listState.layoutInfo.visibleItemsInfo.firstOrNull { it.index == lock + 1 }
                    val violated = if (item == null) {
                        listState.firstVisibleItemIndex > lock + 1
                    } else {
                        item.offset < readingY - 4f && item.offset + item.size < floorY - 4f
                    }
                    if (violated) {
                        nudgeRequests++
                        if (activeIndex > lock) activate(lock)
                        scrollToLine(lock)
                    }
                }
            }

            // Haptics + auto-advance driven by recite results (tap flow only; silent scroll-past
            // recites emit no events).
            LaunchedEffect(Unit) {
                viewModel.reciteEvents.collectLatest { ev ->
                    if (vibrate) {
                        view.performHapticFeedback(
                            if (ev.justCompleted) HapticFeedbackConstants.LONG_PRESS else HapticFeedbackConstants.CLOCK_TICK,
                        )
                    }
                    // Only a finished repeat count auto-advances (it just unlocked the scroll);
                    // single-count lines complete in place and the reader moves by scrolling.
                    if (ev.justCompleted && ev.pageIndex == activeIndex) {
                        val target = viewModel.uiState.value.pages.getOrNull(ev.pageIndex)?.effectiveTarget ?: 1
                        if (target > 1) {
                            delay(ADVANCE_DELAY_MS)
                            // When the part just finished, stay put: the pill flips to "tap to finish".
                            if (!viewModel.uiState.value.isPartComplete) currentAdvance()
                        }
                    }
                }
            }

            // Bring the active line to the reading position on entry, and re-anchor it after
            // geometry changes (viewport resize, text-size cycle reflowing line heights). The
            // frame waits let the reflow remeasure land first — anchoring by index against
            // stale item heights leaves the active line off-position.
            LaunchedEffect(readingY, fontScale) {
                withFrameNanos { }
                withFrameNanos { }
                listState.scrollToItem(activeIndex + 1, -readingY.toInt())
            }

            val cardColor = if (isAwradDarkTheme()) {
                Color.White.copy(alpha = 0.05f)
            } else {
                MaterialTheme.colorScheme.primary.copy(alpha = 0.06f)
            }
            Surface(
                shape = RoundedCornerShape(28.dp),
                color = cardColor,
                modifier = Modifier
                    .fillMaxSize()
                    .nestedScroll(lockConnection)
                    .pointerInput(Unit) {
                        // Tap-anywhere-to-recite. Deliberately not detectTapGestures: a recite
                        // must never fire from a scroll, so any gesture that gets consumed by the
                        // list or travels beyond touch slop is rejected outright.
                        awaitEachGesture {
                            val down = awaitFirstDown()
                            val up = waitForUpOrCancellation()
                            if (up != null &&
                                (up.position - down.position).getDistance() <= viewConfiguration.touchSlop
                            ) {
                                up.consume()
                                currentOnTap()
                            }
                        }
                    },
            ) {
                LazyColumn(state = listState, modifier = Modifier.fillMaxSize()) {
                    item(key = "reading-offset") { Spacer(Modifier.fillParentMaxHeight(READING_FRACTION)) }
                    itemsIndexed(pages, key = { index, _ -> index }) { index, page ->
                        if (page.segment.kind == SegmentKind.HEADING) {
                            HeadingLine(
                                text = page.segment.localizedText.resolve(lang),
                            )
                        } else {
                            ReaderLine(
                                page = page,
                                lang = lang,
                                isActive = index == activeIndex,
                                isPassed = index < activeIndex,
                                fontScale = fontScale,
                            )
                        }
                    }
                    item(key = "tail-space") { Spacer(Modifier.fillParentMaxHeight(1f - READING_FRACTION)) }
                }
            }

            // Nudge / first-run hint chips + the floating control pill.
            Column(
                Modifier
                    .align(Alignment.BottomCenter)
                    .padding(horizontal = 8.dp, vertical = 12.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                // The tap hint only matters when a count is actually pending on the active line.
                val activePage = pages.getOrNull(activeIndex)
                val hintVisible = !interacted && !state.isPartComplete && !showNudge &&
                    activePage?.isRepeatLine == true && !activePage.isSegmentComplete
                AnimatedVisibility(
                    visible = showNudge || hintVisible,
                    enter = fadeIn(tween(200)),
                    exit = fadeOut(tween(200)),
                ) {
                    FloatingChip(
                        text = stringResource(
                            if (showNudge) R.string.wird_complete_count_to_continue
                            else R.string.wird_hint_tap_to_recite,
                        ),
                    )
                }
                Spacer(Modifier.height(10.dp))
                BottomPill(
                    page = activePage,
                    lang = lang,
                    isWirdComplete = state.isPartComplete,
                    canStepBack = prevActionable(pages, activeIndex) != null,
                    onStepBack = stepBack,
                    onTap = {
                        if (viewModel.uiState.value.isPartComplete) showCompletion = true
                        else currentOnTap()
                    },
                )
            }

            if (showContents) {
                ContentsSheet(
                    state = state,
                    lang = lang,
                    currentPage = activeIndex,
                    onDismiss = { showContents = false },
                    onSelectPage = { index ->
                        showContents = false
                        jumpToLine(index)
                    },
                )
            }

            if (showCompletion) {
                val nextPartTitle = state.nextPart?.localizedTitle?.resolve(lang)
                CompletionOverlay(
                    wirdName = state.wird?.displayName(lang).orEmpty(),
                    streak = state.streak,
                    nextPartTitle = nextPartTitle,
                    onContinueNextPart = state.nextPart?.let { part ->
                        { onNavigateToPart(part.id) }
                    },
                    onDone = onNavigateBack,
                    onReadAgain = {
                        showCompletion = false
                        viewModel.readAgain()
                        val restart = nearestActionableAt(pages, 0)
                        activate(restart)
                        scope.launch { scrollToLine(restart) }
                    },
                )
            }
        }
    }
}

/** Modifier that reacts to taps without drawing a ripple, used for the title/section tap target. */
@Composable
private fun Modifier.clickableNoRipple(onClick: () -> Unit): Modifier = this.then(
    Modifier.clickable(
        indication = null,
        interactionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() },
        onClick = onClick,
    ),
)

@Composable
private fun HeadingLine(text: String) {
    Row(
        Modifier
            .fillMaxWidth()
            .alpha(0.7f)
            .padding(horizontal = 28.dp, vertical = 18.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        HorizontalDivider(
            Modifier.weight(1f),
            color = MaterialTheme.colorScheme.primary.copy(alpha = 0.3f),
        )
        Text(
            text = text,
            color = MaterialTheme.colorScheme.primary,
            style = MaterialTheme.typography.titleMedium.copy(fontFamily = NotoNaskhArabicFontFamily),
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 14.dp),
        )
        HorizontalDivider(
            Modifier.weight(1f),
            color = MaterialTheme.colorScheme.primary.copy(alpha = 0.3f),
        )
    }
}

@Composable
private fun ReaderLine(
    page: ReaderPage,
    lang: String,
    isActive: Boolean,
    isPassed: Boolean,
    fontScale: Float,
) {
    val alpha by animateFloatAsState(
        targetValue = if (isActive) 1f else 0.35f,
        animationSpec = tween(300),
        label = "lineAlpha",
    )
    val seg = page.segment
    Box(
        Modifier
            .fillMaxWidth()
            .graphicsLayer { this.alpha = alpha }
            .padding(vertical = 12.dp),
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            when {
                seg.kind == SegmentKind.INSTRUCTION -> Text(
                    text = seg.localizedText.resolve(lang),
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    style = MaterialTheme.typography.titleSmall,
                    textAlign = TextAlign.Center,
                )

                seg.kind == SegmentKind.QURAN -> {
                    seg.quranRef?.let {
                        SurahHeader(ref = it, fontScale = fontScale)
                    }
                    val (bismillah, body) = remember(seg.arabic) { splitBismillah(seg.arabic) }
                    if (bismillah != null) {
                        Spacer(Modifier.height(16.dp))
                        Text(
                            text = bismillah,
                            color = MaterialTheme.colorScheme.onSurface,
                            style = MaterialTheme.typography.titleLarge.copy(
                                fontFamily = NotoNaskhArabicFontFamily,
                                fontSize = 24.sp * fontScale,
                                lineHeight = 44.sp * fontScale,
                            ),
                            textAlign = TextAlign.Center,
                        )
                    }
                    Spacer(Modifier.height(12.dp))
                    QuranBodyText(arabic = body, fontScale = fontScale)
                    ActiveLineExtras(page = page, lang = lang, isActive = isActive)
                }

                else -> {
                    seg.quranRef?.let {
                        Pill(text = it.displayText())
                        Spacer(Modifier.height(10.dp))
                    }
                    // Ornate ﴿…﴾ brackets mark embedded Quran quotes — tint them.
                    val quoteColor = MaterialTheme.colorScheme.primary
                    val display = remember(seg.arabic, quoteColor) {
                        val ranges = quranQuoteRanges(seg.arabic)
                        if (ranges.isEmpty()) {
                            AnnotatedString(seg.arabic)
                        } else {
                            buildAnnotatedString {
                                append(seg.arabic)
                                ranges.forEach {
                                    addStyle(SpanStyle(color = quoteColor), it.first, it.last + 1)
                                }
                            }
                        }
                    }
                    Text(
                        text = display,
                        color = MaterialTheme.colorScheme.onSurface,
                        style = MaterialTheme.typography.headlineMedium.copy(
                            fontFamily = NotoNaskhArabicFontFamily,
                            fontSize = MaterialTheme.typography.headlineMedium.fontSize * fontScale,
                            lineHeight = 52.sp * fontScale,
                        ),
                        textAlign = TextAlign.Center,
                    )
                    ActiveLineExtras(page = page, lang = lang, isActive = isActive)
                }
            }
        }

        // Keep progress in the margin without taking width away from the reading column.
        Box(
            Modifier
                .align(Alignment.TopStart)
                .width(44.dp)
                .padding(top = 8.dp),
            contentAlignment = Alignment.TopCenter,
        ) {
            when {
                (page.isCountable && page.isSegmentComplete) || (!page.isCountable && isPassed) -> CheckDot()
                page.isRepeatLine -> RepChip(done = page.count, reps = page.effectiveTarget)
            }
        }
    }
}

/** Translation + virtue note unfold for the active line only; the pill echoes the transliteration. */
@Composable
private fun ActiveLineExtras(page: ReaderPage, lang: String, isActive: Boolean) {
    val seg = page.segment
    AnimatedVisibility(visible = isActive) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            val translation = seg.translation.resolve(lang)
            if (translation.isNotBlank()) {
                Spacer(Modifier.height(10.dp))
                Text(
                    text = translation,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.85f),
                    style = MaterialTheme.typography.bodyMedium,
                    textAlign = TextAlign.Center,
                )
            }
            val fadl = seg.fadl.resolve(lang)
            if (fadl.isNotBlank()) {
                Spacer(Modifier.height(8.dp))
                Text(
                    text = fadl,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    style = MaterialTheme.typography.bodySmall.copy(fontStyle = FontStyle.Italic),
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}

@Composable
private fun CheckDot() {
    Box(
        Modifier
            .size(18.dp)
            .clip(CircleShape)
            .background(MaterialTheme.colorScheme.primary),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            Icons.Filled.Check,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onPrimary,
            modifier = Modifier.size(12.dp),
        )
    }
}

@Composable
private fun RepChip(done: Int, reps: Int) {
    Surface(
        shape = RoundedCornerShape(50),
        color = MaterialTheme.colorScheme.primary.copy(alpha = 0.18f),
        contentColor = MaterialTheme.colorScheme.onSurface,
    ) {
        Text(
            text = "$done/$reps",
            style = MaterialTheme.typography.labelSmall,
            modifier = Modifier.padding(horizontal = 7.dp, vertical = 3.dp),
        )
    }
}

@Composable
private fun FloatingChip(text: String) {
    Surface(
        shape = RoundedCornerShape(50),
        color = MaterialTheme.colorScheme.inverseSurface.copy(alpha = 0.92f),
        contentColor = MaterialTheme.colorScheme.inverseOnSurface,
        shadowElevation = 4.dp,
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.labelMedium,
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 8.dp),
        )
    }
}

/** Best short latin-ish label for a line: surah name for Quran, else transliteration with fallbacks. */
private fun pillTitle(page: ReaderPage, lang: String): String {
    val seg = page.segment
    if (seg.kind == SegmentKind.QURAN) {
        seg.quranRef?.let { ref ->
            surahName(ref.surah)?.let { return "Sūrat ${it.transliteration}" }
        }
    }
    return seg.transliteration.resolve(lang)
        .ifBlank { seg.localizedText.resolve(lang) }
        .ifBlank { seg.translation.resolve(lang) }
        .ifBlank { seg.arabic }
}

@Composable
private fun BottomPill(
    page: ReaderPage?,
    lang: String,
    isWirdComplete: Boolean,
    canStepBack: Boolean,
    onStepBack: () -> Unit,
    onTap: () -> Unit,
) {
    Surface(
        shape = RoundedCornerShape(50),
        color = MaterialTheme.colorScheme.surface,
        tonalElevation = 3.dp,
        shadowElevation = 8.dp,
        modifier = Modifier
            .fillMaxWidth()
            .clickableNoRipple(onClick = onTap),
    ) {
        Row(
            Modifier.padding(start = 8.dp, end = 16.dp, top = 8.dp, bottom = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Surface(
                shape = CircleShape,
                color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.6f),
                modifier = Modifier
                    .size(44.dp)
                    .alpha(if (canStepBack) 1f else 0.35f)
                    .clip(CircleShape)
                    .clickable(enabled = canStepBack, onClick = onStepBack),
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        Icons.AutoMirrored.Filled.NavigateBefore,
                        contentDescription = stringResource(R.string.wird_step_back),
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            }
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(
                    text = if (isWirdComplete) {
                        stringResource(R.string.wird_complete_title)
                    } else {
                        page?.let { pillTitle(it, lang) }.orEmpty()
                    },
                    color = MaterialTheme.colorScheme.onSurface,
                    style = MaterialTheme.typography.titleSmall,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    text = when {
                        isWirdComplete -> stringResource(R.string.wird_tap_to_finish)
                        page != null && page.isRepeatLine && !page.isSegmentComplete ->
                            stringResource(R.string.wird_count_progress_tap, page.count, page.effectiveTarget)
                        page != null && page.isCountable && !page.isSegmentComplete ->
                            stringResource(R.string.wird_tap_to_count)
                        else -> stringResource(R.string.wird_scroll_to_continue)
                    },
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    style = MaterialTheme.typography.bodySmall,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Spacer(Modifier.width(12.dp))
            when {
                isWirdComplete -> Icon(
                    Icons.Filled.CheckCircle,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(34.dp),
                )
                page != null && page.isRepeatLine && !page.isSegmentComplete ->
                    CountRing(count = page.count, target = page.effectiveTarget)
                page != null && page.isCountable && !page.isSegmentComplete -> Icon(
                    Icons.Outlined.TouchApp,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(26.dp),
                )
                else -> Icon(
                    Icons.Outlined.SwipeUp,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(24.dp),
                )
            }
        }
    }
}

@Composable
private fun CountRing(count: Int, target: Int) {
    val progress by animateFloatAsState(
        targetValue = if (target == 0) 0f else count.toFloat() / target,
        label = "countRing",
    )
    Box(Modifier.size(44.dp), contentAlignment = Alignment.Center) {
        CircularProgressIndicator(
            progress = { progress },
            color = MaterialTheme.colorScheme.primary,
            trackColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.22f),
            strokeWidth = 4.dp,
            strokeCap = StrokeCap.Round,
            modifier = Modifier.fillMaxSize(),
        )
        Text(
            text = "$count",
            color = MaterialTheme.colorScheme.onSurface,
            style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.Bold),
        )
    }
}

@Composable
private fun Pill(text: String) {
    Surface(
        color = MaterialTheme.colorScheme.primaryContainer,
        contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
        shape = RoundedCornerShape(50),
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.labelMedium,
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 6.dp),
        )
    }
}

@Composable
private fun CompletionOverlay(
    wirdName: String,
    streak: Int,
    nextPartTitle: String?,
    onContinueNextPart: (() -> Unit)?,
    onDone: () -> Unit,
    onReadAgain: () -> Unit,
) {
    Box(
        Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.scrim.copy(alpha = 0.55f)),
        contentAlignment = Alignment.Center,
    ) {
        Surface(
            shape = RoundedCornerShape(28.dp),
            color = MaterialTheme.colorScheme.surface,
            modifier = Modifier
                .systemBarsPadding()
                .padding(28.dp),
        ) {
            Column(
                Modifier.padding(28.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Icon(
                    Icons.Filled.CheckCircle,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.height(72.dp),
                )
                Spacer(Modifier.height(16.dp))
                Text(
                    stringResource(R.string.wird_section_complete_title),
                    color = MaterialTheme.colorScheme.onSurface,
                    style = MaterialTheme.typography.headlineSmall,
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    wirdName,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    style = MaterialTheme.typography.titleMedium,
                )
                if (streak > 0) {
                    Spacer(Modifier.height(12.dp))
                    Pill(text = stringResource(R.string.wird_streak_days, streak))
                }
                Spacer(Modifier.height(28.dp))
                if (onContinueNextPart != null && !nextPartTitle.isNullOrBlank()) {
                    Button(
                        onClick = onContinueNextPart,
                        modifier = Modifier.fillMaxWidth(),
                    ) { Text(stringResource(R.string.wird_continue_next_part, nextPartTitle)) }
                    Spacer(Modifier.height(10.dp))
                    OutlinedButton(onClick = onDone, modifier = Modifier.fillMaxWidth()) {
                        Text(stringResource(R.string.wird_done))
                    }
                } else {
                    Button(
                        onClick = onDone,
                        modifier = Modifier.fillMaxWidth(),
                    ) { Text(stringResource(R.string.wird_done)) }
                }
                Spacer(Modifier.height(10.dp))
                TextButton(onClick = onReadAgain, modifier = Modifier.fillMaxWidth()) {
                    Text(stringResource(R.string.wird_read_again))
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ContentsSheet(
    state: WirdReaderUiState,
    lang: String,
    currentPage: Int,
    onDismiss: () -> Unit,
    onSelectPage: (Int) -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = false)
    val pages = state.pages
    val partTitle = state.part?.localizedTitle?.resolve(lang).orEmpty()

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        LazyColumn(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp),
        ) {
            item {
                Text(
                    text = stringResource(R.string.wird_contents),
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 8.dp),
                )
            }
            state.sections.forEach { section ->
                item(key = "header-${section.startPage}") {
                    val rangePages = pages.subList(section.startPage, (section.endPageInclusive + 1).coerceAtMost(pages.size))
                    val countableInRange = rangePages.count { it.isCountable }
                    val completedInRange = rangePages.count { it.isCountable && it.isSegmentComplete }
                    Row(
                        Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 8.dp, vertical = 10.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            text = section.titleLocalized?.resolve(lang)?.takeIf { it.isNotBlank() } ?: partTitle,
                            style = MaterialTheme.typography.titleSmall,
                            color = MaterialTheme.colorScheme.onSurface,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.weight(1f),
                        )
                        if (countableInRange > 0) {
                            Text(
                                text = "$completedInRange/$countableInRange",
                                style = MaterialTheme.typography.labelMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                    HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))
                }
                items(
                    items = (section.startPage..section.endPageInclusive.coerceAtMost(pages.lastIndex))
                        .filter { pages[it].segment.kind != SegmentKind.HEADING },
                    key = { it },
                ) { index ->
                    ContentsRow(
                        page = pages[index],
                        lang = lang,
                        isCurrent = index == currentPage,
                        onClick = { onSelectPage(index) },
                    )
                }
            }
            item { Spacer(Modifier.height(24.dp)) }
        }
    }
}

@Composable
private fun ContentsRow(
    page: ReaderPage,
    lang: String,
    isCurrent: Boolean,
    onClick: () -> Unit,
) {
    val seg = page.segment
    val title = when {
        seg.kind == SegmentKind.INSTRUCTION -> seg.localizedText.resolve(lang)
        seg.kind == SegmentKind.QURAN && seg.quranRef != null ->
            surahName(seg.quranRef.surah)?.let { "سورة ${it.arabic}" } ?: seg.arabic
        else -> seg.arabic
    }.take(40)

    Row(
        Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .background(
                if (isCurrent) MaterialTheme.colorScheme.surfaceVariant else Color.Transparent,
            )
            .padding(horizontal = 8.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        SegmentKindIcon(kind = seg.kind)
        Spacer(Modifier.width(12.dp))
        Text(
            text = title,
            style = MaterialTheme.typography.bodyMedium.copy(fontFamily = NotoNaskhArabicFontFamily),
            color = if (isCurrent) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
        Spacer(Modifier.width(8.dp))
        if (page.isCountable) {
            if (page.isSegmentComplete) {
                Icon(
                    Icons.Filled.CheckCircle,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(18.dp),
                )
            } else {
                Text(
                    text = "${page.count}/${page.effectiveTarget}",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }
}

@Composable
private fun SegmentKindIcon(kind: SegmentKind) {
    val (icon, tint) = when (kind) {
        SegmentKind.QURAN -> Icons.AutoMirrored.Outlined.MenuBook to MaterialTheme.colorScheme.primary
        SegmentKind.DUA -> Icons.Outlined.VolunteerActivism to MaterialTheme.colorScheme.primary
        SegmentKind.SALAH -> Icons.Filled.Star to MaterialTheme.colorScheme.primary
        SegmentKind.INSTRUCTION -> Icons.Outlined.Info to MaterialTheme.colorScheme.onSurfaceVariant
        SegmentKind.DHIKR, SegmentKind.HEADING -> Icons.Outlined.Circle to MaterialTheme.colorScheme.onSurfaceVariant
    }
    Icon(
        icon,
        contentDescription = null,
        tint = tint,
        modifier = Modifier.size(18.dp),
    )
}
