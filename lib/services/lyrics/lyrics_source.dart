import 'dart:convert';

import '../../domain/entities/lyrics.dart';
import '../../domain/entities/track.dart';
import '../network/network_service.dart';

/// 歌词提供者接口
abstract interface class LyricsSource {
  String get sourceId;

  /// 根据曲目获取歌词
  Future<Lyrics?> fetchLyrics(Track track);

  /// 可选：搜索歌词（用于无法直接匹配时）
  Future<List<Lyrics>> searchLyrics(String query, {int limit = 5}) async => const [];
}

/// 网易云歌词源
class NetEaseLyricsSource implements LyricsSource {
  NetEaseLyricsSource(this._network);

  final NetworkService _network;

  @override
  String get sourceId => 'netease';

  @override
  Future<Lyrics?> fetchLyrics(Track track) async {
    try {
      final data = await _network.getJson(
        'https://music.163.com/api/song/lyric',
        query: {'id': track.id, 'lv': '1', 'kv': '1', 'tv': '-1'},
        headers: {'Referer': 'https://music.163.com/'},
      );

      final root = data as Map;
      final lrc = root['lrc'] as Map?;
      final tlrc = root['tlyric'] as Map?;

      if (lrc == null || lrc['lyric'] == null) return null;

      final lyrics = LrcParser.parse(
        lrc['lyric'] as String,
        title: track.title,
        artist: track.artist,
        album: track.album,
      );

      if (tlrc != null && tlrc['lyric'] != null) {
        final translated = LrcParser.parseTranslation(
          tlrc['lyric'] as String,
          lyrics.lines,
        );
        return Lyrics(
          title: lyrics.title,
          artist: lyrics.artist,
          album: lyrics.album,
          lines: lyrics.lines,
          translatedLines: translated,
          offset: lyrics.offset,
        );
      }

      return lyrics;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Lyrics>> searchLyrics(String query, {int limit = 5}) async {
    // TODO: Implement search via NetEase API
    return const <Lyrics>[];
  }
}

/// QQ 音乐歌词源
class QQLyricsSource implements LyricsSource {
  QQLyricsSource(this._network);

  final NetworkService _network;

  @override
  String get sourceId => 'qq';

  @override
  Future<Lyrics?> fetchLyrics(Track track) async {
    try {
      final data = await _network.getJson(
        'https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric.fcg',
        query: {'songmid': track.id, 'format': 'json', 'nobase64': '1'},
        headers: {'Referer': 'https://y.qq.com/'},
      );

      final root = data as Map;
      final lyric = root['lyric']?.toString() ?? '';
      final trans = root['trans']?.toString() ?? '';

      if (lyric.isEmpty) return null;

      // QQ 音乐歌词可能是 base64 编码
      String decodedLyric = lyric;
      String decodedTrans = trans;

      try {
        if (lyric.contains(',') || lyric.contains('+') || lyric.contains('/')) {
          decodedLyric = utf8.decode(base64.decode(lyric));
        }
      } catch (_) {}

      try {
        if (trans.contains(',') || trans.contains('+') || trans.contains('/')) {
          decodedTrans = utf8.decode(base64.decode(trans));
        }
      } catch (_) {}

      final lyrics = LrcParser.parse(
        decodedLyric,
        title: track.title,
        artist: track.artist,
        album: track.album,
      );

      if (decodedTrans.isNotEmpty) {
        final translated = LrcParser.parseTranslation(
          decodedTrans,
          lyrics.lines,
        );
        return Lyrics(
          title: lyrics.title,
          artist: lyrics.artist,
          album: lyrics.album,
          lines: lyrics.lines,
          translatedLines: translated,
          offset: lyrics.offset,
        );
      }

      return lyrics;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Lyrics>> searchLyrics(String query, {int limit = 5}) async {
    // TODO: Implement search via QQ Music API
    return const <Lyrics>[];
  }
}

/// 酷我歌词源
class KuwoLyricsSource implements LyricsSource {
  KuwoLyricsSource(this._network);

  final NetworkService _network;

  @override
  String get sourceId => 'kuwo';

  @override
  Future<Lyrics?> fetchLyrics(Track track) async {
    try {
      final data = await _network.getJson(
        'http://www.kuwo.cn/api/getLrc.aspx',
        query: {'musicId': track.id, 'type': 'lrc'},
        headers: {'Referer': 'http://www.kuwo.cn/'},
      );

      final root = data as Map;
      final lrc = root['lrclist'] as List?;

      if (lrc == null || lrc.isEmpty) return null;

      // 酷我返回的是数组格式，需转换为标准 LRC
      final sb = StringBuffer();
      for (final item in lrc) {
        final map = item as Map;
        final time = map['time']?.toString() ?? '';
        final lyric = map['lineLyric']?.toString() ?? '';
        if (time.isNotEmpty && lyric.isNotEmpty) {
          sb.writeln('[$time]$lyric');
        }
      }

      final lyrics = LrcParser.parse(
        sb.toString(),
        title: track.title,
        artist: track.artist,
        album: track.album,
      );

      return lyrics;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Lyrics>> searchLyrics(String query, {int limit = 5}) async {
    // TODO: Implement search via Kuwo API
    return const <Lyrics>[];
  }
}