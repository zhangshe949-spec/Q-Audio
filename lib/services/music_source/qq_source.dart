import '../../domain/entities/track.dart';
import '../network/network_service.dart';
import 'music_source.dart';

/// QQ 音乐源。
/// 搜索：c.y.qq.com client_search_cp（网页端接口，实测可用）。
/// 播放：官方 vkey 接口需要登录，改走 gdstudio 聚合 API（source=tencent
///       不支持时返回 null，用户可切换其他源播放）。
class QQMusicSource implements MusicSource {
  QQMusicSource(this._network);

  final NetworkService _network;

  @override
  String get sourceId => 'qq';

  @override
  String get displayName => 'QQ 音乐';

  static const _headers = {
    'Referer': 'https://y.qq.com/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0 Safari/537.36',
  };

  @override
  Future<List<Track>> search(String query, {int limit = 30}) async {
    if (query.trim().isEmpty) return const <Track>[];
    try {
      final data = await _network.getJson(
        'https://c.y.qq.com/soso/fcgi-bin/client_search_cp',
        query: {
          'w': query,
          'p': 1,
          'n': limit,
          'format': 'json',
          't': 0,
          'cr': 1,
        },
        headers: _headers,
      );
      final root = data as Map;
      final dataNode = root['data'];
      if (dataNode is! Map) return const <Track>[];
      final songNode = dataNode['song'];
      if (songNode is! Map) return const <Track>[];
      final songs = songNode['list'];
      if (songs is! List) return const <Track>[];
      final tracks = songs
          .take(limit)
          .map((item) {
            final song = item as Map;
            final songMid = song['songmid'];
            final name = song['songname'];
            if (songMid == null || name == null) return null;
            final singerList = song['singer'];
            final artist = singerList is List && singerList.isNotEmpty
                ? (singerList.first as Map)['name']?.toString() ?? ''
                : '';
            final albumData = song['albumname'];
            final albumName = albumData?.toString() ?? '';
            final interval = song['interval'];
            return Track(
              id: songMid.toString(),
              sourceId: sourceId,
              title: name.toString(),
              artist: artist,
              album: albumName,
              duration:
                  interval is int ? Duration(seconds: interval) : Duration.zero,
            );
          })
          .whereType<Track>()
          .toList();
      return List.unmodifiable(tracks);
    } catch (_) {
      return const <Track>[];
    }
  }

  @override
  Future<String?> resolveUrl(Track track) async {
    // QQ 官方 vkey 接口需要登录态；gdstudio 不支持 tencent 源时返回 null。
    // 搜索结果仍展示（来自 QQ），播放时提示用户换源。
    return null;
  }

  @override
  Future<void> prefetch(Track track) async {}
}
