import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'presentation/providers/catalog_providers.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/player_providers.dart' show playerProvider;
import 'presentation/pages/download_page.dart'
    show downloadTasksProvider;
import 'presentation/pages/playlist_page.dart'
    show playlistsProvider;
import 'routes/app_router.dart';
import 'services/desktop/desktop_providers.dart';
import 'services/equalizer/equalizer_providers.dart';
import 'services/playback/media_kit_engine.dart';
import 'services/playback/player_controller.dart';

/// 测试环境标记 - 生产为 false，测试中由 test_app.dart 覆盖为 true
final testEnvironmentProvider = Provider<bool>((ref) => false);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        audioEngineProvider.overrideWith((ref) => MediaKitAudioEngine()),
        equalizerServiceProvider.overrideWith((ref) {
          return EqualizerService(preferences);
        }),
      ],
      child: QAudioApp(router: createAppRouter()),
    ),
  );
}

class QAudioApp extends ConsumerWidget {
  const QAudioApp({super.key, required this.router});
  final GoRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themePersistenceProvider);
    ref.watch(themeRestoreProvider);
    ref.watch(equalizerEnabledProvider);
    ref.watch(equalizerCurrentPresetProvider);
    ref.watch(equalizerCustomGainsProvider);
    ref.watch(downloadTasksProvider);
    ref.watch(playlistsProvider);

    // 仅在非测试环境初始化桌面端服务
    final isTest = ref.watch(testEnvironmentProvider);
    if (!isTest) {
      _initDesktopServices(ref);
    }

    return MaterialApp.router(
      title: 'Q-Audio / 亲-音乐',
      debugShowCheckedModeBanner: false,
      theme: AppThemes.light,
      darkTheme: AppThemes.dark,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
    );
  }

  void _initDesktopServices(WidgetRef ref) {
    ref.read(windowManagerServiceProvider).initialize();
    ref.read(systemTrayServiceProvider).initialize();
    ref.read(mediaSessionServiceProvider).initialize();
    ref.read(globalHotkeysServiceProvider).initialize();
    ref.read(desktopLyricsWindowProvider).initialize();
    _setupPlaybackSync(ref);
  }

  void _setupPlaybackSync(WidgetRef ref) {
    ref.listen<PlaybackState?>(playerProvider, (previous, next) {
      if (next == null) return;
      final playback = next;

      final mediaSession = ref.read(mediaSessionServiceProvider);
      if (playback.track != null) {
        final track = playback.track!;
        mediaSession.syncMetadata(
          title: track.title,
          artist: track.artist,
          album: track.album,
          artworkUrl: track.artworkUrl,
          duration: track.duration,
        );
      }
      mediaSession.syncPlaybackState(
        status: playback.status,
        position: playback.position,
        duration: playback.track?.duration,
        shuffleMode: playback.shuffleMode,
        repeatMode: playback.repeatMode,
      );

      final tray = ref.read(systemTrayServiceProvider);
      if (playback.track != null) {
        tray.updateToolTip(
          '${playback.track!.title} - ${playback.track!.artist}',
        );
      }
    });
  }
}