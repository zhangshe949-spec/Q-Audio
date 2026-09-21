import 'dart:async';

import '../../domain/entities/lyrics.dart';
import '../../domain/entities/track.dart';
import 'lyrics_source.dart';

/// 歌词服务：聚合多个歌词源，提供缓存和自动回退
class LyricsService {
  LyricsService(this._sources) : _cache = <String, Lyrics>{};

  final List<LyricsSource> _sources;
  final Map<String, Lyrics> _cache;
  final _controllers = <String, StreamController<Lyrics?>>{};

  List<LyricsSource> get sources => List.unmodifiable(_sources);

  /// 获取歌词（优先缓存，然后并行查询所有源）
  Future<Lyrics?> getLyrics(Track track) async {
    final cacheKey = '${track.sourceId}:${track.id}';

    // 缓存命中
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    // 并行查询所有源
    Lyrics? result;
    for (final source in _sources) {
      if (source.sourceId == track.sourceId) {
        result = await source.fetchLyrics(track);
        if (result != null) break;
      }
    }

    // 如果主源没找到，尝试其他源（按标题/艺术家搜索）
    if (result == null) {
      for (final source in _sources) {
        if (source.sourceId != track.sourceId) {
          result = await source.fetchLyrics(track);
          if (result != null) break;
        }
      }
    }

    if (result != null) {
      _cache[cacheKey] = result;
      _notify(cacheKey, result);
    }

    return result;
  }

  /// 监听歌词更新流
  Stream<Lyrics?> watchLyrics(Track track) {
    final cacheKey = '${track.sourceId}:${track.id}';

    late final StreamController<Lyrics?> controller;
    controller = StreamController<Lyrics?>.broadcast(
      onListen: () {
        // 立即发送缓存值
        if (_cache.containsKey(cacheKey)) {
          controller.add(_cache[cacheKey]);
        } else {
          // 异步获取
          getLyrics(track).then((lyrics) {
            if (!controller.isClosed) controller.add(lyrics);
          });
        }
      },
    );
    _controllers[cacheKey] = controller;
    return controller.stream;
  }

  void _notify(String key, Lyrics lyrics) {
    final controller = _controllers[key];
    if (controller != null && !controller.isClosed) {
      controller.add(lyrics);
    }
  }

  /// 预加载歌词（后台静默获取）
  Future<void> prefetch(Track track) async {
    await getLyrics(track);
  }

  /// 清除缓存
  void clearCache() {
    _cache.clear();
  }

  Future<void> dispose() async {
    for (final controller in _controllers.values) {
      await controller.close();
    }
    _controllers.clear();
  }
}
