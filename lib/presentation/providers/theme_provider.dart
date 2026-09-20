import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'catalog_providers.dart';

/// 主题模式状态（浅色 / 深色 / 跟随系统）。
/// 不 watch themeRestoreProvider：恢复逻辑单向写回本状态，
/// 避免"恢复完成→依赖变化→重建重置回默认"的环。
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

/// 启动时尽力恢复持久化主题（由 QAudioApp watch 激活）。
/// 存储不可用或值损坏时保持默认，不崩应用。
final themeRestoreProvider = FutureProvider<void>((ref) async {
  try {
    final raw = await ref.watch(storageProvider).read('themeMode');
    if (raw == null) return;
    for (final mode in ThemeMode.values) {
      if (mode.name == raw) {
        ref.read(themeModeProvider.notifier).state = mode;
        return;
      }
    }
  } catch (_) {
    // 存储不可用或数据损坏：保持默认主题模式。
  }
});

/// 主题变化尽力持久化到命名空间存储，失败不影响界面。
final themePersistenceProvider = Provider<void>((ref) {
  ref.listen<ThemeMode>(themeModeProvider, (previous, next) {
    unawaited(() async {
      try {
        await ref.read(storageProvider).write('themeMode', next.name);
      } catch (_) {
        // 持久化失败：会话内仍保留所选模式。
      }
    }());
  });
});
