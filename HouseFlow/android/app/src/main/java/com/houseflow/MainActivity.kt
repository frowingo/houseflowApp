package com.houseflow

import android.app.Activity
import android.os.Bundle
import com.houseflow.platform.AppLifecycle
import com.houseflow.platform.InviteCodeBridge

/** Non-product shell: exercise native loading without inventing an Android UI. */
class MainActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        check(InviteCodeBridge.normalize("ab-12 cd34xyz") == "AB12CD34")
    }

    override fun onStart() {
        super.onStart()
        AppLifecycle.bridge.onStarted()
    }

    override fun onStop() {
        AppLifecycle.bridge.onStopped()
        super.onStop()
    }
}
