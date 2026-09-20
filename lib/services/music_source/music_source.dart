import '../../domain/entities/track.dart';

/// Source-level contract. Each provider owns its own request format,
/// URL resolution, and error mapping. UI never touches provider internals.
abstract interface class MusicSource {
  /// Stable provider identifier used as Track.sourceId.
  String get sourceId;

  /// Human-readable provider name.
  String get displayName;

  /// Search tracks by keyword. Returns an immutable list.
  Future<List<Track>> search(String query, {int limit = 20});

  /// Resolve a playable URL for an existing Track.
  /// Returns null when the source cannot serve a URL for this id.
  Future<String?> resolveUrl(Track track);

  /// Optional: prefetch a track's metadata into the catalog.
  Future<void> prefetch(Track track) async {}
}

/// Aggregates multiple sources and deduplicates results across providers.
class SourceAggregator {
  SourceAggregator(this._sources);

  final List<MusicSource> _sources;

  List<MusicSource> get sources => List.unmodifiable(_sources);

  /// Search every source in parallel, merge by (sourceId, id).
  Future<List<Track>> searchAll(String query, {int limitPerSource = 20}) async {
    final results = await Future.wait(
      _sources.map((source) => source.search(query, limit: limitPerSource)),
    );
    final merged = <(String, String), Track>{};
    for (final batch in results) {
      for (final track in batch) {
        merged.putIfAbsent(track.key, () => track);
      }
    }
    return List.unmodifiable(merged.values);
  }
}
