package com.fauscrew.push

import com.google.android.gms.tasks.Task
import com.google.firebase.messaging.FirebaseMessaging
import kotlin.coroutines.resume
import kotlinx.coroutines.suspendCancellableCoroutine

internal interface PushTokenProviding {
    suspend fun token(): String?
    suspend fun delete()
}

internal class FirebasePushTokenProvider : PushTokenProviding {
    override suspend fun token(): String? = FirebaseMessaging.getInstance().token.await()

    override suspend fun delete() {
        FirebaseMessaging.getInstance().deleteToken().await()
    }

    /** The result, or null when the task failed or was cancelled; coroutines-play-services is not a dependency. */
    private suspend fun <T> Task<T>.await(): T? = suspendCancellableCoroutine { continuation ->
        addOnSuccessListener { if (continuation.isActive) continuation.resume(it) }
        addOnFailureListener {
            PushLog.d("firebase task failed: ${it.javaClass.simpleName}")
            if (continuation.isActive) continuation.resume(null)
        }
        addOnCanceledListener { if (continuation.isActive) continuation.resume(null) }
    }
}
