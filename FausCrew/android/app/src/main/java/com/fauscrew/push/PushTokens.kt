package com.fauscrew.push

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/** The latest token FCM issued in this process, for the registration flow to collect. */
internal object PushTokens {
    private val mutableLatest = MutableStateFlow<String?>(null)
    val latest: StateFlow<String?> = mutableLatest.asStateFlow()

    fun publish(token: String) { mutableLatest.value = token }
}
