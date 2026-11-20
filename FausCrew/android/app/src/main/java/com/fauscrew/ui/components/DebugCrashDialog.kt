package com.fauscrew.ui.components

import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.fauscrew.platform.DebugCrashReport

/**
 * Debug builds only: the last crash or survived engine error, selectable and copyable, so a
 * tester can paste it into a message. Technical text, not localized. Draws nothing in release.
 */
@Composable
internal fun DebugCrashDialog() {
    val report by DebugCrashReport.pending.collectAsStateWithLifecycle()
    val text = report ?: return
    val clipboard = LocalClipboardManager.current
    AlertDialog(
        onDismissRequest = DebugCrashReport::dismiss,
        title = { Text("Debug error report") },
        text = {
            SelectionContainer(Modifier.heightIn(max = 420.dp).verticalScroll(rememberScrollState())) {
                Text(text, fontFamily = FontFamily.Monospace, fontSize = 10.sp, lineHeight = 12.sp)
            }
        },
        confirmButton = {
            TextButton(onClick = {
                clipboard.setText(AnnotatedString(text))
                DebugCrashReport.dismiss()
            }) { Text("Copy and close") }
        },
        dismissButton = { TextButton(onClick = DebugCrashReport::dismiss) { Text("Close") } },
    )
}
