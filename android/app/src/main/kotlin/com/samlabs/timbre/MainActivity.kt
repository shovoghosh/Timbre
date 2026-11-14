package com.samlabs.timbre

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * AudioServiceActivity shares one FlutterEngine between the activity and the
 * background audio service, which is what just_audio_background needs.
 */
class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        LibraryChannel(this, messenger)
        AudioEffectsChannel(this, messenger)
    }
}
