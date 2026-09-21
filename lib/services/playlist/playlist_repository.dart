import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/playlist.dart';
import '../../../presentation/providers/catalog_providers.dart'
    show sharedPreferencesProvider;

/// 基于 SharedPreferences 的播放列表仓库
class SharedPreferencesPlaylistRepository implements PlaylistRepository {
  SharedPreferencesPlaylistRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _kPrefix = 'q_audio.playlists.';

  final _controller = StreamController<List<Playlist>>.broadcast();

  @override
  Future<List<Playlist>> getAll() async {
    final keys = _prefs.getKeys().where((k) => k.startsWith(_kPrefix)).toList();
    final playlists = <Playlist>[];
    for (final key in keys) {
      final json = _prefs.getString(key);
      if (json != null) {
        try {
          playlists
              .add(Playlist.fromJson(jsonDecode(json) as Map<String, dynamic>));
        } catch (_) {
          // 忽略损坏条目
        }
      }
    }
    // 按更新时间倒序
    playlists.sort((a, b) {
      final aTime = a.updatedAt?.millisecondsSinceEpoch ??
          a.createdAt?.millisecondsSinceEpoch ??
          0;
      final bTime = b.updatedAt?.millisecondsSinceEpoch ??
          b.createdAt?.millisecondsSinceEpoch ??
          0;
      return bTime.compareTo(aTime);
    });
    return playlists;
  }

  @override
  Future<Playlist?> getById(String id) async {
    final json = _prefs.getString('$_kPrefix$id');
    if (json == null) return null;
    try {
      return Playlist.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(Playlist playlist) async {
    final key = '$_kPrefix${playlist.id}';
    final updated = playlist.copyWith(updatedAt: DateTime.now());
    await _prefs.setString(key, jsonEncode(updated.toJson()));
    _notify();
  }

  @override
  Future<void> delete(String id) async {
    await _prefs.remove('$_kPrefix$id');
    _notify();
  }

  @override
  Stream<List<Playlist>> watch() {
    getAll().then(_controller.add);
    return _controller.stream;
  }

  void _notify() {
    getAll().then(_controller.add);
  }

  void dispose() {
    _controller.close();
  }
}

/// Provider
final playlistRepositoryProvider = Provider<PlaylistRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SharedPreferencesPlaylistRepository(prefs);
});

final playlistRepositoryInstanceProvider =
    Provider<SharedPreferencesPlaylistRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SharedPreferencesPlaylistRepository(prefs);
});
