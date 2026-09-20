import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/stored_music_repository.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/music_repository.dart';
import '../../presentation/providers/player_providers.dart' show playerProvider, PlaybackState;
import '../../services/cache/artwork_cache_service.dart';
import '../../services/music_source/music_search_service.dart';
import '../../services/music_source/music_source.dart';
import '../../services/music_source/netease_source.dart';
import '../../services/music_source/qq_source.dart';
import '../../services/music_source/kuwo_source.dart';
import '../../services/lyrics/lyrics_service.dart';
import '../../services/lyrics/lyrics_source.dart';
import '../../services/network/network_service.dart';
import '../../services/storage/preferences_storage_service.dart';
import '../../services/storage/storage_service.dart';
import '../../services/data/data_export_import_service.dart';
import '../../services/download/download_service.dart';
import '../../services/download/download_repository.dart';

/// Must be overridden with an initialized instance before runApp
/// (see main.dart). Tests override it with SharedPreferences.setMockInitialValues.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden with an initialized instance.',
  );
});

final storageProvider = Provider<StorageService>(
  (ref) => PreferencesStorageService(ref.watch(sharedPreferencesProvider)),
);

/// One shared catalog repository per ProviderScope.
final musicRepositoryProvider = Provider<MusicRepository>(
  (ref) => StoredMusicRepository(ref.watch(storageProvider)),
);

/// Real local catalog for the library page. Rebuilds after invalidate().
final catalogListProvider = FutureProvider<List<Track>>((ref) async {
  final repository = ref.watch(musicRepositoryProvider);
  return repository.search('');
});

/// Network transport for music sources. Production uses a single Dio.
final networkServiceProvider = Provider<NetworkService>(
  (ref) => DioNetworkService.withDefaults(),
);

/// All available music sources. Each source owns its own request format.
final musicSourcesProvider = Provider<List<MusicSource>>((ref) {
  final network = ref.watch(networkServiceProvider);
  return [
    NetEaseMusicSource(network),
    QQMusicSource(network),
    KuwoSource(network),
  ];
});

/// Search aggregator across all sources. Rebuilds when sources change.
final musicSearchProvider = Provider<MusicSearchService>((ref) {
  final sources = ref.watch(musicSourcesProvider);
  return MusicSearchService(sources);
});

/// All available lyrics sources.
final lyricsSourcesProvider = Provider<List<LyricsSource>>((ref) {
  final network = ref.watch(networkServiceProvider);
  return [
    NetEaseLyricsSource(network),
    QQLyricsSource(network),
    KuwoLyricsSource(network),
  ];
});

/// Lyrics aggregator service.
final lyricsServiceProvider = Provider<LyricsService>((ref) {
  final sources = ref.watch(lyricsSourcesProvider);
  return LyricsService(sources);
});

/// Artwork cache service (二级缓存：内存 + 磁盘)
final artworkCacheProvider = Provider<ArtworkCacheService>((ref) {
  return ArtworkCacheService.instance;
});

/// 下载服务 Provider
final downloadServiceProvider = Provider<DownloadService>((ref) {
  final repository = ref.watch(downloadRepositoryProvider);
  return DownloadService(repository);
});

/// 数据导出/导入服务 Provider（需 Ref，动态创建）
final dataExportImportServiceProvider = Provider<DataExportImportService>((ref) {
  return DataExportImportService(ref);
});

/// 播放状态变化流 - 供桌面歌词窗口等服务监听
final playbackStateStreamProvider = Provider<Stream<PlaybackState?>>((ref) {
  final controller = StreamController<PlaybackState?>.broadcast();

  // 监听 playerProvider 变化
  ref.listen<PlaybackState?>(playerProvider, (prev, next) {
    controller.add(next);
  });

  ref.onDispose(() {
    controller.close();
  });

  return controller.stream;
});