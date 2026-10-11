package com.houseflow.platform

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

internal enum class AppVisibility { BACKGROUND, ACTIVE }

/** The single-Activity shell forwards only active/background, never UI details. */
internal class AndroidLifecycleBridge {
    private val mutableVisibility = MutableStateFlow(AppVisibility.BACKGROUND)
    val visibility: StateFlow<AppVisibility> = mutableVisibility.asStateFlow()

    fun onStarted() {
        mutableVisibility.value = AppVisibility.ACTIVE
    }

    fun onStopped() {
        mutableVisibility.value = AppVisibility.BACKGROUND
    }
}

internal object AppLifecycle {
    val bridge = AndroidLifecycleBridge()
}
