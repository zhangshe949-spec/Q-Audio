import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:q_audio/core/theme/app_theme.dart';
import 'package:q_audio/core/constants/app_strings.dart';
import 'package:q_audio/presentation/providers/player_providers.dart';
import 'package:q_audio/presentation/widgets/custom_title_bar.dart';

/// Route layout only; the root MaterialApp lives in QAudioApp.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // 测试环境强制使用移动端布局，避免 bitsdojo_window 原生库依赖
    final isTest = const bool.fromEnvironment('flutter.test');
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            Expanded(
              child: isTest || constraints.maxWidth <= 1000
                  ? _mobileLayout(context)
                  : _desktopLayout(context),
            ),
            const Material(child: _MiniPlayer()),
          ],
        );
      },
    );
  }

  /// 桌面布局：左侧导航栏 + 右侧内容
  Widget _desktopLayout(BuildContext context) {
    return Scaffold(
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(40),
        child: CustomTitleBar(),
      ),
      body: Row(
        children: [
          // 导航栏
          NavigationRail(
            selectedIndex: _currentIndexForDesktop(context),
            onDestinationSelected: (index) =>
                _onDesktopDestinationSelected(context, index),
            labelType: NavigationRailLabelType.selected,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  const Icon(
                    Icons.music_note_rounded,
                    size: 36,
                    color: AppColors.lightPrimary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Q-Audio',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.home_rounded),
                selectedIcon: Icon(
                  Icons.home_rounded,
                  color: AppColors.lightPrimary,
                ),
                label: Text(AppStrings.home),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.search_rounded),
                selectedIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.lightPrimary,
                ),
                label: Text(AppStrings.search),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.radio_rounded),
                selectedIcon: Icon(
                  Icons.radio_rounded,
                  color: AppColors.lightPrimary,
                ),
                label: Text(AppStrings.radio),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.auto_stories_rounded),
                selectedIcon: Icon(
                  Icons.auto_stories_rounded,
                  color: AppColors.lightPrimary,
                ),
                label: Text(AppStrings.audiobook),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.podcasts_rounded),
                selectedIcon: Icon(
                  Icons.podcasts_rounded,
                  color: AppColors.lightPrimary,
                ),
                label: Text(AppStrings.podcast),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.library_music_rounded),
                selectedIcon: Icon(
                  Icons.library_music_rounded,
                  color: AppColors.lightPrimary,
                ),
                label: Text(AppStrings.local),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.playlist_play_rounded),
                selectedIcon: Icon(
                  Icons.playlist_play_rounded,
                  color: AppColors.lightPrimary,
                ),
                label: Text(AppStrings.playlist),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.download_rounded),
                selectedIcon: Icon(
                  Icons.download_rounded,
                  color: AppColors.lightPrimary,
                ),
                label: Text(AppStrings.downloads),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_rounded),
                selectedIcon: Icon(
                  Icons.settings_rounded,
                  color: AppColors.lightPrimary,
                ),
                label: Text(AppStrings.settings),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // 内容区
          Expanded(child: child),
        ],
      ),
    );
  }

  /// 移动布局：底部4 Tab + 内容区
  Widget _mobileLayout(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndexForMobile(context),
        onDestinationSelected: (index) =>
            _onMobileDestinationSelected(context, index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_rounded),
            selectedIcon: Icon(
              Icons.home_rounded,
              color: AppColors.lightPrimary,
            ),
            label: AppStrings.mobileHome,
          ),
          NavigationDestination(
            icon: Icon(Icons.radio_rounded),
            selectedIcon: Icon(
              Icons.radio_rounded,
              color: AppColors.lightPrimary,
            ),
            label: AppStrings.mobileRadio,
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_rounded),
            selectedIcon: Icon(
              Icons.auto_stories_rounded,
              color: AppColors.lightPrimary,
            ),
            label: AppStrings.mobileAudiobook,
          ),
          NavigationDestination(
            icon: Icon(Icons.person_rounded),
            selectedIcon: Icon(
              Icons.person_rounded,
              color: AppColors.lightPrimary,
            ),
            label: AppStrings.mobileMe,
          ),
        ],
      ),
    );
  }

  int _currentIndexForDesktop(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location == '/') return 0;
    if (location == '/search') return 1;
    if (location == '/radio') return 2;
    if (location == '/audiobook') return 3;
    if (location == '/podcast') return 4;
    if (location == '/local') return 5;
    if (location == '/playlist') return 6;
    if (location == '/downloads') return 7;
    if (location == '/settings') return 8;
    return 0;
  }

  int _currentIndexForMobile(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location == '/' || location == '/search') return 0;
    if (location == '/radio') return 1;
    if (location == '/audiobook') return 2;
    if (location == '/podcast' ||
        location == '/local' ||
        location == '/playlist' ||
        location == '/downloads' ||
        location == '/settings') {
      return 3; // “我的”页统一归入最后一个 Tab，实际路由仍走 GoRouter
    }
    return 0;
  }

  void _onDesktopDestinationSelected(BuildContext context, int index) {
    final locations = [
      '/',
      '/search',
      '/radio',
      '/audiobook',
      '/podcast',
      '/local',
      '/playlist',
      '/downloads',
      '/settings',
    ];
    if (index < locations.length) {
      context.go(locations[index]);
    }
  }

  void _onMobileDestinationSelected(BuildContext context, int index) {
    final locations = [
      '/',
      '/radio',
      '/audiobook',
      '/settings', // 示例：点击“我的”跳到设置页作为占位
    ];
    if (index < locations.length) {
      context.go(locations[index]);
    }
  }
}

/// 底部常驻迷你播放条：无歌时显示占位文案，有歌时显示标题与播放/暂停按钮。
/// 阶段4真实音源接入后，点击歌曲行调用 playerProvider 播放即可点亮本条。
class _MiniPlayer extends ConsumerWidget {
  const _MiniPlayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playerProvider);
    if (!playback.hasTrack) {
      return Container(
        height: 56,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Text(
            '${AppStrings.miniPlayer}（占位）',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }
    final playing = playback.status == PlaybackStatus.playing;
    final loading = playback.status == PlaybackStatus.loading;
    final title = playback.track!.title;
    final artist = playback.track!.artist;
    return Container(
      key: const Key('mini-player'),
      height: 56,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.music_note_rounded, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (artist.isNotEmpty)
                  Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          IconButton(
            key: const Key('mini-play-toggle'),
            tooltip: playing ? '暂停' : '播放',
            onPressed: loading
                ? null
                : () {
                    final controller = ref.read(playerProvider.notifier);
                    playing ? controller.pause() : controller.resume();
                  },
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
          ),
        ],
      ),
    );
  }
}
