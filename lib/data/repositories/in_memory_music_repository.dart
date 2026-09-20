import '../../domain/entities/track.dart';
import '../../domain/repositories/music_repository.dart';

/// Deterministic session-local catalog, empty unless explicitly seeded.
/// No network calls, fabricated catalog, or disk persistence.
class InMemoryMusicRepository implements MusicRepository {
  InMemoryMusicRepository({Iterable<Track> initialTracks = const []}) {
    for (final track in initialTracks) {
      _tracks[track.key] = track;
    }
  }

  final Map<(String, String), Track> _tracks = {};

  @override
  Future<void> save(Track track) async {
    _tracks[track.key] = track;
  }

  @override
  Future<Track?> findById({
    required String sourceId,
    required String id,
  }) async {
    return _tracks[(sourceId.trim(), id.trim())];
  }

  @override
  Future<bool> remove({required String sourceId, required String id}) async {
    return _tracks.remove((sourceId.trim(), id.trim())) != null;
  }

  @override
  Future<List<Track>> search(
    String query, {
    String? sourceId,
    int offset = 0,
    int limit = 50,
  }) async {
    if (offset < 0) throw ArgumentError.value(offset, 'offset');
    if (limit < 1 || limit > 200) {
      throw ArgumentError.value(limit, 'limit', 'Must be between 1 and 200.');
    }
    final term = query.trim().toLowerCase();
    final source = sourceId?.trim();
    final matches = _tracks.values.where((track) {
      if (source != null && track.sourceId != source) return false;
      return term.isEmpty ||
          [
            track.title,
            track.artist,
            track.album,
          ].any((field) => field.toLowerCase().contains(term));
    });
    return List<Track>.unmodifiable(matches.skip(offset).take(limit));
  }

  @override
  Future<void> clearAll() async {
    _tracks.clear();
  }
}
