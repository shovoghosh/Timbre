package com.samlabs.timbre

import android.content.Context
import android.content.Intent
import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Wraps the platform equalizer and bass boost for one audio session.
 *
 * The band count comes from the device, so the app shows five bands on phones
 * with a five band effect and more where the hardware offers more.
 */
class AudioEffectsChannel(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "timbre/effects")
    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null
    private var sessionId = 0
    private var enabled = false
    private var bassStrength = 0

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "attach" -> {
                    val id = call.argument<Int>("sessionId") ?: 0
                    attach(id)
                    result.success(info())
                }
                "release" -> {
                    release()
                    result.success(true)
                }
                "setEnabled" -> {
                    enabled = call.argument<Boolean>("enabled") ?: false
                    applyEnabled()
                    result.success(true)
                }
                "setBandLevels" -> {
                    val levels = call.argument<List<Int>>("levels") ?: emptyList()
                    setBandLevels(levels)
                    result.success(true)
                }
                "setPreset" -> {
                    val index = call.argument<Int>("index") ?: 0
                    setPreset(index)
                    result.success(true)
                }
                "setBassBoost" -> {
                    bassStrength = call.argument<Int>("strength") ?: 0
                    applyBassBoost()
                    result.success(true)
                }
                "info" -> result.success(info())
                "openSystemPanel" -> {
                    result.success(openSystemPanel())
                }
                else -> result.notImplemented()
            }
        } catch (t: Throwable) {
            result.error("effects_error", t.message ?: t.javaClass.simpleName, null)
        }
    }

    private fun attach(id: Int) {
        if (id <= 0) return
        release()
        sessionId = id
        try {
            equalizer = Equalizer(0, id).apply { this.enabled = false }
        } catch (t: Throwable) {
            equalizer = null
        }
        try {
            bassBoost = BassBoost(0, id).apply { this.enabled = false }
        } catch (t: Throwable) {
            bassBoost = null
        }
        applyEnabled()
        applyBassBoost()
    }

    private fun release() {
        try {
            equalizer?.release()
        } catch (_: Throwable) {
        }
        try {
            bassBoost?.release()
        } catch (_: Throwable) {
        }
        equalizer = null
        bassBoost = null
        sessionId = 0
    }

    private fun applyEnabled() {
        equalizer?.enabled = enabled
        bassBoost?.enabled = enabled && bassStrength > 0
    }

    private fun applyBassBoost() {
        val boost = bassBoost ?: return
        boost.enabled = enabled && bassStrength > 0
        if (enabled && bassStrength > 0) {
            boost.setStrength(bassStrength.toShort())
        }
    }

    private fun setBandLevels(levels: List<Int>) {
        val eq = equalizer ?: return
        val count = eq.numberOfBands.toInt()
        for (i in 0 until minOf(count, levels.size)) {
            val range = eq.bandLevelRange
            val level = levels[i].coerceIn(range[0].toInt(), range[1].toInt())
            eq.setBandLevel(i.toShort(), level.toShort())
        }
    }

    private fun setPreset(index: Int) {
        val eq = equalizer ?: return
        if (index < 0 || index >= eq.numberOfPresets) return
        eq.usePreset(index.toShort())
        applyEnabled()
    }

    private fun info(): Map<String, Any?> {
        val eq = equalizer
        if (eq == null) {
            return mapOf(
                "supported" to false,
                "bands" to emptyList<Int>(),
                "presets" to emptyList<String>(),
                "minLevel" to 0,
                "maxLevel" to 0,
                "hasBassBoost" to false,
                "bassStrength" to bassStrength,
                "enabled" to enabled,
                "sessionId" to sessionId,
            )
        }
        val range = eq.bandLevelRange
        val bands = ArrayList<Int>(eq.numberOfBands.toInt())
        for (i in 0 until eq.numberOfBands.toInt()) {
            bands.add(eq.getCenterFreq(i.toShort()) / 1000)
        }
        val presets = ArrayList<String>(eq.numberOfPresets.toInt())
        for (i in 0 until eq.numberOfPresets.toInt()) {
            presets.add(eq.getPresetName(i.toShort()).trim())
        }
        return mapOf(
            "supported" to true,
            "bands" to bands,
            "presets" to presets,
            "minLevel" to range[0].toInt(),
            "maxLevel" to range[1].toInt(),
            "bandLevels" to (0 until eq.numberOfBands.toInt()).map { eq.getBandLevel(it.toShort()).toInt() },
            "hasBassBoost" to (bassBoost?.strengthSupported() ?: false),
            "bassStrength" to bassStrength,
            "enabled" to enabled,
            "sessionId" to sessionId,
        )
    }

    private fun BassBoost.strengthSupported(): Boolean = strengthSupported

    private fun openSystemPanel(): Boolean {
        val intent = Intent("android.media.action.DISPLAY_AUDIO_EFFECT_CONTROL_PANEL").apply {
            putExtra("android.media.extra.AUDIO_SESSION", sessionId)
            putExtra("android.media.extra.CONTENT_TYPE", 0)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return try {
            if (intent.resolveActivity(context.packageManager) != null) {
                context.startActivity(intent)
                true
            } else {
                val fallback = Intent(android.provider.Settings.ACTION_SOUND_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(fallback)
                true
            }
        } catch (t: Throwable) {
            false
        }
    }
}
