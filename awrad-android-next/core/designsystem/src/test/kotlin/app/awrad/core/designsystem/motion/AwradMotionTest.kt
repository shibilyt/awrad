package app.awrad.core.designsystem.motion

import androidx.compose.animation.EnterExitState
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.snap
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import app.awrad.core.designsystem.theme.AwradEasing
import app.awrad.core.designsystem.theme.AwradSprings
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/** Motion specs come from the tokens, and reduced motion swaps every movement for the cross-fade. */
class AwradMotionTest {

    private val full = AwradMotion(isReduced = false)
    private val reduced = AwradMotion(isReduced = true)
    private val crossfade = tween<Float>(durationMillis = 150, easing = LinearEasing)

    @Test
    fun aZeroAnimationScaleAsksForReducedMotion() {
        assertTrue(isReducedMotion(animatorDurationScale = 0f, transitionAnimationScale = 1f))
        assertTrue(isReducedMotion(animatorDurationScale = 1f, transitionAnimationScale = 0f))
        assertFalse(isReducedMotion(animatorDurationScale = 1f, transitionAnimationScale = 1f))
        assertFalse(isReducedMotion(animatorDurationScale = 0.5f, transitionAnimationScale = 2f))
    }

    @Test
    fun pagePushScalesAndFadesOnTheEmphasizedEasing() {
        val page = tween<Float>(durationMillis = 350, easing = AwradEasing.emphasized)
        assertEquals(scaleIn(page, initialScale = 0.96f) + fadeIn(page, initialAlpha = 0.35f), full.pagePushEnter)
        assertEquals(scaleOut(page, targetScale = 0.985f), full.pagePushExit)
        val shortFade = tween<Float>(durationMillis = 250, easing = AwradEasing.emphasized)
        assertEquals(scaleOut(page, targetScale = 0.96f) + fadeOut(shortFade), full.pagePopExit)
    }

    @Test
    fun reducedMotionTurnsEveryTransitionIntoTheCrossFade() {
        assertEquals(fadeIn(crossfade), reduced.pagePushEnter)
        assertEquals(fadeOut(crossfade), reduced.pagePushExit)
        assertEquals(fadeIn(crossfade), reduced.pagePopEnter)
        assertEquals(fadeOut(crossfade), reduced.pagePopExit)
        assertEquals(fadeIn(crossfade), reduced.tabSwitchEnter)
        assertEquals(fadeIn(crossfade), reduced.expandEnter)
        assertEquals(fadeOut(crossfade), reduced.expandExit)
    }

    @Test
    fun reducedMotionSwapsSpringsForTheCrossFadeAndMovementsForAJump() {
        assertEquals(spring(dampingRatio = 0.8f, stiffness = 380f), full.spring<Float>(AwradSprings.spatial))
        assertEquals(crossfade, reduced.spring<Float>(AwradSprings.spatial))
        assertEquals(crossfade, reduced.tween<Float>(durationMillis = 450, easing = AwradEasing.emphasized))
        assertEquals(snap(), reduced.movement<Float>())
        assertEquals(crossfade, reduced.ringFill())
    }

    @Test
    fun reducedMotionKeepsScalesAtOne() {
        assertEquals(0.7f, full.navPill.pillScaleFrom)
        assertEquals(1f, reduced.navPill.pillScaleFrom)
        assertEquals(1.04f, full.countTap.popScale)
        assertEquals(1f, reduced.countTap.popScale)
        assertEquals(0.98f, AwradPressTarget.Button.scale)
        assertEquals(0.985f, AwradPressTarget.Card.scale)
    }

    @Test
    fun thePageBehindAPushOrRevealedByAPopHasDepth() {
        val pages = AwradPageTransitions(full)
        val home = Any()
        val account = Any()

        pages.push(from = home, to = account)
        assertEquals(1f, pages.depth(home, EnterExitState.PostExit))
        assertEquals(0f, pages.depth(account, EnterExitState.PreEnter))

        pages.pop(from = account, to = home)
        assertEquals(1f, pages.depth(home, EnterExitState.PreEnter))
        assertEquals(0f, pages.depth(home, EnterExitState.Visible))
        assertEquals(0f, pages.depth(account, EnterExitState.PostExit))
    }

    @Test
    fun reducedMotionHasNoScreenDepth() {
        val pages = AwradPageTransitions(reduced)
        val home = Any()
        pages.push(from = home, to = Any())
        assertEquals(0f, pages.depth(home, EnterExitState.PostExit))
    }
}
