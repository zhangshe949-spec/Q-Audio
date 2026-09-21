import '../../domain/entities/track.dart';
import '../network/network_service.dart';
import 'music_source.dart';

/// 网易云音乐公开搜索接口（music.163.com 网页端 API）。
/// 仅做搜索与播放地址解析，不涉及 DRM 破解或付费内容绕过。
class NetEaseMusicSource implements MusicSource {
  NetEaseMusicSource(this._network);

  final NetworkService _network;

  @override
  String get sourceId => 'netease';

  @override
  String get displayName => '网易云音乐';

  static const _referer = {
    'Referer': 'https://music.163.com/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0 Safari/537.36',
  };

  @override
  Future<List<Track>> search(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return const <Track>[];
    try {
      final data = await _network.getJson(
        'https://music.163.com/api/search/suggest',
        query: {'s': query, 'type': '1'},
        headers: _referer,
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
            return Track(
              id: id.toString(),
              sourceId: sourceId,
              title: name.toString(),
              artist: artist,
              album: albumName,
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
    final data = await _network.getJson(
      'https://music.163.com/api/song/url',
      query: {'id': track.id, 'br': '320000'},
      headers: _referer,
    );
    final root = data as Map;
    final songs = root['data'];
    if (songs is! List || songs.isEmpty) return null;
    final item = songs.first;
    if (item is! Map) return null;
    final url = item['url'];
    if (url is! String || url.isEmpty) return null;
    return url;
  }

  @override
  Future<void> prefetch(Track track) async {}
}
