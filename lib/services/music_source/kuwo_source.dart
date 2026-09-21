import '../../domain/entities/track.dart';
import '../network/network_service.dart';
import 'music_source.dart';

/// 酷我音乐接口（www.kuwo.cn）。
/// Note: official API is frequently blocked; uses the same API pattern
/// as open-source music clients.
class KuwoSource implements MusicSource {
  KuwoSource(this._network);

  final NetworkService _network;

  @override
  String get sourceId => 'kuwo';

  @override
  String get displayName => '酷我音乐';

  static const _referer = {
    'Referer': 'http://www.kuwo.cn/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0 Safari/537.36',
  };

  @override
  Future<List<Track>> search(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return const <Track>[];
    try {
      final data = await _network.getJson(
        'http://www.kuwo.cn/api/getSearchList.aspx',
        query: {
          'key': query,
          'pn': '0',
          'rn': '$limit',
          'userid': -1,
          'client': 'kt',
        },
        headers: _referer,
      );
      final root = data as Map;
      final absList = root['abslist'] as List?;
      if (absList == null) return const <Track>[];
      final tracks = absList
          .take(limit)
          .map((item) {
            final song = item as Map;
            final songId = song['SongId'];
            final name = song['SongName'];
            if (songId == null || name == null) return null;
            final artist = song['Artist']?.toString() ?? '';
            final album = song['Album']?.toString() ?? '';
            return Track(
              id: songId.toString(),
              sourceId: sourceId,
              title: name.toString(),
              artist: artist,
              album: album,
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
    try {
      final data = await _network.getJson(
        'http://www.kuwo.cn/api/getSongUrlNew.aspx',
        query: {
          'rid': track.id,
          'type': 'mp3',
          'br': '128000',
          'format': 'json',
        },
        headers: _referer,
      );
      final root = data as Map;
      final url = root['url']?.toString();
      if (url == null || url.isEmpty) return null;
      return url;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> prefetch(Track track) async {}
}
