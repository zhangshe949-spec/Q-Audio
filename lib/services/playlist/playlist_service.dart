import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/playlist.dart';
import '../../domain/entities/track.dart';
import 'playlist_repository.dart';

/// 播放列表服务
class PlaylistService {
  PlaylistService(this._repository);

  final PlaylistRepository _repository;

  /// 创建播放列表
  Future<Playlist> create({
    required String name,
    String? description,
    String? coverUrl,
    List<Track>? initialTracks,
  }) async {
    final id = _generateId();
    final now = DateTime.now();
    final trackIds = initialTracks?.map(Playlist.trackKey).toList() ?? [];

    final playlist = Playlist(
      id: id,
      name: name,
      description: description,
      coverUrl: coverUrl,
      trackIds: trackIds,
      createdAt: now,
      updatedAt: now,
    );

    await _repository.save(playlist);
    return playlist;
  }

  /// 重命名
  Future<void> rename(String id, String newName) async {
    final playlist = await _repository.getById(id);
    if (playlist != null) {
      await _repository
          .save(playlist.copyWith(name: newName, updatedAt: DateTime.now()));
    }
  }

  /// 更新描述
  Future<void> updateDescription(String id, String? description) async {
    final playlist = await _repository.getById(id);
    if (playlist != null) {
      await _repository.save(playlist.copyWith(
          description: description, updatedAt: DateTime.now()));
    }
  }

  /// 更新封面
  Future<void> updateCover(String id, String? coverUrl) async {
    final playlist = await _repository.getById(id);
    if (playlist != null) {
      await _repository.save(
          playlist.copyWith(coverUrl: coverUrl, updatedAt: DateTime.now()));
    }
  }

  /// 添加曲目
  Future<void> addTrack(String id, Track track) async {
    final playlist = await _repository.getById(id);
    if (playlist != null) {
      await _repository.save(playlist.addTrack(track));
    }
  }

  /// 批量添加曲目
  Future<void> addTracks(String id, List<Track> tracks) async {
    final playlist = await _repository.getById(id);
    if (playlist != null) {
      var updated = playlist;
      for (final track in tracks) {
        updated = updated.addTrack(track);
      }
      await _repository.save(updated);
    }
  }

  /// 移除曲目
  Future<void> removeTrack(String id, Track track) async {
    final playlist = await _repository.getById(id);
    if (playlist != null) {
      await _repository.save(playlist.removeTrack(track));
    }
  }

  /// 移除指定索引的曲目
  Future<void> removeTrackAt(String id, int index) async {
    final playlist = await _repository.getById(id);
    if (playlist != null && index >= 0 && index < playlist.trackIds.length) {
      final newTrackIds = List<String>.from(playlist.trackIds)..removeAt(index);
      await _repository.save(
          playlist.copyWith(trackIds: newTrackIds, updatedAt: DateTime.now()));
    }
  }

  /// 移动曲目（重排序）
  Future<void> moveTrack(String id, int oldIndex, int newIndex) async {
    final playlist = await _repository.getById(id);
    if (playlist != null) {
      await _repository.save(playlist.moveTrack(oldIndex, newIndex));
    }
  }

  /// 清空播放列表
  Future<void> clearTracks(String id) async {
    final playlist = await _repository.getById(id);
    if (playlist != null) {
      await _repository.save(playlist.clearTracks());
    }
  }

  /// 删除播放列表
  Future<void> delete(String id) async {
    await _repository.delete(id);
  }

  String _generateId() => 'pl_${DateTime.now().millisecondsSinceEpoch}';
}

/// Provider
final playlistServiceProvider = Provider<PlaylistService>((ref) {
  final repository = ref.watch(playlistRepositoryProvider);
  return PlaylistService(repository);
});
