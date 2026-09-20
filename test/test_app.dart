import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:q_audio/main.dart';
import 'package:q_audio/presentation/providers/catalog_providers.dart';
import 'package:q_audio/presentation/providers/player_providers.dart' show PlaybackStatus;
import 'package:q_audio/presentation/providers/theme_provider.dart';
import 'package:q_audio/routes/app_router.dart';
import 'package:q_audio/services/desktop/desktop_providers.dart'
    show windowManagerServiceProvider, systemTrayServiceProvider,
         mediaSessionServiceProvider, globalHotkeysServiceProvider,
         desktopLyricsWindowProvider;
import 'package:q_audio/services/desktop/window_manager_service.dart'
    show WindowManagerService, WindowState;
import 'package:q_audio/services/desktop/system_tray_service.dart'
    show SystemTrayService;
import 'package:q_audio/services/desktop/media_session_service.dart'
    show MediaSessionService;
import 'package:q_audio/services/desktop/global_hotkeys_service.dart'
    show GlobalHotkeysService;
import 'package:q_audio/services/desktop/desktop_lyrics_window.dart'
    show DesktopLyricsWindowService;
import 'package:q_audio/services/equalizer/equalizer_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Common mounts; each test gets an isolated router, scope and storage.
/// [overrideThemeMode] false keeps the real restore-from-storage path.
/// [additionalOverrides] lets tests inject fake engines/repositories.
Future<GoRouter> mountApp(
  WidgetTester tester, {
  Size size = const Size(400, 800),
  String location = '/',
  ThemeMode mode = ThemeMode.light,
  bool overrideThemeMode = true,
  Map<String, Object> initialValues = const {'unrelated': 'preserve'},
  List<Override> additionalOverrides = const [],
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  SharedPreferences.setMockInitialValues(initialValues);
  final preferences = await SharedPreferences.getInstance();
  final router = createAppRouter(initialLocation: location);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (overrideThemeMode) themeModeProvider.overrideWith((ref) => mode),
        sharedPreferencesProvider.overrideWithValue(preferences),
        // 测试环境标记：跳过桌面端服务初始化
        testEnvironmentProvider.overrideWith((ref) => true),
        // Mock EqualizerService for tests
        equalizerServiceProvider.overrideWith((ref) => MockEqualizerService()),
        // Mock WindowManagerService for tests
        windowManagerServiceProvider.overrideWith((ref) => MockWindowManagerService()),
        // Mock other desktop services
        systemTrayServiceProvider.overrideWith((ref) => MockSystemTrayService()),
        mediaSessionServiceProvider.overrideWith((ref) => MockMediaSessionService()),
        globalHotkeysServiceProvider.overrideWith((ref) => MockGlobalHotkeysService()),
        desktopLyricsWindowProvider.overrideWith((ref) => MockDesktopLyricsWindowService()),
        ...additionalOverrides,
      ],
      child: QAudioApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

/// Mock EqualizerService for tests - uses test constructor
class MockEqualizerService extends EqualizerService {
  MockEqualizerService() : super.test();

  @override
  String? getCurrentFilter() => null;
}

/// Mock WindowManagerService for tests - implements the same interface
class MockWindowManagerService implements WindowManagerService {
  MockWindowManagerService();

  @override
  Future<void> initialize() async {}

  @override
  void setMinimizeToTray(bool value) {}

  @override
  Future<void> minimize() async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> show() async {}

  @override
  Future<void> toggleMaximize() async {}

  @override
  Future<void> setSize(Size size) async {}

  @override
  Future<void> setPosition(Offset position) async {}

  @override
  Future<WindowState> getWindowState() async => const WindowState();

  @override
  Future<void> restoreWindowState(WindowState state) async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> setAutoStart(bool enabled) async {}
}

class MockSystemTrayService implements SystemTrayService {
  MockSystemTrayService();
  @override Future<void> initialize() async {}
  @override Future<void> updateToolTip(String tip) async {}
  @override Future<void> dispose() async {}
}

class MockMediaSessionService implements MediaSessionService {
  MockMediaSessionService();
  @override Future<void> initialize() async {}
  @override Future<void> syncMetadata({required String title, required String artist, String? album, String? artworkUrl, Duration? duration}) async {}
  @override Future<void> syncPlaybackState({required PlaybackStatus status, required Duration position, Duration? duration, bool shuffleMode = false, bool repeatMode = false}) async {}
  @override Future<void> dispose() async {}
}

class MockGlobalHotkeysService implements GlobalHotkeysService {
  MockGlobalHotkeysService();
  @override Future<void> initialize() async {}
  @override Future<void> registerCustomHotkey(String action, dynamic hotkey) async {}
  @override Future<void> unregisterHotkey(dynamic hotkey) async {}
  @override Future<void> dispose() async {}
}

class MockDesktopLyricsWindowService implements DesktopLyricsWindowService {
  MockDesktopLyricsWindowService();
  @override Future<void> initialize() async {}
  @override Future<void> show() async {}
  @override Future<void> hide() async {}
  @override Future<void> toggle() async {}
  @override Future<void> dispose() async {}
}