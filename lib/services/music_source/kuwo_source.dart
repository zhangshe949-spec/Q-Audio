import '../../domain/entities/track.dart';
import '../network/network_service.dart';
import 'music_source.dart';

/// 酷我音乐源。
/// 搜索：search.kuwo.cn/r.s（老接口，返回类 JSON 的 python-dict 风格文本，
///       需要预处理成合法 JSON）。
/// 播放：antiserver.kuwo.cn/anti.s convert_url3（实测可用，返回 mp3 直链）。
class KuwoSource implements MusicSource {
  KuwoSource(this._network);

  final NetworkService _network;

  @override
  String get sourceId => 'kuwo';

  @override
  String get displayName => '酷我音乐';

  static const _headers = {
    'Referer': 'http://www.kuwo.cn/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0 Safari/537.36',
  };

  /// r.s 返回形如 {'key':'value'} 的伪 JSON（单引号 + true/false 大写），
  /// 转成合法 JSON 再解析。
  static String _normalizeKuwoJson(String raw) {
    return raw
        .replaceAll("'", '"')
        .replaceAll('None', 'null')
        .replaceAll('True', 'true')
        .replaceAll('False', 'false');
  }

  @override
  Future<List<Track>> search(String query, {int limit = 30}) async {
    if (query.trim().isEmpty) return const <Track>[];
    try {
      // r.s 接口返回文本，先拿原始字符串再手工解析。
      final raw = await _network.getText(
        'http://search.kuwo.cn/r.s',
        query: {
          'all': query,
          'ft': 'music',
          'client': 'kt',
          'cluster': '0',
          'pn': '0',
          'rn': '$limit',
          'encoding': 'utf8',
          'rformat': 'json',
          'mobi': '1',
          'issubtitle': '1',
        },
        headers: _headers,
      );
      final jsonText = _normalizeKuwoJson(raw);
      // r.s 返回最外层没有引号包裹的 key（python dict 风格），包一层再解。
      final wrapped = '{$jsonText}';
      final data = _network.parseJson(wrapped);
      final root = data as Map;
      final absList = root['abslist'];
      if (absList is! List) return const <Track>[];
      final tracks = absList
          .take(limit)
          .map((item) {
            final song = item as Map;
            final songId = song['MUSICRID'] ?? song['DC_TARGETID'];
            final name = song['SONGNAME'] ?? song['SongName'];
            if (songId == null || name == null) return null;
            final id = songId.toString().replaceAll('MUSIC_', '');
            final artist = (song['ARTIST'] ?? song['Artist'])?.toString() ?? '';
            final album = (song['ALBUM'] ?? song['Album'])?.toString() ?? '';
            final durationStr = song['DURATION']?.toString();
            final duration = durationStr != null && durationStr.isNotEmpty
                ? Duration(seconds: int.tryParse(durationStr) ?? 0)
                : Duration.zero;
            return Track(
              id: id,
              sourceId: sourceId,
              title: name.toString(),
              artist: artist,
              album: album,
              duration: duration,
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
        'http://antiserver.kuwo.cn/anti.s',
        query: {
          'type': 'convert_url3',
          'rid': 'MUSIC_${track.id}',
          'format': 'mp3',
        },
        headers: const {'User-Agent': 'Mozilla/5.0'},
        timeout: const Duration(seconds: 12),
      );
      final root = data as Map;
      final url = root['url']?.toString();
      if (url == null || url.isEmpty || !url.startsWith('http')) return null;
      return url;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> prefetch(Track track) async {}
}
