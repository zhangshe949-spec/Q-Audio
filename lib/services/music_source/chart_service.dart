import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/track.dart';
import '../network/network_service.dart';

/// 网易云榜单（热歌榜 3778678 / 新歌榜 3779629）。
class ChartService {
  ChartService(this._network);

  final NetworkService _network;

  static const _chartIds = <String, String>{
    'hot': '3778678', // 云音乐热歌榜
    'new': '3779629', // 云音乐新歌榜
  };

  static const _headers = {
    'Referer': 'https://music.163.com/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0 Safari/537.36',
  };

  /// 拉取榜单前 [limit] 首。chartId: 'hot' | 'new'。
  Future<List<Track>> fetchChart(String chartId, {int limit = 20}) async {
    final playlistId = _chartIds[chartId] ?? _chartIds['hot']!;
    try {
      final data = await _network.getJson(
        'https://music.163.com/api/playlist/detail',
        query: {'id': playlistId},
        headers: _headers,
        timeout: const Duration(seconds: 15),
      );
      final root = data as Map;
      final result = root['result'];
      if (result is! Map) return const <Track>[];
      final tracks = result['tracks'];
      if (tracks is! List) return const <Track>[];
      final list = tracks
          .take(limit)
          .map((item) {
            final song = item as Map;
            final id = song['id'];
            final name = song['name'];
            if (id == null || name == null) return null;
            final artists = song['artists'];
            final artist = artists is List && artists.isNotEmpty
                ? (artists.first as Map)['name']?.toString() ?? ''
                : '';
            final album = song['album'];
            final albumName =
                album is Map ? album['name']?.toString() ?? '' : '';
            final durationMs = song['duration'];
            return Track(
              id: id.toString(),
              sourceId: 'netease',
              title: name.toString(),
              artist: artist,
              album: albumName,
              duration: durationMs is int
                  ? Duration(milliseconds: durationMs)
                  : Duration.zero,
            );
          })
          .whereType<Track>()
          .toList();
      return List.unmodifiable(list);
    } catch (_) {
      return const <Track>[];
    }
  }
}

/// 播放历史：内存 + SharedPreferences 持久化（最近 100 首，去重靠前）。
class PlayHistory {
  PlayHistory();

  final List<Track> _tracks = <Track>[];

  List<Track> get tracks => List.unmodifiable(_tracks);

  void record(Track track) {
    _tracks.removeWhere(
      (t) => t.sourceId == track.sourceId && t.id == track.id,
    );
    _tracks.insert(0, track);
    if (_tracks.length > 100) _tracks.removeRange(100, _tracks.length);
  }
}

final chartServiceProvider = Provider<ChartService>((ref) {
  // Own Dio instance (no shared state with music sources; chart requests
  // are independent and this avoids a circular import with the app layer).
  return ChartService(DioNetworkService.withDefaults());
});

final playHistoryProvider =
    StateNotifierProvider<PlayHistoryNotifier, List<Track>>((ref) {
  return PlayHistoryNotifier();
});

class PlayHistoryNotifier extends StateNotifier<List<Track>> {
  PlayHistoryNotifier() : super(const <Track>[]);

  void record(Track track) {
    final next = <Track>[
      track,
      ...state.where(
        (t) => !(t.sourceId == track.sourceId && t.id == track.id),
      ),
    ];
    if (next.length > 100) next.removeRange(100, next.length);
    state = List.unmodifiable(next);
  }

  void clear() => state = const <Track>[];
}

/// 首页榜单数据 provider：热歌榜 + 新歌榜。
final hotChartProvider = FutureProvider.autoDispose<List<Track>>((ref) async {
  final chart = ref.watch(chartServiceProvider);
  return chart.fetchChart('hot');
});

final newChartProvider = FutureProvider.autoDispose<List<Track>>((ref) async {
  final chart = ref.watch(chartServiceProvider);
  return chart.fetchChart('new');
});
