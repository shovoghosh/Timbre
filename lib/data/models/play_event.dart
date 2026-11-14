/// One play of one track. Snapshot fields keep stats meaningful after a file
/// is moved or deleted.
class PlayEvent {
  const PlayEvent({
    this.id,
    required this.trackId,
    required this.title,
    required this.artist,
    required this.album,
    required this.genre,
    required this.startedAt,
    required this.listenedMs,
    this.completed = false,
  });

  /// Database row id, null before insert.
  final int? id;
  final String trackId;
  final String title;
  final String artist;
  final String album;
  final String genre;

  /// Epoch milliseconds.
  final int startedAt;
  final int listenedMs;
  final bool completed;

  PlayEvent copyWith({int? id, int? listenedMs, bool? completed}) {
    return PlayEvent(
      id: id ?? this.id,
      trackId: trackId,
      title: title,
      artist: artist,
      album: album,
      genre: genre,
      startedAt: startedAt,
      listenedMs: listenedMs ?? this.listenedMs,
      completed: completed ?? this.completed,
    );
  }
}
