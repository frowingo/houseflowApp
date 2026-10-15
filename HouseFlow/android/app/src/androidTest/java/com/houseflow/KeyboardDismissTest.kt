package com.houseflow

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.assertIsFocused
import androidx.compose.ui.test.assertIsNotFocused
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.houseflow.ui.components.dismissKeyboardOnTap
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** The root keyboard policy: tapping empty space ends editing, tapping a field keeps it. */
@RunWith(AndroidJUnit4::class)
class KeyboardDismissTest {
    @get:Rule val compose = createComposeRule()

    // Taps put a real device in touch mode; outside it Compose re-assigns focus for keyboard navigation.
    @Before fun touchMode() = InstrumentationRegistry.getInstrumentation().setInTouchMode(true)

    @Test fun tapOnEmptySpaceClearsFocusButTapOnFieldKeepsIt() {
        compose.setContent {
            var value by remember { mutableStateOf("") }
            Box(Modifier.fillMaxSize().dismissKeyboardOnTap()) {
                Column {
                    BasicTextField(value, { value = it }, Modifier.fillMaxWidth().height(56.dp).testTag("field"))
                    Text("Label", Modifier.fillMaxWidth().height(200.dp).testTag("empty"))
                }
            }
        }
        compose.onNodeWithTag("field").performClick()
        compose.onNodeWithTag("field").assertIsFocused()
        compose.onNodeWithTag("field").performClick()
        compose.onNodeWithTag("field").assertIsFocused()
        compose.onNodeWithTag("empty").performClick()
        compose.onNodeWithTag("field").assertIsNotFocused()
    }
}
