import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../audio/effects.dart';
import '../audio/playback_controller.dart';
import '../data/history/history_store.dart';
import '../data/history/stats_controller.dart';
import '../data/library/artwork.dart';
import '../data/library/library_controller.dart';
import '../data/library/lyrics_store.dart';
import '../data/library/playlists_store.dart';
import '../data/library/saved_store.dart';
import '../data/settings/app_settings.dart';
import '../theme/theme_controller.dart';
import 'prefs.dart';

/// The app's long-lived controllers, built once at startup in dependency order
/// and read anywhere through [Services.i].
class Services {
  Services._({
    required this.theme,
    required this.settings,
    required this.artwork,
    required this.library,
    required this.history,
    required this.effects,
    required this.playback,
    required this.playlists,
    required this.favorites,
    required this.ratings,
    required this.lyrics,
    required this.stats,
  });

  static Services? _instance;

  static Services get i {
    final value = _instance;
    if (value == null) {
      throw StateError('Services.boot() must run before the app is built');
    }
    return value;
  }

  final ThemeController theme;
  final AppSettings settings;
  final ArtworkStore artwork;
  final LibraryController library;
  final HistoryStore history;
  final AudioEffects effects;
  final PlaybackController playback;
  final PlaylistStore playlists;
  final FavoritesStore favorites;
  final RatingsStore ratings;
  final LyricsStore lyrics;
  final StatsController stats;

  static Future<void> boot() async {
    if (_instance != null) return;
    await Prefs.init();

    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.samlabs.timbre.playback',
      androidNotificationChannelName: 'Playback',
      androidNotificationChannelDescription: 'The song that is playing',
      androidNotificationIcon: 'drawable/ic_launcher_monochrome',
      notificationColor: const Color(0xFFE0562D),
      preloadArtwork: true,
      artDownscaleWidth: 512,
      artDownscaleHeight: 512,
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: true,
    );

    final theme = ThemeController();
    final settings = AppSettings();
    final artwork = ArtworkStore();
    await artwork.init();

    final history = HistoryStore();
    await history.init();

    final library = LibraryController(artwork: artwork);
    await library.init();

    final playlists = PlaylistStore();
    await playlists.init();
    final favorites = FavoritesStore();
    await favorites.init();
    final ratings = RatingsStore();
    await ratings.init();
    final lyrics = LyricsStore();
    await lyrics.init();

    final effects = AudioEffects();
    final stats = StatsController(
      history: history,
      library: library,
      favorites: favorites,
      ratings: ratings,
      settings: settings,
    );
    await stats.load();
    final playback = PlaybackController(
      library: library,
      artwork: artwork,
      history: history,
      effects: effects,
      settings: settings,
      theme: theme,
    );
    await playback.init();

    _instance = Services._(
      theme: theme,
      settings: settings,
      artwork: artwork,
      library: library,
      history: history,
      effects: effects,
      playback: playback,
      playlists: playlists,
      favorites: favorites,
      ratings: ratings,
      lyrics: lyrics,
      stats: stats,
    );
  }
}
