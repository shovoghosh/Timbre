/// A listener-made playlist. Smart lists are computed and never stored here.
class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.trackIds,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.coverPath,
  });

  final String id;
  final String name;
  final List<String> trackIds;
  final int createdAt;
  final int updatedAt;
  final String description;

  /// Optional custom cover stored by the app.
  final String? coverPath;

  int get length => trackIds.length;

  Playlist copyWith({
    String? name,
    List<String>? trackIds,
    int? updatedAt,
    String? description,
    String? coverPath,
    bool clearCover = false,
  }) {
    return Playlist(
      id: id,
      name: name ?? this.name,
      trackIds: trackIds ?? this.trackIds,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      description: description ?? this.description,
      coverPath: clearCover ? null : (coverPath ?? this.coverPath),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'trackIds': trackIds,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'description': description,
    'coverPath': coverPath,
  };

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: '${json['id']}',
      name: '${json['name'] ?? 'Playlist'}',
      trackIds: (json['trackIds'] as List?)?.map((e) => '$e').toList() ?? const [],
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
      description: '${json['description'] ?? ''}',
      coverPath: json['coverPath'] as String?,
    );
  }
}
