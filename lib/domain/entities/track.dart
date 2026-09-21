/// A source-scoped track. IDs from different providers are not interchangeable.
class Track {
  Track({
    required String id,
    required String sourceId,
    required String title,
    this.artist = '',
    this.album = '',
    this.albumArtist,
    this.genre,
    this.year,
    this.trackNumber,
    this.discNumber,
    this.duration = Duration.zero,
    this.url,
    this.artworkUrl,
    this.filePath,
    this.fileSize,
    this.modifiedAt,
  })  : id = id.trim(),
        sourceId = sourceId.trim(),
        title = title.trim() {
    if (this.id.isEmpty || this.sourceId.isEmpty || this.title.isEmpty) {
      throw ArgumentError('Track id, sourceId and title must not be empty.');
    }
    if (duration.isNegative) {
      throw ArgumentError.value(duration, 'duration', 'Must not be negative.');
    }
  }

  final String id;
  final String sourceId;
  final String title;
  final String artist;
  final String album;
  final String? albumArtist;
  final String? genre;
  final int? year;
  final int? trackNumber;
  final int? discNumber;
  final Duration duration;
  final String? url;
  final String? artworkUrl;
  final String? filePath;
  final int? fileSize;
  final DateTime? modifiedAt;

  /// Record keys avoid separator collisions between provider and track IDs.
  (String, String) get key => (sourceId, id);

  Map<String, Object> toJson() => {
        'id': id,
        'sourceId': sourceId,
        'title': title,
        'artist': artist,
        'album': album,
        if (albumArtist != null) 'albumArtist': albumArtist!,
        if (genre != null) 'genre': genre!,
        if (year != null) 'year': year!,
        if (trackNumber != null) 'trackNumber': trackNumber!,
        if (discNumber != null) 'discNumber': discNumber!,
        'durationMs': duration.inMilliseconds,
        if (url != null) 'url': url!,
        if (artworkUrl != null) 'artworkUrl': artworkUrl!,
        if (filePath != null) 'filePath': filePath!,
        if (fileSize != null) 'fileSize': fileSize!,
        if (modifiedAt != null) 'modifiedAt': modifiedAt!.toIso8601String(),
      };

  factory Track.fromJson(Map<String, dynamic> json) {
    String text(String name, {bool required = false}) {
      final value = json[name];
      if (value == null && !required) return '';
      if (value is! String) throw FormatException('Invalid track \$name.');
      return value;
    }

    int? intVal(String name) {
      final value = json[name];
      if (value == null) return null;
      return value is int ? value : int.tryParse(value.toString());
    }

    DateTime? dateVal(String name) {
      final value = json[name];
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    final ms = json['durationMs'] ?? 0;
    if (ms is! int || ms < 0) {
      throw const FormatException('Invalid track durationMs.');
    }
    final urlValue = json['url'];
    if (urlValue != null && urlValue is! String) {
      throw const FormatException('Invalid track url.');
    }
    final artworkValue = json['artworkUrl'];
    if (artworkValue != null && artworkValue is! String) {
      throw const FormatException('Invalid track artworkUrl.');
    }
    try {
      return Track(
        id: text('id', required: true),
        sourceId: text('sourceId', required: true),
        title: text('title', required: true),
        artist: text('artist'),
        album: text('album'),
        albumArtist: json['albumArtist'] as String?,
        genre: json['genre'] as String?,
        year: intVal('year'),
        trackNumber: intVal('trackNumber'),
        discNumber: intVal('discNumber'),
        duration: Duration(milliseconds: ms),
        url: urlValue as String?,
        artworkUrl: artworkValue as String?,
        filePath: json['filePath'] as String?,
        fileSize: intVal('fileSize'),
        modifiedAt: dateVal('modifiedAt'),
      );
    } on ArgumentError catch (error) {
      throw FormatException(error.message.toString());
    }
  }
}
