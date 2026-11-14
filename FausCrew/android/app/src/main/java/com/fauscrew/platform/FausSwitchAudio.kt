package com.fauscrew.platform

import android.animation.ValueAnimator
import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.SoundPool
import com.fauscrew.R

/** What Faus Switch remembers between launches; the keys match iOS's `UserDefaults`. */
internal interface FausSwitchSettings {
    var color: String?
    var bestTime: Double?
    var effectsEnabled: Boolean?
    var musicEnabled: Boolean?
}

internal class SharedPreferencesSwitchSettings(context: Context) : FausSwitchSettings {
    private val preferences = context.applicationContext.getSharedPreferences("faus_switch", Context.MODE_PRIVATE)

    override var color: String?
        get() = preferences.getString(COLOR, null)
        set(value) = preferences.edit().putString(COLOR, value).apply()

    override var bestTime: Double?
        get() = if (preferences.contains(BEST_TIME)) preferences.getFloat(BEST_TIME, 0f).toDouble().takeIf { it > 0 } else null
        set(value) = preferences.edit().apply { if (value == null) remove(BEST_TIME) else putFloat(BEST_TIME, value.toFloat()) }.apply()

    override var effectsEnabled: Boolean?
        get() = if (preferences.contains(EFFECTS)) preferences.getBoolean(EFFECTS, true) else null
        set(value) = preferences.edit().apply { if (value == null) remove(EFFECTS) else putBoolean(EFFECTS, value) }.apply()

    override var musicEnabled: Boolean?
        get() = if (preferences.contains(MUSIC)) preferences.getBoolean(MUSIC, true) else null
        set(value) = preferences.edit().apply { if (value == null) remove(MUSIC) else putBoolean(MUSIC, value) }.apply()

    private companion object {
        const val COLOR = "faus_switch_color"
        const val BEST_TIME = "faus_switch_best_time"
        const val EFFECTS = "faus_switch_sound_enabled"
        const val MUSIC = "faus_switch_music_enabled"
    }
}

/** The race's sound, behind an interface so the view model is tested without audio. */
internal interface FausSwitchSound {
    val isEffectsEnabled: Boolean
    val isMusicEnabled: Boolean
    fun setEffectsEnabled(enabled: Boolean)
    fun setMusicEnabled(enabled: Boolean)
    fun startMusic()
    fun stopMusic()
    fun setMusicPaused(paused: Boolean)
    fun setMusicDucked(ducked: Boolean)
    fun playFlip(toward: SwitchGravity)
    fun playPortal()
    fun release()
}

/**
 * `FausSwitchAudio`: a looping background track during the race, a short "bloop" for the
 * player's own flips (rising toward the ceiling, falling toward the floor) and a "vwoop"
 * through a portal. Effects are decoded into a [SoundPool] at the countdown, so a tap only
 * plays a loaded sample. No audio focus is requested, so it mixes with other apps like
 * iOS's ambient session. Music and effects are switched separately and remembered. The
 * files are the iOS catalog's assets (`Documents/Games/fausSwitchAudioSynth.py`).
 * Main thread only.
 */
internal class FausSwitchAudio(context: Context, private val settings: FausSwitchSettings) : FausSwitchSound {
    private val context = context.applicationContext
    private val attributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_GAME)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()

    override var isEffectsEnabled: Boolean = settings.effectsEnabled ?: true
        private set
    // Until music has its own choice it follows the old single switch.
    override var isMusicEnabled: Boolean = settings.musicEnabled ?: isEffectsEnabled
        private set

    private var music: MediaPlayer? = null
    private var fade: ValueAnimator? = null
    private var volume = 0f
    private var isMusicWanted = false
    private var isMusicPaused = false
    private var isDucked = false

    private var pool: SoundPool? = null
    private val loaded = HashSet<Int>()
    private var flipUp = 0
    private var flipDown = 0
    private var portal = 0
    private var nextVariant = 0

    override fun setEffectsEnabled(enabled: Boolean) {
        if (enabled == isEffectsEnabled) return
        isEffectsEnabled = enabled
        settings.effectsEnabled = enabled
        if (enabled) prepareEffects()
    }

    override fun setMusicEnabled(enabled: Boolean) {
        if (enabled == isMusicEnabled) return
        isMusicEnabled = enabled
        settings.musicEnabled = enabled
        if (enabled) {
            if (isMusicWanted) playMusic(fromStart = false)
        } else {
            fade?.cancel()
            music?.takeIf { it.isPlaying }?.pause()
        }
    }

    // Music

    /** From the race countdown on; restarts the loop for a new race. */
    override fun startMusic() {
        isMusicWanted = true
        isMusicPaused = false
        isDucked = false
        playMusic(fromStart = true)
        prepareEffects()
    }

    override fun stopMusic() {
        isMusicWanted = false
        isMusicPaused = false
        val player = music ?: return
        if (!player.isPlaying) return
        fadeTo(0f, 350) {
            if (!isMusicWanted) {
                player.pause()
                player.seekTo(0)
            }
        }
    }

    /** Pause (demo pause or the app leaving the foreground) keeps the loop position. */
    override fun setMusicPaused(paused: Boolean) {
        if (!isMusicWanted || paused == isMusicPaused) return
        isMusicPaused = paused
        if (paused) {
            fade?.cancel()
            music?.takeIf { it.isPlaying }?.pause()
        } else {
            playMusic(fromStart = false)
        }
    }

    /** Quieter under result panels and notices. */
    override fun setMusicDucked(ducked: Boolean) {
        if (ducked == isDucked) return
        isDucked = ducked
        if (music?.isPlaying == true) fadeTo(targetVolume, 300)
    }

    private val targetVolume: Float get() = if (isDucked) DUCKED_VOLUME else MUSIC_VOLUME

    private fun playMusic(fromStart: Boolean) {
        if (!isMusicEnabled || isMusicPaused) return
        val player = music ?: runCatching {
            MediaPlayer().apply {
                setAudioAttributes(attributes)
                context.resources.openRawResourceFd(R.raw.faus_switch_music).use { setDataSource(it) }
                isLooping = true
                prepare()
            }
        }.getOrNull()?.also { music = it } ?: return
        if (fromStart) player.seekTo(0)
        setVolume(0f)
        player.start()
        fadeTo(targetVolume, if (fromStart) 600 else 250)
    }

    private fun setVolume(value: Float) {
        volume = value
        music?.setVolume(value, value)
    }

    private fun fadeTo(target: Float, millis: Long, then: () -> Unit = {}) {
        fade?.cancel()
        fade = ValueAnimator.ofFloat(volume, target).apply {
            duration = millis
            addUpdateListener { setVolume(it.animatedValue as Float) }
            addListener(object : android.animation.AnimatorListenerAdapter() {
                private var cancelled = false
                override fun onAnimationCancel(animation: android.animation.Animator) { cancelled = true }
                override fun onAnimationEnd(animation: android.animation.Animator) { if (!cancelled) then() }
            })
            start()
        }
    }

    // Effects

    /** The player's accepted flip, toward [toward]'s rail; three pitches so quick flips do not repeat. */
    override fun playFlip(toward: SwitchGravity) {
        if (!isEffectsEnabled) return
        val id = if (toward == SwitchGravity.UP) flipUp else flipDown
        val rate = FLIP_PITCHES[nextVariant % FLIP_PITCHES.size]
        nextVariant += 1
        play(id, FLIP_VOLUME, rate)
    }

    override fun playPortal() {
        if (isEffectsEnabled) play(portal, PORTAL_VOLUME, 1f)
    }

    private fun play(id: Int, level: Float, rate: Float) {
        val pool = pool ?: return
        if (id == 0 || id !in loaded) return
        pool.play(id, level, level, 1, 0, rate)
    }

    /** Decodes the effects; called at the race countdown, while the course is still. */
    private fun prepareEffects() {
        if (!isEffectsEnabled || pool != null) return
        val pool = SoundPool.Builder().setMaxStreams(4).setAudioAttributes(attributes).build()
        pool.setOnLoadCompleteListener { _, id, status -> if (status == 0) loaded += id }
        flipUp = pool.load(context, R.raw.faus_switch_flip_up, 1)
        flipDown = pool.load(context, R.raw.faus_switch_flip_down, 1)
        portal = pool.load(context, R.raw.faus_switch_portal, 1)
        this.pool = pool
    }

    override fun release() {
        fade?.cancel()
        fade = null
        music?.release()
        music = null
        pool?.release()
        pool = null
        loaded.clear()
        isMusicWanted = false
    }

    private companion object {
        const val MUSIC_VOLUME = 0.34f
        const val DUCKED_VOLUME = 0.12f
        const val FLIP_VOLUME = 0.62f
        const val PORTAL_VOLUME = 0.7f
        val FLIP_PITCHES = floatArrayOf(0.95f, 1f, 1.06f)
    }
}
