import 'dart:ffi' hide Size;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:win32/win32.dart';
import 'package:ffi/ffi.dart';

/// 窗口管理服务 - 自定义标题栏、最小化到托盘、窗口状态持久化
class WindowManagerService {
  WindowManagerService(this._ref);

  final Ref _ref;
  bool _initialized = false;
  bool _minimizeToTray = true;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    await windowManager.ensureInitialized();

    final windowOptions = WindowOptions(
      minimumSize: const Size(900, 600),
      maximumSize: Size.infinite,
      center: true,
      title: 'Q-Audio',
      titleBarStyle: TitleBarStyle.hidden,
      windowButtonVisibility: false,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
    );

    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    }

    windowManager.addListener(_WindowListener(_ref));

    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      doWhenWindowReady(() {
        appWindow.minSize = const Size(900, 600);
        appWindow.maxSize = const Size(10000, 10000);
        appWindow.alignment = Alignment.center;
        appWindow.title = 'Q-Audio';
        appWindow.show();
      });
    }

    _initialized = true;
  }

  void setMinimizeToTray(bool value) => _minimizeToTray = value;

  Future<void> minimize() async {
    if (!_initialized || kIsWeb) return;
    if (_minimizeToTray) {
      await windowManager.hide();
    } else {
      await windowManager.minimize();
    }
  }

  Future<void> close() async {
    if (!_initialized || kIsWeb) return;
    if (_minimizeToTray) {
      await windowManager.hide();
    } else {
      await windowManager.destroy();
    }
  }

  Future<void> show() async {
    if (!_initialized || kIsWeb) return;
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> toggleMaximize() async {
    if (!_initialized || kIsWeb) return;
    final isMaximized = await windowManager.isMaximized();
    if (isMaximized) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  Future<void> setSize(Size size) async {
    if (!_initialized || kIsWeb) return;
    await windowManager.setSize(size);
  }

  Future<void> setPosition(Offset position) async {
    if (!_initialized || kIsWeb) return;
    await windowManager.setPosition(position);
  }

  Future<WindowState> getWindowState() async {
    if (!_initialized || kIsWeb) return const WindowState();

    final bounds = await windowManager.getBounds();
    return WindowState(
      left: bounds.left,
      top: bounds.top,
      width: bounds.width,
      height: bounds.height,
      isMaximized: await windowManager.isMaximized(),
      isMinimized: await windowManager.isMinimized(),
      isFullScreen: await windowManager.isFullScreen(),
    );
  }

  Future<void> restoreWindowState(WindowState state) async {
    if (!_initialized || kIsWeb) return;

    if (state.isMaximized) {
      await windowManager.maximize();
    } else if (state.isFullScreen) {
      await windowManager.setFullScreen(true);
    } else {
      await windowManager.setBounds(Rect.fromLTWH(
        state.left,
        state.top,
        state.width,
        state.height,
      ));
    }
  }

  Future<void> dispose() async {
    if (!_initialized || kIsWeb) return;
    windowManager.removeListener(_WindowListener(_ref));
    _initialized = false;
  }

  /// 设置开机自启（Windows 注册表）
  Future<void> setAutoStart(bool enabled) async {
    if (!Platform.isWindows) return;

    const appName = 'Q-Audio';
    final executablePath = Platform.resolvedExecutable;
    final hKey = calloc<HKEY>();
    final subKey =
        'Software\\Microsoft\\Windows\\CurrentVersion\\Run'.toNativeUtf16();

    try {
      final result = RegOpenKeyEx(HKEY_CURRENT_USER, subKey, 0, KEY_WRITE, hKey);
      if (result != WIN32_ERROR.ERROR_SUCCESS) {
        throw Exception('Failed to open registry key: $result');
      }

      if (enabled) {
        final valueData = executablePath.toNativeUtf16();
        final result = RegSetValueEx(
          hKey.value,
          appName.toNativeUtf16(),
          0,
          REG_SZ,
          valueData.cast<Uint8>(),
          (executablePath.length + 1) * 2,
        );
        if (result != WIN32_ERROR.ERROR_SUCCESS) {
          throw Exception('Failed to set auto-start: $result');
        }
      } else {
        final result = RegDeleteValue(hKey.value, appName.toNativeUtf16());
        if (result != WIN32_ERROR.ERROR_SUCCESS &&
            result != WIN32_ERROR.ERROR_FILE_NOT_FOUND) {
          throw Exception('Failed to remove auto-start: $result');
        }
      }
    } finally {
      RegCloseKey(hKey.value);
      free(hKey);
      free(subKey);
    }
  }
}

class WindowState {
  const WindowState({
    this.left = 0,
    this.top = 0,
    this.width = 1200,
    this.height = 800,
    this.isMaximized = false,
    this.isMinimized = false,
    this.isFullScreen = false,
  });

  final double left;
  final double top;
  final double width;
  final double height;
  final bool isMaximized;
  final bool isMinimized;
  final bool isFullScreen;

  Map<String, dynamic> toJson() => {
        'left': left,
        'top': top,
        'width': width,
        'height': height,
        'isMaximized': isMaximized,
        'isMinimized': isMinimized,
        'isFullScreen': isFullScreen,
      };

  factory WindowState.fromJson(Map<String, dynamic> json) => WindowState(
        left: (json['left'] as num?)?.toDouble() ?? 0,
        top: (json['top'] as num?)?.toDouble() ?? 0,
        width: (json['width'] as num?)?.toDouble() ?? 1200,
        height: (json['height'] as num?)?.toDouble() ?? 800,
        isMaximized: json['isMaximized'] as bool? ?? false,
        isMinimized: json['isMinimized'] as bool? ?? false,
        isFullScreen: json['isFullScreen'] as bool? ?? false,
      );
}

class _WindowListener extends WindowListener {
  _WindowListener(this._ref);

  final Ref _ref;

  @override
  void onWindowClose() {
    final service = _ref.read(windowManagerServiceProvider);
    service.close();
  }

  @override
  void onWindowMinimize() {}

  @override
  void onWindowMaximize() {}

  @override
  void onWindowUnmaximize() {}
}

final windowManagerServiceProvider = Provider<WindowManagerService>((ref) {
  return WindowManagerService(ref);
});
