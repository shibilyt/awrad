package app.awrad.feature.practice

import androidx.compose.runtime.MutableState

/** Replaces the state with [change] applied to it, as `MutableStateFlow.update` does. Main thread only. */
internal inline fun <T> MutableState<T>.update(change: (T) -> T) {
    value = change(value)
}
