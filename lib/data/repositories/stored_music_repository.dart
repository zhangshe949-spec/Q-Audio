import 'dart:async';
import 'dart:convert';

import '../../domain/entities/track.dart';
import '../../domain/repositories/music_repository.dart';
import '../../services/storage/storage_service.dart';
import 'in_memory_music_repository.dart';

/// Small catalog snapshot adapter, not the final large-library database.
/// Provide one shared repository per store; concurrent external writers are not
/// supported. A future Drift adapter can implement the same domain contract.
class StoredMusicRepository implements MusicRepository {
  StoredMusicRepository(this.storage);
  final StorageService storage;
  static const storageKey = 'catalog';
  static const maxTracks = 200;
  Future<void> _tail = Future<void>.value();

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<List<Track>> _load() async {
    final raw = await storage.read(storageKey);
    if (raw == null) return [];
    final value = jsonDecode(raw);
    if (value is! Map<String, dynamic> ||
        value['version'] != 1 ||
        value['tracks'] is! List) {
      throw const FormatException('Invalid catalog schema.');
    }
    final rows = value['tracks'] as List;
    if (rows.length > maxTracks) {
      throw const FormatException('Catalog too large.');
    }
    final tracks = <Track>[];
    final keys = <(String, String)>{};
    for (final row in rows) {
      if (row is! Map<String, dynamic>) {
        throw const FormatException('Invalid catalog row.');
      }
      final track = Track.fromJson(row);
      if (!keys.add(track.key)) {
        throw const FormatException('Duplicate track key.');
      }
      tracks.add(track);
    }
    return tracks;
  }

  Future<void> _store(Iterable<Track> tracks) => storage.write(
        storageKey,
        jsonEncode({
          'version': 1,
          'tracks': tracks.map((t) => t.toJson()).toList(),
        }),
      );

  @override
  Future<void> save(Track track) => _serial(() async {
        final records = {for (final t in await _load()) t.key: t};
        records[track.key] = track;
        if (records.length > maxTracks) {
          throw StateError('Catalog capacity exceeded.');
        }
        await _store(records.values);
      });

  @override
  Future<Track?> findById({required String sourceId, required String id}) =>
      _serial(
        () async => InMemoryMusicRepository(initialTracks: await _load())
            .findById(sourceId: sourceId, id: id),
      );

  @override
  Future<bool> remove({required String sourceId, required String id}) =>
      _serial(() async {
        final records = {for (final t in await _load()) t.key: t};
        if (records.remove((sourceId.trim(), id.trim())) == null) return false;
        await _store(records.values);
        return true;
      });

  @override
  Future<List<Track>> search(
    String query, {
    String? sourceId,
    int offset = 0,
    int limit = 50,
  }) =>
      _serial(
        () async => InMemoryMusicRepository(initialTracks: await _load())
            .search(query, sourceId: sourceId, offset: offset, limit: limit),
      );

  @override
  Future<void> clearAll() => _serial(() async {
        await _store([]);
      });
}
