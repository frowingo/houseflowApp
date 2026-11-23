package com.fauscrew.push

import com.fauscrew.viewmodel.AuthRoute

/**
 * A pending push tap is forgotten only on a real sign-out: signed in before, no profile now, and
 * the app is at the sign-in or onboarding screen. A session restore after a long background
 * ([AuthRoute.Restoring]) also drops the push user to null for a moment, and the tap must survive it.
 */
internal fun isRealSignOut(hadSession: Boolean, profileUserId: String?, route: AuthRoute): Boolean =
    hadSession && profileUserId == null && (route == AuthRoute.SignIn || route == AuthRoute.Onboarding)

/** The user the notification state follows: the push user, held through a session restore. */
internal fun notificationUserId(previous: String?, pushUserId: String?, route: AuthRoute): String? =
    if (route == AuthRoute.Restoring || route is AuthRoute.RestoreError) previous else pushUserId
