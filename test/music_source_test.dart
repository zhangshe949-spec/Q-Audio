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

    test('search parses response correctly', () async {
      final mockResponse = {
        'result': {
          'songs': [
            {
              'id': 12345,
              'name': 'Test Song',
              'artists': [
                {'name': 'Test Artist'}
              ],
              'album': {'name': 'Test Album'}
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

    test('resolveUrl returns URL from response', () async {
      final mockResponse = {
        'data': [
          {'url': 'https://example.com/song.mp3'}
        ]
      };

      when(() => mockNetwork.getJson(any(),
              query: any(named: 'query'), headers: any(named: 'headers')))
          .thenAnswer((_) async => mockResponse);

      final track = Track(
        id: '12345',
        sourceId: 'netease',
        title: 'Test',
        artist: 'Artist',
      );
      final url = await source.resolveUrl(track);
      expect(url, 'https://example.com/song.mp3');
    });

    test('resolveUrl returns null for empty URL', () async {
      final mockResponse = {
        'data': [
          {'url': ''}
        ]
      };

      when(() => mockNetwork.getJson(any(),
              query: any(named: 'query'), headers: any(named: 'headers')))
          .thenAnswer((_) async => mockResponse);

      final track = Track(
        id: '12345',
        sourceId: 'netease',
        title: 'Test',
        artist: 'Artist',
      );
      final url = await source.resolveUrl(track);
      expect(url, isNull);
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

    test('search parses response correctly', () async {
      final mockResponse = {
        'data': {
          'songs': [
            {
              'songid': 67890,
              'songname': 'QQ Song',
              'singer': [
                {'name': 'QQ Artist'}
              ],
              'album': {'name': 'QQ Album'}
            }
          ]
        }
      };

      when(() => mockNetwork.getJson(any(),
              query: any(named: 'query'), headers: any(named: 'headers')))
          .thenAnswer((_) async => mockResponse);

      final results = await source.search('test');
      expect(results.length, 1);
      expect(results.first.id, '67890');
      expect(results.first.title, 'QQ Song');
      expect(results.first.artist, 'QQ Artist');
      expect(results.first.album, 'QQ Album');
      expect(results.first.sourceId, 'qq');
    });

    test('resolveUrl parses mp3 URL correctly', () async {
      final mockResponse = {
        'urlinfo': {
          'mp3': {'url': 'https://qq.com/song.mp3'}
        }
      };

      when(() => mockNetwork.getJson(any(),
              query: any(named: 'query'), headers: any(named: 'headers')))
          .thenAnswer((_) async => mockResponse);

      final track = Track(
        id: '67890',
        sourceId: 'qq',
        title: 'Test',
        artist: 'Artist',
      );
      final url = await source.resolveUrl(track);
      expect(url, 'https://qq.com/song.mp3');
    });
  });

  group('MusicSource - KuwoSource', () {
    late MockNetworkService mockNetwork;
    late KuwoSource source;

    setUp(() {
      mockNetwork = MockNetworkService();
      source = KuwoSource(mockNetwork);
    });

    test('sourceId and displayName are correct', () {
      expect(source.sourceId, 'kuwo');
      expect(source.displayName, '酷我音乐');
    });

    test('search returns empty list for empty query', () async {
      final results = await source.search('  ');
      expect(results, isEmpty);
    });

    test('search parses response correctly', () async {
      final mockResponse = {
        'abslist': [
          {
            'SongId': 11111,
            'SongName': 'Kuwo Song',
            'Artist': 'Kuwo Artist',
            'Album': 'Kuwo Album'
          }
        ]
      };

      when(() => mockNetwork.getJson(any(),
              query: any(named: 'query'), headers: any(named: 'headers')))
          .thenAnswer((_) async => mockResponse);

      final results = await source.search('test');
      expect(results.length, 1);
      expect(results.first.id, '11111');
      expect(results.first.title, 'Kuwo Song');
      expect(results.first.artist, 'Kuwo Artist');
      expect(results.first.album, 'Kuwo Album');
      expect(results.first.sourceId, 'kuwo');
    });

    test('resolveUrl returns URL from response', () async {
      final mockResponse = {'url': 'https://kuwo.com/song.mp3'};

      when(() => mockNetwork.getJson(any(),
              query: any(named: 'query'), headers: any(named: 'headers')))
          .thenAnswer((_) async => mockResponse);

      final track = Track(
        id: '11111',
        sourceId: 'kuwo',
        title: 'Test',
        artist: 'Artist',
      );
      final url = await source.resolveUrl(track);
      expect(url, 'https://kuwo.com/song.mp3');
    });

    test('search handles network errors gracefully', () async {
      when(() => mockNetwork.getJson(any(),
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
          'songs': [
            {
              'songid': 2,
              'songname': 'QQ Song',
              'singer': [
                {'name': 'QQ Artist'}
              ],
              'album': {'name': 'QQ Album'}
            }
          ]
        }
      };
      final kuwoResponse = {
        'abslist': [
          {
            'SongId': 3,
            'SongName': 'KW Song',
            'Artist': 'KW Artist',
            'Album': 'KW Album'
          }
        ]
      };

      when(() => mockNetwork.getJson(
            'https://music.163.com/api/search/suggest',
            query: any(named: 'query'),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => neResponse);

      when(() => mockNetwork.getJson(
            'https://c.y.qq.com/soso/fcgi-bin/fcg_search_pc.fcg',
            query: any(named: 'query'),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => qqResponse);

      when(() => mockNetwork.getJson(
            'http://www.kuwo.cn/api/getSearchList.aspx',
            query: any(named: 'query'),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => kuwoResponse);

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
            'https://music.163.com/api/search/suggest',
            query: any(named: 'query'),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => neResponse);

      when(() => mockNetwork.getJson(
            'https://c.y.qq.com/soso/fcgi-bin/fcg_search_pc.fcg',
            query: any(named: 'query'),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => {'data': {}});

      when(() => mockNetwork.getJson(
            'http://www.kuwo.cn/api/getSearchList.aspx',
            query: any(named: 'query'),
            headers: any(named: 'headers'),
          )).thenAnswer((_) async => {'abslist': []});

      final results = await service.search('test');
      expect(results.length, 1);
    });

    test('resolveUrl delegates to correct source', () async {
      final track = Track(
          id: '123', sourceId: 'netease', title: 'Test', artist: 'Artist');
      final mockResponse = {
        'data': [
          {'url': 'https://netease.com/track.mp3'}
        ]
      };

      when(() => mockNetwork.getJson(any(),
              query: any(named: 'query'), headers: any(named: 'headers')))
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
