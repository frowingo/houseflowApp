package com.houseflow.ui.components

import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.SuspendingPointerInputModifierNode
import androidx.compose.ui.node.CompositionLocalConsumerModifierNode
import androidx.compose.ui.node.DelegatingNode
import androidx.compose.ui.node.ModifierNodeElement
import androidx.compose.ui.node.currentValueOf
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalSoftwareKeyboardController

/**
 * iOS `dismissKeyboardOnTap()`: a tap that no child consumed (empty space, labels, cards)
 * clears focus and hides the keyboard. Taps on text fields and buttons keep their own
 * behavior because those children consume the gesture first.
 *
 * Applied once per window root (activity content and every popup window) so new screens
 * inherit it without per-screen code.
 */
internal fun Modifier.dismissKeyboardOnTap(): Modifier = this then DismissKeyboardOnTapElement

private data object DismissKeyboardOnTapElement : ModifierNodeElement<DismissKeyboardOnTapNode>() {
    override fun create() = DismissKeyboardOnTapNode()
    override fun update(node: DismissKeyboardOnTapNode) = Unit
}

private class DismissKeyboardOnTapNode : DelegatingNode(), CompositionLocalConsumerModifierNode {
    init {
        delegate(SuspendingPointerInputModifierNode {
            detectTapGestures(onTap = {
                currentValueOf(LocalFocusManager).clearFocus()
                currentValueOf(LocalSoftwareKeyboardController)?.hide()
            })
        })
    }
}
