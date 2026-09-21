import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

import '../../presentation/providers/player_providers.dart'
    show PlaybackStatus, playerProvider;

/// 系统托盘服务
class SystemTrayService {
  SystemTrayService(this._ref);

  final Ref _ref;
  final SystemTray _systemTray = SystemTray();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    String iconPath;
    if (Platform.isWindows) {
      // system_tray on Windows needs absolute path to .ico file
      final directory = await getApplicationDocumentsDirectory();
      final iconFile = File('${directory.path}/app_icon.ico');
      if (!await iconFile.exists()) {
        // Copy from Flutter assets
        final assetData = await rootBundle.load('assets/app_icon.ico');
        await iconFile.writeAsBytes(assetData.buffer.asUint8List());
      }
      iconPath = iconFile.path;
    } else {
      iconPath = 'assets/app_icon.ico';
    }

    await _systemTray.initSystemTray(
      title: 'Q-Audio',
      iconPath: iconPath,
    );

    final menu = Menu();
    await menu.buildFrom([
      MenuItemLabel(
        label: '显示主窗口',
        onClicked: (_) => _showWindow(),
      ),
      MenuItemLabel(
        label: '播放/暂停',
        onClicked: (_) => _togglePlayPause(),
      ),
      MenuItemLabel(
        label: '下一首',
        onClicked: (_) => _playNext(),
      ),
      MenuItemLabel(
        label: '上一首',
        onClicked: (_) => _playPrevious(),
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: '退出',
        onClicked: (_) => _quitApp(),
      ),
    ]);

    await _systemTray.setContextMenu(menu);

    _systemTray.registerSystemTrayEventHandler((event) {
      // event is a String like 'leftClick', 'rightClick', etc.
      if (event == 'leftClick' || event == 'doubleClick') {
        _showWindow();
      }
    });

    _initialized = true;
  }

  Future<void> _showWindow() async {
    if (kIsWeb) return;
    await windowManager.show();
    await windowManager.focus();
  }

  void _togglePlayPause() {
    final controller = _ref.read(playerProvider.notifier);
    final playback = _ref.read(playerProvider);
    if (playback.status == PlaybackStatus.playing) {
      controller.pause();
    } else {
      controller.resume();
    }
  }

  void _playNext() {
    final controller = _ref.read(playerProvider.notifier);
    controller.next();
  }

  void _playPrevious() {
    final controller = _ref.read(playerProvider.notifier);
    controller.previous();
  }

  void _quitApp() {
    _systemTray.destroy();
    exit(0);
  }

  Future<void> updateToolTip(String text) async {
    if (!_initialized || kIsWeb) return;
    await _systemTray.setSystemTrayInfo(toolTip: text);
  }

  Future<void> dispose() async {
    if (!_initialized || kIsWeb) return;
    await _systemTray.destroy();
    _initialized = false;
  }
}

final systemTrayServiceProvider = Provider<SystemTrayService>((ref) {
  return SystemTrayService(ref);
});
