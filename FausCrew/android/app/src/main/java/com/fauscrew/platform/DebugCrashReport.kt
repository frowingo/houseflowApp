package com.fauscrew.platform

import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.content.Context
import android.content.pm.ApplicationInfo
import android.util.Log
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import java.util.Date
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Debug builds only: keeps the last failure on the phone so a tester without a computer can
 * read and copy it. Kotlin crashes are written by an uncaught-exception handler, failures the
 * app survived (an online match closed after an engine error) by [recordHandled], and native
 * (Swift) crashes come from Android's exit records on the next launch. Nothing leaves the device.
 */
internal object DebugCrashReport {
    private const val FILE_NAME = "debug-last-crash.txt"
    private const val PREFERENCES = "debug-crash-report"
    private const val SEEN_EXIT = "seenExitTimestamp"

    @Volatile private var directory: File? = null
    private val mutablePending = MutableStateFlow<String?>(null)
    /** The report to show, or null. */
    val pending: StateFlow<String?> = mutablePending.asStateFlow()

    /** Call once from the activity; does nothing in a release build. */
    fun install(context: Context) {
        val app = context.applicationContext
        if (app.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE == 0 || directory != null) return
        directory = app.filesDir
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, error ->
            runCatching { write("Crash on thread ${thread.name}", error) }
            previous?.uncaughtException(thread, error)
        }
        mutablePending.value = runCatching { load(app) }.getOrNull()
    }

    /** A failure the app survived; shown at once. A no-op in release builds and JVM tests. */
    fun recordHandled(title: String, error: Throwable) {
        if (directory == null) return
        runCatching {
            Log.w("FausCrash", title, error)
            mutablePending.value = write(title, error)
        }
    }

    fun dismiss() {
        mutablePending.value = null
        directory?.let { File(it, FILE_NAME).delete() }
    }

    private fun write(title: String, error: Throwable): String {
        val trace = StringWriter().also { error.printStackTrace(PrintWriter(it)) }.toString()
        val text = "$title\n${Date()}\n\n$trace"
        directory?.let { File(it, FILE_NAME).writeText(text) }
        return text
    }

    /** The saved Kotlin report plus native crashes and ANRs not shown before. */
    private fun load(context: Context): String? {
        val saved = directory?.let { File(it, FILE_NAME) }?.takeIf(File::exists)?.readText()
        val exits = exitReports(context)
        return listOfNotNull(saved, exits).joinToString("\n\n----------\n\n").ifEmpty { null }
    }

    private fun exitReports(context: Context): String? {
        val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        val seen = preferences.getLong(SEEN_EXIT, 0)
        val manager = context.getSystemService(ActivityManager::class.java) ?: return null
        val exits = manager.getHistoricalProcessExitReasons(context.packageName, 0, 5)
            .filter { it.timestamp > seen && it.reason in REPORTED }
        if (exits.isEmpty()) return null
        preferences.edit().putLong(SEEN_EXIT, exits.maxOf { it.timestamp }).apply()
        return exits.joinToString("\n\n----------\n\n") { exit ->
            val kind = when (exit.reason) {
                ApplicationExitInfo.REASON_CRASH_NATIVE -> "Native (Swift) crash"
                ApplicationExitInfo.REASON_ANR -> "Not responding (ANR)"
                else -> "Crash"
            }
            "$kind\n${Date(exit.timestamp)}\n${exit.description.orEmpty()}\n\n${trace(exit)}"
        }
    }

    /**
     * A native crash's trace is a binary tombstone; its readable runs carry the abort message
     * (Swift's "Fatal error: …") and the backtrace's function names, which is what matters here.
     */
    private fun trace(exit: ApplicationExitInfo): String {
        val bytes = runCatching { exit.traceInputStream?.use { it.readBytes() } }.getOrNull() ?: return ""
        if (exit.reason == ApplicationExitInfo.REASON_ANR) return String(bytes, Charsets.UTF_8).take(6_000)
        val lines = mutableListOf<String>()
        val run = StringBuilder()
        fun flush() {
            if (run.length >= 6) lines += run.toString()
            run.clear()
        }
        for (byte in bytes) {
            val code = byte.toInt() and 0xFF
            if (code in 0x20..0x7E) run.append(code.toChar()) else flush()
        }
        flush()
        return lines.take(120).joinToString("\n")
    }

    private val REPORTED = setOf(
        ApplicationExitInfo.REASON_CRASH, ApplicationExitInfo.REASON_CRASH_NATIVE, ApplicationExitInfo.REASON_ANR,
    )
}
