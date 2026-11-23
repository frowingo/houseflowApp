package com.fauscrew

import android.app.Application
import com.fauscrew.push.PushChannels
import com.fauscrew.push.PushLog
import com.fauscrew.push.PushRegistrationHost

class FausCrewApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        PushLog.init(this)
        // A background push is shown by the system on this channel before any activity exists.
        PushChannels.createIfMissing(this)
        PushRegistrationHost.init(this)
    }
}
