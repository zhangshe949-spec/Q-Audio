import '../entities/track.dart';

/// Catalog contract only: it does not resolve media URLs or play audio.
abstract interface class MusicRepository {
  Future<void> save(Track track);
  Future<Track?> findById({required String sourceId, required String id});
  Future<bool> remove({required String sourceId, required String id});
  Future<void> clearAll();

  /// Empty query lists tracks. Results are insertion ordered and immutable.
  /// Source filtering is exact; title/artist/album search ignores letter case.
  Future<List<Track>> search(
    String query, {
    String? sourceId,
    int offset = 0,
    int limit = 50,
  });
}
