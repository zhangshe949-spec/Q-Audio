import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../presentation/providers/player_providers.dart'
    show PlaybackStatus, playerProvider;

/// 全局热键服务 - 使用 hotkey_manager 监听系统级快捷键
class GlobalHotkeysService {
  GlobalHotkeysService(this._ref);

  final Ref _ref;
  bool _initialized = false;
  final List<HotKey> _registeredHotkeys = [];

  // 默认热键配置
  static final Map<String, HotKey> _defaultHotkeys = {
    'play_pause': HotKey(
      key: PhysicalKeyboardKey.space,
      modifiers: [HotKeyModifier.alt],
      scope: HotKeyScope.system,
    ),
    'next': HotKey(
      key: PhysicalKeyboardKey.arrowRight,
      modifiers: [HotKeyModifier.alt],
      scope: HotKeyScope.system,
    ),
    'previous': HotKey(
      key: PhysicalKeyboardKey.arrowLeft,
      modifiers: [HotKeyModifier.alt],
      scope: HotKeyScope.system,
    ),
    'volume_up': HotKey(
      key: PhysicalKeyboardKey.arrowUp,
      modifiers: [HotKeyModifier.alt],
      scope: HotKeyScope.system,
    ),
    'volume_down': HotKey(
      key: PhysicalKeyboardKey.arrowDown,
      modifiers: [HotKeyModifier.alt],
      scope: HotKeyScope.system,
    ),
    'toggle_window': HotKey(
      key: PhysicalKeyboardKey.keyW,
      modifiers: [HotKeyModifier.alt, HotKeyModifier.control],
      scope: HotKeyScope.system,
    ),
    'seek_forward': HotKey(
      key: PhysicalKeyboardKey.arrowRight,
      modifiers: [HotKeyModifier.alt, HotKeyModifier.shift],
      scope: HotKeyScope.system,
    ),
    'seek_backward': HotKey(
      key: PhysicalKeyboardKey.arrowLeft,
      modifiers: [HotKeyModifier.alt, HotKeyModifier.shift],
      scope: HotKeyScope.system,
    ),
  };

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    // 注册所有默认热键
    for (final entry in _defaultHotkeys.entries) {
      await _registerHotkey(entry.value, entry.key);
    }

    _initialized = true;
  }

  Future<void> _registerHotkey(HotKey hotkey, String action) async {
    try {
      await hotKeyManager.register(
        hotkey,
        keyDownHandler: (hk) => _handleHotkey(action),
      );
      _registeredHotkeys.add(hotkey);
    } catch (e) {
      // 热键可能已被占用，忽略错误
      debugPrint('Failed to register hotkey $action: $e');
    }
  }

  void _handleHotkey(String action) {
    final controller = _ref.read(playerProvider.notifier);
    final playback = _ref.read(playerProvider);

    switch (action) {
      case 'play_pause':
        if (playback.status == PlaybackStatus.playing) {
          controller.pause();
        } else {
          controller.resume();
        }
        break;
      case 'next':
        controller.next();
        break;
      case 'previous':
        controller.previous();
        break;
      case 'volume_up':
        controller.setVolume((playback.volume + 0.1).clamp(0.0, 1.0));
        break;
      case 'volume_down':
        controller.setVolume((playback.volume - 0.1).clamp(0.0, 1.0));
        break;
      case 'toggle_window':
        _toggleWindow();
        break;
      case 'seek_forward':
        controller.seek(playback.position + const Duration(seconds: 10));
        break;
      case 'seek_backward':
        controller.seek(playback.position - const Duration(seconds: 10));
        break;
      default:
        break;
    }
  }

  Future<void> _toggleWindow() async {
    if (kIsWeb) return;
    final isVisible = await windowManager.isVisible();
    if (isVisible) {
      await windowManager.hide();
    } else {
      await windowManager.show();
      await windowManager.focus();
    }
  }

  /// 自定义热键（用户可在设置中修改）
  Future<void> registerCustomHotkey(String action, HotKey hotkey) async {
    if (!_initialized || kIsWeb) return;
    await _registerHotkey(hotkey, action);
  }

  Future<void> unregisterHotkey(HotKey hotkey) async {
    if (!_initialized || kIsWeb) return;
    try {
      await hotKeyManager.unregister(hotkey);
      _registeredHotkeys.remove(hotkey);
    } catch (_) {}
  }

  Future<void> dispose() async {
    if (!_initialized || kIsWeb) return;
    for (final hotkey in _registeredHotkeys) {
      await hotKeyManager.unregister(hotkey);
    }
    _registeredHotkeys.clear();
    _initialized = false;
  }
}

final globalHotkeysServiceProvider = Provider<GlobalHotkeysService>((ref) {
  return GlobalHotkeysService(ref);
});