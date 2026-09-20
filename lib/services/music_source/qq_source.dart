import '../../domain/entities/track.dart';
import '../network/network_service.dart';
import 'music_source.dart';

/// QQ 音乐公开搜索接口（c.y.qq.com）。
class QQMusicSource implements MusicSource {
  QQMusicSource(this._network);

  final NetworkService _network;

  @override
  String get sourceId => 'qq';

  @override
  String get displayName => 'QQ 音乐';

  @override
  Future<List<Track>> search(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return const <Track>[];
    final data = await _network.getJson(
      'https://c.y.qq.com/soso/fcgi-bin/fcg_search_pc.fcg',
      query: {'w': query, 'p': '1', 'n': '$limit', 'format': 'json', 't': '8'},
      headers: {'Referer': 'https://y.qq.com/'},
    );
    final root = data as Map;
    final data2 = root['data'];
    if (data2 is! Map) return const <Track>[];
    final songs = data2['songs'] as List?;
    if (songs == null) return const <Track>[];
    final tracks = songs
        .take(limit)
        .map((item) {
          final song = item as Map;
          final songId = song['songid'];
          final name = song['songname'];
          if (songId == null || name == null) return null;
          final singerList = song['singer'] as List?;
          final artist = singerList != null && singerList.isNotEmpty
              ? ((singerList.first as Map)['name']?.toString() ?? '')
              : '';
          final albumData = song['album'] as Map?;
          final albumName = albumData?['name']?.toString() ?? '';
          return Track(
            id: songId.toString(),
            sourceId: sourceId,
            title: name.toString(),
            artist: artist,
            album: albumName,
          );
        })
        .whereType<Track>()
        .toList();
    return List.unmodifiable(tracks);
  }

  @override
  Future<String?> resolveUrl(Track track) async {
    final data = await _network.getJson(
      'https://c.y.qq.com/fcg-bin/fcg_get_song_url.fcg',
      query: {'guid': '1234567890', 'songid': track.id, 'format': 'json'},
      headers: {'Referer': 'https://y.qq.com/'},
    );
    final root = data as Map;
    final urlInfo = root['urlinfo'] as Map?;
    if (urlInfo == null) return null;
    final mp3 = urlInfo['mp3'] as Map?;
    if (mp3 == null) return null;
    final url = mp3['url']?.toString();
    if (url == null || url.isEmpty) return null;
    return url;
  }

  @override
  Future<void> prefetch(Track track) async {}
}
