import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

import '../../services/playback/player_controller.dart' show PlaybackStatus;
import '../../presentation/providers/player_providers.dart' show playerProvider;

/// 自定义标题栏 - 根据平台自动选择实现
class CustomTitleBar extends ConsumerWidget implements PreferredSizeWidget {
  const CustomTitleBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(40);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 测试环境、Web、移动端使用简化版标题栏
    if (const bool.fromEnvironment('flutter.test') ||
        kIsWeb ||
        !(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return const _SimpleTitleBar();
    }

    // 桌面端使用 bitsdojo_window 实现
    return _DesktopTitleBar();
  }
}

/// 简化版标题栏（测试环境、移动端、Web 使用）
class _SimpleTitleBar extends StatelessWidget implements PreferredSizeWidget {
  const _SimpleTitleBar();

  @override
  Size get preferredSize => const Size.fromHeight(40);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 40,
      color: colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.music_note_rounded,
              size: 20, color: Color(0xFF6C5CE7)),
          const SizedBox(width: 8),
          Text(
            'Q-Audio',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
          ),
        ],
      ),
    );
  }
}

/// 移动端/自适应标题栏（无窗口按钮，用于移动端或不支持自定义标题栏的平台）
class AdaptiveTitleBar extends ConsumerWidget implements PreferredSizeWidget {
  const AdaptiveTitleBar({super.key, this.showMenuButton = true});

  final bool showMenuButton;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playerProvider);

    return AppBar(
      title: const Text('Q-Audio'),
      centerTitle: false,
      leading: showMenuButton
          ? Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            )
          : null,
      actions: [
        if (playback.hasTrack)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous_rounded),
                  onPressed: () => ref.read(playerProvider.notifier).previous(),
                ),
                IconButton(
                  icon: Icon(playback.status == PlaybackStatus.playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded),
                  onPressed: () {
                    final controller = ref.read(playerProvider.notifier);
                    playback.status == PlaybackStatus.playing
                        ? controller.pause()
                        : controller.resume();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded),
                  onPressed: () => ref.read(playerProvider.notifier).next(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 自适应标题栏选择器 - 根据平台自动选择
class AppTitleBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTitleBar({super.key, this.showMenuButton = true});

  final bool showMenuButton;

  @override
  Size get preferredSize {
    if (_isDesktop) {
      return const Size.fromHeight(40);
    }
    return const Size.fromHeight(kToolbarHeight);
  }

  bool get _isDesktop {
    return !kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
  }

  @override
  Widget build(BuildContext context) {
    if (_isDesktop) {
      return const CustomTitleBar();
    }
    return AdaptiveTitleBar(showMenuButton: showMenuButton);
  }
}

/// 桌面端标题栏实现（使用 bitsdojo_window）
/// 仅在桌面端构建时编译，测试环境通过 flutter.test 常量跳过
class _DesktopTitleBar extends ConsumerWidget implements PreferredSizeWidget {
  const _DesktopTitleBar();

  @override
  Size get preferredSize => const Size.fromHeight(40);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WindowTitleBarBox(
      child: MoveWindow(
        child: Container(
          height: 40,
          color: isDark
              ? colorScheme.surfaceContainerHighest.withOpacity(0.8)
              : colorScheme.surface.withOpacity(0.9),
          child: Row(
            children: [
              // 应用图标和标题
              Expanded(
                child: MoveWindow(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.music_note_rounded,
                            size: 20, color: Color(0xFF6C5CE7)),
                        const SizedBox(width: 8),
                        Text(
                          'Q-Audio',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 窗口控制按钮组
              const _WindowButtons(),
            ],
          ),
        ),
      ),
    );
  }
}

/// 窗口控制按钮
class _WindowButtons extends StatelessWidget {
  const _WindowButtons();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        MinimizeWindowButton(
          colors: WindowButtonColors(
            mouseOver: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            mouseDown: colorScheme.surfaceContainerHighest.withOpacity(0.8),
            iconNormal: colorScheme.onSurfaceVariant,
            iconMouseOver: colorScheme.onSurface,
            iconMouseDown: colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        MaximizeWindowButton(
          colors: WindowButtonColors(
            mouseOver: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            mouseDown: colorScheme.surfaceContainerHighest.withOpacity(0.8),
            iconNormal: colorScheme.onSurfaceVariant,
            iconMouseOver: colorScheme.onSurface,
            iconMouseDown: colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        CloseWindowButton(
          colors: WindowButtonColors(
            mouseOver: colorScheme.error,
            mouseDown: colorScheme.error.withOpacity(0.8),
            iconNormal: colorScheme.onSurface,
            iconMouseOver: Colors.white,
            iconMouseDown: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}
