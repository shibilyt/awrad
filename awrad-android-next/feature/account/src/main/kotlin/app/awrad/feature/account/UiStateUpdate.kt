package app.awrad.feature.account

import androidx.compose.runtime.MutableState

/*
 * ViewModels with text fields hold their UI state in Compose snapshot state, not a StateFlow: the screen reads it
 * synchronously, so a fast typist's next keystroke always lands on the text the last one produced. Collecting a
 * flow delivers each edit a frame late, and the field then drops characters (Compose's TextField state guidance).
 */

/** Replaces the state with [change] applied to it, as `MutableStateFlow.update` does. Main thread only. */
internal inline fun <T> MutableState<T>.update(change: (T) -> T) {
    value = change(value)
}
