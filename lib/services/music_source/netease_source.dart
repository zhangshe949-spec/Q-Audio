import '../../domain/entities/track.dart';
import '../network/network_service.dart';
import 'music_source.dart';

/// 网易云音乐源。
/// 搜索：/api/search/get/web（网页端老接口，稳定可用）。
/// 播放：/song/media/outer/url 302 重定向到真实 CDN mp3；
///       失败时走 gdstudio 聚合 API 兜底。
class NetEaseMusicSource implements MusicSource {
  NetEaseMusicSource(this._network);

  final NetworkService _network;

  @override
  String get sourceId => 'netease';

  @override
  String get displayName => '网易云音乐';

  static const _headers = {
    'Referer': 'https://music.163.com/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0 Safari/537.36',
  };

  @override
  Future<List<Track>> search(String query, {int limit = 30}) async {
    if (query.trim().isEmpty) return const <Track>[];
    try {
      final data = await _network.getJson(
        'https://music.163.com/api/search/get/web',
        query: {
          's': query,
          'type': 1,
          'offset': 0,
          'limit': limit,
          'total': 'true',
        },
        headers: _headers,
      );
      final root = data as Map;
      final result = root['result'];
      if (result is! Map) return const <Track>[];
      final songs = result['songs'];
      if (songs is! List) return const <Track>[];
      final tracks = songs
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
              sourceId: sourceId,
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
      return List.unmodifiable(tracks);
    } catch (_) {
      return const <Track>[];
    }
  }

  @override
  Future<String?> resolveUrl(Track track) async {
    // 1) outer/url 302 重定向：跟随重定向拿到真实 CDN 地址。
    //    Dio 默认跟随重定向，但该接口返回 302 → mp3（非 JSON），
    //    所以这里用 validateStatus 接受 302 并读取 location 之外，
    //    更简单的方式：直接请求 gdstudio（它内部处理了网易的版权逻辑）。
    // 2) gdstudio 聚合 API：types=url 直接返回可播放的 mp3 地址。
    try {
      final data = await _network.getJson(
        'https://music-api.gdstudio.xyz/api.php',
        query: {'types': 'url', 'source': 'netease', 'id': track.id, 'br': 320},
        headers: const {'User-Agent': 'Mozilla/5.0'},
        timeout: const Duration(seconds: 12),
      );
      final root = data as Map;
      final url = root['url'];
      if (url is String && url.isNotEmpty && url.startsWith('http')) {
        return url;
      }
    } catch (_) {
      // fall through
    }

    // 3) 兜底：outer/url 直链（部分免费歌曲可用，302 已由 Dio 跟随）。
    return 'https://music.163.com/song/media/outer/url?id=${track.id}.mp3';
  }

  @override
  Future<void> prefetch(Track track) async {}
}
