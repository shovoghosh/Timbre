import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../core/prefs.dart';
import '../data/history/history_store.dart';
import '../data/library/artwork.dart';
import '../data/library/library_controller.dart';
import '../data/models/play_event.dart';
import '../data/models/track.dart';
import '../data/settings/app_settings.dart';
import '../theme/theme_controller.dart';
import 'effects.dart';

enum PlayerRepeatMode {
  off('Repeat off'),
  all('Repeat all'),
  one('Repeat one');

  const PlayerRepeatMode(this.label);
  final String label;
}

/// The audio engine and queue. One place owns the player, listening history,
/// sleep timer, speed and the cover accent so nothing fights over them.
class PlaybackController extends ChangeNotifier {
  PlaybackController({
    required this.library,
    required this.artwork,
    required this.history,
    required this.effects,
    required this.settings,
    required this.theme,
  }) {
    player = AudioPlayer();
  }

  final LibraryController library;
  final ArtworkStore artwork;
  final HistoryStore history;
  final AudioEffects effects;
  final AppSettings settings;
  final ThemeController theme;

  late final AudioPlayer player;

  static const _kRepeat = 'player.repeat';
  static const _kShuffle = 'player.shuffle';
  static const _kVolume = 'player.volume';
  static const _kSpeeds = 'player.speeds';

  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration> duration = ValueNotifier(Duration.zero);
  final ValueNotifier<Duration?> sleepRemaining = ValueNotifier(null);

  final List<StreamSubscription<dynamic>> _subs = <StreamSubscription<dynamic>>[];
  Timer? _ticker;
  Timer? _sleepTicker;
  Timer? _sleepFadeTimer;
  DateTime? _sleepEnd;
  bool _sleepAtTrackEnd = false;

  List<Track> _queue = const [];
  int _index = 0;
  Track? _current;
  bool _playing = false;
  bool _buffering = false;
  bool _initialized = false;
  String _label = '';
  String? _error;

  PlayerRepeatMode _repeat = PlayerRepeatMode.off;
  bool _shuffle = false;
  double _volume = 1;

  /// What the listener last asked for, so a fade that is still running cannot
  /// pause or resume behind their newest tap.
  bool _wantPlaying = false;

  /// Increments whenever a new fade starts, which stops the previous one.
  int _fadeToken = 0;
  double _speed = 1;
  final Map<String, double> _speeds = <String, double>{};
  SequenceState? _sequence;

  int? _eventId;
  Track? _eventTrack;
  int _eventStartedAt = 0;
  int _eventListened = 0;

  List<Track> get queue => _queue;
  int get index => _index;
  Track? get current => _current;
  bool get playing => _playing;
  bool get buffering => _buffering;
  bool get initialized => _initialized;
  bool get hasTrack => _current != null;
  bool get isShuffled => _shuffle;
  PlayerRepeatMode get repeat => _repeat;
  double get volume => _volume;
  double get speed => _speed;
  String get label => _label;
  String? get error => _error;
  bool get hasSleepTimer => _sleepEnd != null || _sleepAtTrackEnd;
  bool get sleepAtTrackEnd => _sleepAtTrackEnd;
  bool get isEmpty => _queue.isEmpty;

  double get progress {
    final total = duration.value.inMilliseconds;
    if (total <= 0) return 0;
    return (position.value.inMilliseconds / total).clamp(0.0, 1.0);
  }

  /// Up next in the order that will actually play, accounting for shuffle.
  List<Track> get upNext {
    final sequence = _sequence;
    if (sequence == null || _queue.isEmpty) {
      return _index + 1 < _queue.length
          ? _queue.sublist(_index + 1)
          : const [];
    }
    final byId = {for (final track in _queue) track.id: track};
    final currentId = _current?.id;
    final effective = sequence.effectiveSequence;
    final result = <Track>[];
    var reachedCurrent = false;
    for (final source in effective) {
      final id = _trackIdOf(source);
      if (id == null) continue;
      if (!reachedCurrent) {
        if (id == currentId) reachedCurrent = true;
        continue;
      }
      final track = byId[id];
      if (track != null) result.add(track);
    }
    return result;
  }

  List<Track> get playedBefore {
    final sequence = _sequence;
    if (sequence == null || _queue.isEmpty) {
      return _index > 0 ? _queue.sublist(0, _index) : const [];
    }
    final byId = {for (final track in _queue) track.id: track};
    final currentId = _current?.id;
    final result = <Track>[];
    for (final source in sequence.effectiveSequence) {
      final id = _trackIdOf(source);
      if (id == null) continue;
      if (id == currentId) break;
      final track = byId[id];
      if (track != null) result.add(track);
    }
    return result;
  }

  String? _trackIdOf(AudioSource source) {
    if (source is IndexedAudioSource) {
      final tag = source.tag;
      if (tag is MediaItem) return tag.id;
    }
    return null;
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _repeat = PlayerRepeatMode.values.firstWhere(
      (mode) => mode.name == Prefs.getString(_kRepeat),
      orElse: () => PlayerRepeatMode.off,
    );
    _shuffle = Prefs.getBool(_kShuffle);
    _volume = Prefs.getDouble(_kVolume, fallback: 1).clamp(0.0, 1.0);
    _readSpeeds();

    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    await player.setLoopMode(_loopModeFor(_repeat));
    await player.setShuffleModeEnabled(_shuffle);
    await player.setVolume(_volume);
    try {
      await player.setSkipSilenceEnabled(settings.skipSilence);
    } catch (_) {
      // The skip silence feature is Android only.
    }

    _subs.add(
      player.playerStateStream.listen((state) {
        final playingNow = state.playing;
        final bufferingNow =
            state.processingState == ProcessingState.loading ||
            state.processingState == ProcessingState.buffering;
        var changed = false;
        if (playingNow != _playing) {
          _playing = playingNow;
          changed = true;
        }
        if (bufferingNow != _buffering) {
          _buffering = bufferingNow;
          changed = true;
        }
        if (state.processingState == ProcessingState.completed) {
          _flushEvent(finalize: true);
          _onCompleted();
        }
        if (changed) notifyListeners();
      }),
    );

    _subs.add(
      player.positionStream.listen((value) {
        position.value = value;
        final total = duration.value.inMilliseconds;
        if (total > 0 && value.inMilliseconds > total) {
          duration.value = value;
        }
      }),
    );

    _subs.add(
      player.durationStream.listen((value) {
        if (value != null) duration.value = value;
      }),
    );

    _subs.add(
      player.currentIndexStream.listen((value) {
        if (value != null) _setIndex(value);
      }),
    );

    _subs.add(
      player.sequenceStateStream.listen((state) {
        _sequence = state;
        notifyListeners();
      }),
    );

    _subs.add(
      player.androidAudioSessionIdStream.listen((id) {
        if (id != null && id > 0) effects.attach(id);
      }),
    );

    _ticker = Timer.periodic(const Duration(seconds: 10), (_) => _flushEvent());
  }

  LoopMode _loopModeFor(PlayerRepeatMode mode) => switch (mode) {
    PlayerRepeatMode.off => LoopMode.off,
    PlayerRepeatMode.all => LoopMode.all,
    PlayerRepeatMode.one => LoopMode.one,
  };

  AudioSource _sourceFor(Track track) {
    final cover = track.coverPath;
    return AudioSource.uri(
      Uri.parse(track.uri),
      tag: MediaItem(
        id: track.id,
        title: track.title,
        artist: track.displayArtist,
        album: track.displayAlbum,
        duration: Duration(milliseconds: track.durationMs),
        artUri: cover != null && cover.isNotEmpty ? Uri.file(cover) : null,
      ),
    );
  }

  Future<void> playQueue(
    List<Track> tracks, {
    int startIndex = 0,
    String label = '',
  }) async {
    if (tracks.isEmpty) return;
    final index = startIndex.clamp(0, tracks.length - 1);
    _queue = List<Track>.of(tracks);
    _label = label;
    _error = null;
    notifyListeners();

    try {
      final sources = _queue.map(_sourceFor).toList();
      await player.setAudioSources(
        sources,
        initialIndex: index,
        initialPosition: Duration.zero,
      );
      await _applyModes();
      _setIndex(index);
      await _startPlayback();
    } on PlayerException catch (error) {
      _error = 'Could not play "${_queue[index].title}". The file may have moved.';
      _playing = false;
      notifyListeners();
      debugPrint('Timbre playback error: $error');
    } on PlayerInterruptedException {
      // A newer queue arrived; nothing to do.
    }
  }

  Future<void> playTrack(Track track, {List<Track>? queue, String label = ''}) async {
    final list = queue ?? [track];
    final index = list.indexWhere((item) => item.id == track.id);
    await playQueue(list, startIndex: index < 0 ? 0 : index, label: label);
  }

  Future<void> _applyModes() async {
    await player.setLoopMode(_loopModeFor(_repeat));
    await player.setShuffleModeEnabled(_shuffle);
  }

  /// Starts or resumes playback without waiting on the play future.
  ///
  /// In just_audio the future from [AudioPlayer.play] completes when playback
  /// stops again, not when it starts, so waiting on it would hold up the caller
  /// until the listener pauses.
  void _resume() {
    unawaited(player.play().catchError((Object _) {}));
  }

  Future<void> _startPlayback() async {
    _wantPlaying = true;
    _cancelFade();
    if (settings.fade) {
      await player.setVolume(0);
      _resume();
      await _fadeTo(_volume, const Duration(milliseconds: 420));
    } else {
      await player.setVolume(_volume);
      _resume();
    }
  }

  Future<void> toggle() async {
    if (_current == null) return;
    if (_playing) {
      _wantPlaying = false;
      _cancelFade();
      if (settings.fade) {
        await _fadeTo(0, const Duration(milliseconds: 260));
        // The listener may have pressed play again while the fade ran.
        if (_wantPlaying) return;
      }
      await player.pause();
      await player.setVolume(_volume);
      return;
    }
    if (player.processingState == ProcessingState.completed) {
      await player.seek(Duration.zero);
    }
    _startEventIfNeeded();
    await _startPlayback();
  }

  Future<void> next() async {
    if (_queue.isEmpty) return;
    try {
      if (repeat == PlayerRepeatMode.one) {
        await player.seek(Duration.zero);
        _resume();
        return;
      }
      await player.seekToNext();
      if (!player.playing) _resume();
    } catch (_) {
      // At the end of the queue.
    }
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    if (position.value.inSeconds > 4) {
      await player.seek(Duration.zero);
      return;
    }
    try {
      await player.seekToPrevious();
      if (!player.playing) _resume();
    } catch (_) {
      await player.seek(Duration.zero);
    }
  }

  Future<void> seek(Duration value) async {
    position.value = value;
    await player.seek(value);
  }

  Future<void> seekToIndex(int index) async {
    if (index < 0 || index >= _queue.length) return;
    await player.seek(Duration.zero, index: index);
    _wantPlaying = true;
    _cancelFade();
    await player.setVolume(_volume);
    _resume();
  }

  Future<void> setRepeat(PlayerRepeatMode mode) async {
    _repeat = mode;
    await Prefs.setString(_kRepeat, mode.name);
    await player.setLoopMode(_loopModeFor(mode));
    notifyListeners();
  }

  Future<void> cycleRepeat() async {
    final next = switch (_repeat) {
      PlayerRepeatMode.off => PlayerRepeatMode.all,
      PlayerRepeatMode.all => PlayerRepeatMode.one,
      PlayerRepeatMode.one => PlayerRepeatMode.off,
    };
    await setRepeat(next);
  }

  Future<void> setShuffle(bool value) async {
    _shuffle = value;
    await Prefs.setBool(_kShuffle, value);
    await player.setShuffleModeEnabled(value);
    notifyListeners();
  }

  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0);
    await player.setVolume(_volume);
    await Prefs.setDouble(_kVolume, _volume);
    notifyListeners();
  }

  Future<void> setSpeed(double value) async {
    _speed = value.clamp(0.5, 2.0);
    final track = _current;
    if (track != null) {
      _speeds[track.id] = _speed;
      await _saveSpeeds();
    }
    await player.setSpeed(_speed);
    notifyListeners();
  }

  double speedFor(Track track) => _speeds[track.id] ?? 1;

  /// Applies values from a restored backup.
  Future<void> restorePreferences({
    required PlayerRepeatMode repeat,
    required bool shuffle,
    required double volume,
    required Map<String, double> speeds,
  }) async {
    _repeat = repeat;
    _shuffle = shuffle;
    _volume = volume.clamp(0.0, 1.0);
    _speeds
      ..clear()
      ..addAll(speeds);
    await Prefs.setString(_kRepeat, repeat.name);
    await Prefs.setBool(_kShuffle, shuffle);
    await Prefs.setDouble(_kVolume, _volume);
    await _saveSpeeds();
    await player.setLoopMode(_loopModeFor(repeat));
    await player.setShuffleModeEnabled(shuffle);
    await player.setVolume(_volume);
    notifyListeners();
  }

  Future<void> playNext(Track track) async {
    final at = math.min(_index + 1, _queue.length);
    try {
      await player.insertAudioSource(at, _sourceFor(track));
      _queue = [..._queue]..insert(at, track);
      notifyListeners();
    } catch (_) {
      await addToQueue(track);
    }
  }

  Future<void> addToQueue(Track track) async {
    try {
      await player.addAudioSource(_sourceFor(track));
      _queue = [..._queue, track];
      notifyListeners();
    } catch (_) {
      // The player is not ready yet.
    }
  }

  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _queue.length) return;
    if (_queue.length == 1) {
      await stop();
      return;
    }
    try {
      await player.removeAudioSourceAt(index);
    } catch (_) {
      // Ignore a race with the player.
    }
    _queue = [..._queue]..removeAt(index);
    if (_index > index) _index--;
    notifyListeners();
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    final target = newIndex.clamp(0, _queue.length - 1);
    if (target == oldIndex) return;
    try {
      await player.moveAudioSource(oldIndex, target);
    } catch (_) {
      // Ignore.
    }
    final next = [..._queue];
    final track = next.removeAt(oldIndex);
    next.insert(target, track);
    _queue = next;
    notifyListeners();
  }

  Future<void> clearQueue() async {
    await stop();
    _queue = const [];
    _index = 0;
    _current = null;
    _sequence = null;
    notifyListeners();
  }

  Future<void> stop() async {
    _flushEvent(finalize: true);
    _wantPlaying = false;
    _cancelFade();
    try {
      await player.stop();
    } catch (_) {
      // Ignore.
    }
    await player.setVolume(_volume);
    _playing = false;
    notifyListeners();
  }

  void startSleep(Duration wait) {
    _cancelSleepTicker();
    _sleepAtTrackEnd = false;
    _sleepEnd = DateTime.now().add(wait);
    sleepRemaining.value = wait;
    _sleepTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = _sleepEnd?.difference(DateTime.now());
      if (left == null) return;
      if (left <= Duration.zero) {
        _finishSleep();
      } else {
        sleepRemaining.value = left;
      }
    });
    notifyListeners();
  }

  void sleepAfterCurrentTrack() {
    _cancelSleepTicker();
    _sleepAtTrackEnd = true;
    sleepRemaining.value = null;
    notifyListeners();
  }

  void cancelSleep() {
    _cancelSleepTicker();
    notifyListeners();
  }

  void _cancelSleepTicker() {
    _sleepTicker?.cancel();
    _sleepTicker = null;
    _sleepFadeTimer?.cancel();
    _sleepFadeTimer = null;
    _sleepEnd = null;
    _sleepAtTrackEnd = false;
    sleepRemaining.value = null;
  }

  Future<void> _finishSleep() async {
    _cancelSleepTicker();
    _wantPlaying = false;
    if (settings.sleepFade) {
      await _fadeTo(0, const Duration(seconds: 3));
    }
    await player.pause();
    await player.setVolume(_volume);
    notifyListeners();
  }

  void _cancelFade() {
    _fadeToken++;
  }

  /// Ramps the player volume, stopping early if another fade or an explicit
  /// play or pause takes over.
  Future<void> _fadeTo(double target, Duration duration) async {
    final token = ++_fadeToken;
    final start = player.volume;
    const steps = 12;
    final step = duration ~/ steps;
    for (var i = 1; i <= steps; i++) {
      if (token != _fadeToken) return;
      final t = i / steps;
      final value = start + (target - start) * t;
      try {
        await player.setVolume(value.clamp(0.0, 1.0));
      } catch (_) {
        return;
      }
      await Future<void>.delayed(step);
    }
    if (token == _fadeToken) {
      await player.setVolume(target.clamp(0.0, 1.0));
    }
  }

  void _setIndex(int value) {
    if (value < 0 || value >= _queue.length) return;
    if (value == _index && _current?.id == _queue[value].id) return;
    _flushEvent(finalize: true);
    _index = value;
    _current = _queue[value];
    _speed = _speeds[_current!.id] ?? 1;
    player.setSpeed(_speed);
    _startEventIfNeeded();
    _loadArtworkFor(_current!);
    notifyListeners();
  }

  void _onCompleted() {
    _playing = false;
    if (_sleepAtTrackEnd) {
      _cancelSleepTicker();
      player.pause();
    }
    notifyListeners();
  }

  Future<void> _loadArtworkFor(Track track) async {
    final path = await library.ensureCover(track);
    if (path == null) return;
    final color = await artwork.accentFor(path);
    theme.setArtworkAccent(color);
  }

  void _startEventIfNeeded() {
    if (_eventId != null) return;
    final track = _current;
    if (track == null) return;
    _eventTrack = track;
    _eventStartedAt = DateTime.now().millisecondsSinceEpoch;
    _eventListened = 0;
    history
        .insert(
          PlayEvent(
            trackId: track.id,
            title: track.title,
            artist: track.displayArtist,
            album: track.displayAlbum,
            genre: track.displayGenre,
            startedAt: _eventStartedAt,
            listenedMs: 0,
          ),
        )
        .then((id) => _eventId = id);
  }

  void _flushEvent({bool finalize = false}) {
    final id = _eventId;
    final track = _eventTrack;
    if (id == null || track == null) return;
    final positionMs = position.value.inMilliseconds;
    final listened = math.max(_eventListened, positionMs);
    final completed =
        track.durationMs > 0 && positionMs >= track.durationMs - 2500;
    history.update(
      id,
      listenedMs: math.max(0, listened),
      completed: completed ? true : null,
    );
    _eventListened = listened;
    if (finalize) {
      _eventId = null;
      _eventTrack = null;
    }
  }

  void _readSpeeds() {
    try {
      final raw = Prefs.getString(_kSpeeds);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        decoded.forEach((key, value) {
          if (value is num) _speeds['$key'] = value.toDouble().clamp(0.5, 2.0);
        });
      }
    } catch (_) {
      // Speeds reset to normal.
    }
  }

  Future<void> _saveSpeeds() async {
    try {
      await Prefs.setString(_kSpeeds, jsonEncode(_speeds));
    } catch (_) {
      // Not important enough to surface.
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _sleepTicker?.cancel();
    _sleepFadeTimer?.cancel();
    for (final sub in _subs) {
      sub.cancel();
    }
    position.dispose();
    duration.dispose();
    sleepRemaining.dispose();
    player.dispose();
    super.dispose();
  }
}
