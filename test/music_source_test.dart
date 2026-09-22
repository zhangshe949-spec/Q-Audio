import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:q_audio/domain/entities/track.dart';
import 'package:q_audio/services/music_source/kuwo_source.dart';
import 'package:q_audio/services/music_source/music_source.dart';
import 'package:q_audio/services/music_source/music_search_service.dart';
import 'package:q_audio/services/music_source/netease_source.dart';
import 'package:q_audio/services/music_source/qq_source.dart';
import 'package:q_audio/services/network/network_service.dart';

class MockNetworkService extends Mock implements NetworkService {}

/// 酷我 r.s 返回 python-dict 风格文本：与 NetworkService.parseJson 相同的
/// 预处理 + 解码逻辑，供 mock 使用。
Object? parseKuwoText(String text) {
  var normalized = text.trim();
  if (normalized.isEmpty) return null;
  // r.s 无外层花括号：包一层再解析。
  if (!normalized.startsWith('{')) {
    normalized = '{$normalized}';
  }
  // 单引号 → 双引号（内容不含转义引号时安全）。
  normalized = normalized.replaceAll("'", '"');
  try {
    return jsonDecode(normalized);
  } catch (_) {
    return null;
  }
}

void main() {
  group('MusicSource - NetEaseMusicSource', () {
    late MockNetworkService mockNetwork;
    late NetEaseMusicSource source;

    setUp(() {
      mockNetwork = MockNetworkService();
      source = NetEaseMusicSource(mockNetwork);
    });

    test('sourceId and displayName are correct', () {
      expect(source.sourceId, 'netease');
      expect(source.displayName, '网易云音乐');
    });

    test('search returns empty list for empty query', () async {
      final results = await source.search('  ');
      expect(results, isEmpty);
    });

    test('search parses /api/search/get/web response', () async {
      final mockResponse = {
        'result': {
          'songs': [
            {
              'id': 12345,
              'name': 'Test Song',
              'artists': [
                {'name': 'Test Artist'}
              ],
              'album': {'name': 'Test Album'},
              'duration': 213000,
            }
          ]
        }
      };

      when(() => mockNetwork.getJson(any(),
              query: any(named: 'query'), headers: any(named: 'headers')))
          .thenAnswer((_) async => mockResponse);

      final results = await source.search('test');
      expect(results.length, 1);
      expect(results.first.id, '12345');
      expect(results.first.title, 'Test Song');
      expect(results.first.artist, 'Test Artist');
      expect(results.first.album, 'Test Album');
      expect(results.first.duration, const Duration(milliseconds: 213000));
      expect(results.first.sourceId, 'netease');
    });

    test('search handles malformed response gracefully', () async {
      when(() => mockNetwork.getJson(any(),
              query: any(named: 'query'), headers: any(named: 'headers')))
          .thenAnswer((_) async => {'result': {}});

      final results = await source.search('test');
      expect(results, isEmpty);
    });

    test('search handles network errors gracefully', () async {
      when(() => mockNetwork.getJson(any(),
              query: any(named: 'query'), headers: any(named: 'headers')))
          .thenThrow(Exception('Network error'));

      final results = await source.search('test');
      expect(results, isEmpty);
    });

    test('resolveUrl prefers gdstudio URL', () async {
      final mockResponse = {
        'url': 'https://m801.music.126.net/example.mp3',
        'br': 320,
      };

      when(() => mockNetwork.getJson(any(),
              query: any(named: 'query'),
              headers: any(named: 'headers'),
              timeout: any(named: 'timeout')))
          .thenAnswer((_) async => mockResponse);

      final track = Track(
        id: '12345',
        sourceId: 'netease',
        title: 'Test',
        artist: 'Artist',
      );
      final url = await source.resolveUrl(track);
      expect(url, 'https://m801.music.126.net/example.mp3');
    });

    test('resolveUrl falls back to outer/url direct link', () async {
      when(() => mockNetwork.getJson(any(),
              query: any(named: 'query'),
              headers: any(named: 'headers'),
              timeout: any(named: 'timeout')))
          .thenThrow(Exception('gdstudio down'));

      final track = Track(
        id: '12345',
        sourceId: 'netease',
        title: 'Test',
        artist: 'Artist',
      );
      final url = await source.resolveUrl(track);
      expect(
        url,
        'https://music.163.com/song/media/outer/url?id=12345.mp3',
      );
    });
  });

  group('MusicSource - QQMusicSource', () {
    late MockNetworkService mockNetwork;
    late QQMusicSource source;

    setUp(() {
      mockNetwork = MockNetworkService();
      source = QQMusicSource(mockNetwork);
    });

    test('sourceId and displayName are correct', () {
      expect(source.sourceId, 'qq');
      expect(source.displayName, 'QQ 音乐');
    });

    test('search returns empty list for empty query', () async {
      final results = await source.search('  ');
      expect(results, isEmpty);
    });

    test('search parses client_search_cp response', () async {
      final mockResponse = {
        'data': {
          'song': {
            'list': [
              {
                'songmid': '00abc123',
                'songname': 'QQ Song',
                'singer': [
                  {'name': 'QQ Artist'}
                ],
                'albumname': 'QQ Album',
                'interval': 269,
              }
            ]
          }
        }
      };

      when(() => mockNetwork.getJson(any(),
              query: any(named: 'query'), headers: any(named: 'headers')))
          .thenAnswer((_) async => mockResponse);

      final results = await source.search('test');
      expect(results.length, 1);
      expect(results.first.id, '00abc123');
      expect(results.first.title, 'QQ Song');
      expect(results.first.artist, 'QQ Artist');
      expect(results.first.album, 'QQ Album');
      expect(results.first.duration, const Duration(seconds: 269));
      expect(results.first.sourceId, 'qq');
    });

    test('resolveUrl returns null (official vkey requires login)', () async {
      final track = Track(
        id: '00abc123',
        sourceId: 'qq',
        title: 'Test',
        artist: 'Artist',
      );
      final url = await source.resolveUrl(track);
      expect(url, isNull);
    });
  });

  group('MusicSource - KuwoSource', () {
    late MockNetworkService mockNetwork;
    late KuwoSource source;

    setUp(() {
      mockNetwork = MockNetworkService();
      source = KuwoSource(mockNetwork);
      when(() => mockNetwork.parseJson(any())).thenAnswer(
        (invocation) =>
            parseKuwoText(invocation.positionalArguments.first as String),
      );
    });

    test('sourceId and displayName are correct', () {
      expect(source.sourceId, 'kuwo');
      expect(source.displayName, '酷我音乐');
    });

    test('search returns empty list for empty query', () async {
      final results = await source.search('  ');
      expect(results, isEmpty);
    });

    test('search parses r.s pseudo-JSON response', () async {
      // r.s 返回 python-dict 风格文本（单引号、无外层花括号）。
      const raw = "'abslist':[{'MUSICRID':'MUSIC_11111','SONGNAME':'Kuwo Song',"
          "'ARTIST':'Kuwo Artist','ALBUM':'Kuwo Album','DURATION':'245'}]";

      when(() => mockNetwork.getText(any(),
          query: any(named: 'query'),
          headers: any(named: 'headers'))).thenAnswer((_) async => raw);

      final results = await source.search('test');
      expect(results.length, 1);
      expect(results.first.id, '11111');
      expect(results.first.title, 'Kuwo Song');
      expect(results.first.artist, 'Kuwo Artist');
      expect(results.first.album, 'Kuwo Album');
      expect(results.first.duration, const Duration(seconds: 245));
      expect(results.first.sourceId, 'kuwo');
    });

    test('resolveUrl parses antiserver convert_url3 response', () async {
      final mockResponse = {
        'code': 200,
        'msg': 'success',
        'url': 'https://kw-bj.kuwo.cn/example.mp3'
      };

      when(() => mockNetwork.getJson(any(),
              query: any(named: 'query'),
              headers: any(named: 'headers'),
              timeout: any(named: 'timeout')))
          .thenAnswer((_) async => mockResponse);

      final track = Track(
        id: '11111',
        sourceId: 'kuwo',
        title: 'Test',
        artist: 'Artist',
      );
      final url = await source.resolveUrl(track);
      expect(url, 'https://kw-bj.kuwo.cn/example.mp3');
    });

    test('search handles network errors gracefully', () async {
      when(() => mockNetwork.getText(any(),
              query: any(named: 'query'), headers: any(named: 'headers')))
          .thenThrow(Exception('Network error'));

      final results = await source.search('test');
      expect(results, isEmpty);
    });
  });

  group('MusicSearchService', () {
    late MockNetworkService mockNetwork;
    late List<MusicSource> sources;
    late MusicSearchService service;

    setUp(() {
      mockNetwork = MockNetworkService();
      when(() => mockNetwork.parseJson(any())).thenAnswer(
        (invocation) =>
            parseKuwoText(invocation.positionalArguments.first as String),
      );
      sources = [
        NetEaseMusicSource(mockNetwork),
        QQMusicSource(mockNetwork),
        KuwoSource(mockNetwork),
      ];
      service = MusicSearchService(sources);
    });

    tearDown(() async {
      await service.dispose();
    });

    test('search returns aggregated results', () async {
      final neResponse = {
        'result': {
          'songs': [
            {
              'id': 1,
              'name': 'NE Song',
              'artists': [
                {'name': 'NE Artist'}
              ],
              'album': {'name': 'NE Album'}
            }
          ]
        }
      };
      final qqResponse = {
        'data': {
          'song': {
            'list': [
              {
                'songmid': '00m2',
                'songname': 'QQ Song',
                'singer': [
                  {'name': 'QQ Artist'}
                ],
                'albumname': 'QQ Album',
              }
            ]
          }
        }
      };
      const kuwoRaw = "'abslist':[{'MUSICRID':'MUSIC_3','SONGNAME':'KW Song',"
          "'ARTIST':'KW Artist','ALBUM':'KW Album'}]";

      when(() => mockNetwork.getJson(
            'https://music.163.com/api/search/get/web',
            query: any(named: 'query'),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => neResponse);

      when(() => mockNetwork.getJson(
            'https://c.y.qq.com/soso/fcgi-bin/client_search_cp',
            query: any(named: 'query'),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => qqResponse);

      when(() => mockNetwork.getText(
            'http://search.kuwo.cn/r.s',
            query: any(named: 'query'),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => kuwoRaw);

      final results = await service.search('test');
      expect(results.length, 3);
      expect(results.map((t) => t.sourceId).toSet(), {'netease', 'qq', 'kuwo'});
    });

    test('search deduplicates by (sourceId, id)', () async {
      final neResponse = {
        'result': {
          'songs': [
            {
              'id': 1,
              'name': 'Song A',
              'artists': [
                {'name': 'Artist'}
              ],
              'album': {'name': 'Album'}
            },
            {
              'id': 1,
              'name': 'Song A Dup',
              'artists': [
                {'name': 'Artist'}
              ],
              'album': {'name': 'Album'}
            },
          ]
        }
      };

      when(() => mockNetwork.getJson(
            'https://music.163.com/api/search/get/web',
            query: any(named: 'query'),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => neResponse);

      when(() => mockNetwork.getJson(
            'https://c.y.qq.com/soso/fcgi-bin/client_search_cp',
            query: any(named: 'query'),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => {
            'data': {
              'song': {'list': []}
            }
          });

      when(() => mockNetwork.getText(
            'http://search.kuwo.cn/r.s',
            query: any(named: 'query'),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => "'abslist':[]");

      final results = await service.search('test');
      expect(results.length, 1);
    });

    test('resolveUrl delegates to correct source', () async {
      final track = Track(
          id: '123', sourceId: 'netease', title: 'Test', artist: 'Artist');
      final mockResponse = {
        'url': 'https://netease.com/track.mp3',
      };

      when(() => mockNetwork.getJson(any(),
              query: any(named: 'query'),
              headers: any(named: 'headers'),
              timeout: any(named: 'timeout')))
          .thenAnswer((_) async => mockResponse);

      final url = await service.resolveUrl(track);
      expect(url, 'https://netease.com/track.mp3');
    });

    test('watchResults stream emits results', () async {
      service.watchResults();

      final mockResponse = {
        'result': {
          'songs': [
            {
              'id': 1,
              'name': 'Song',
              'artists': [
                {'name': 'Artist'}
              ],
              'album': {'name': 'Album'}
            }
          ]
        }
      };
      when(() => mockNetwork.getJson(any(),
              query: any(named: 'query'), headers: any(named: 'headers')))
          .thenAnswer((_) async => mockResponse);

      final results = await service.search('test');
      expect(results.length, 1);
    });
  });
}
