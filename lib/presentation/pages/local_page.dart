import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/catalog_providers.dart';
import '../providers/local_music_providers.dart'
    show
        ScanState,
        ScanIdle,
        ScanInProgress,
        ScanDone,
        ScanFailed,
        ScanResult,
        scanStateProvider,
        scanDirectoriesProvider,
        localMusicScannerProvider;
import '../providers/player_providers.dart';

/// 本地音乐：真实持久化目录 + 扫描管理
class LocalPage extends ConsumerWidget {
  const LocalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogListProvider);
    final scanState = ref.watch(scanStateProvider);
    final directories = ref.watch(scanDirectoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('本地音乐'),
        actions: [
          IconButton(
            key: const Key('local-refresh'),
            icon: const Icon(Icons.refresh),
            tooltip: '刷新列表',
            onPressed: () => ref.invalidate(catalogListProvider),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'scan':
                  _startScan(ref, context);
                  break;
                case 'manage_dirs':
                  _showDirectoryManager(context, ref);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'scan',
                child: Row(
                  children: [
                    Icon(Icons.folder_open, size: 20),
                    SizedBox(width: 8),
                    Text('扫描目录'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'manage_dirs',
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20),
                    SizedBox(width: 8),
                    Text('管理扫描目录'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 扫描状态栏
          _buildScanStatusBar(context, ref, scanState),

          // 曲目列表
          Expanded(
            child: catalog.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 40),
                    const SizedBox(height: 12),
                    Text('目录读取失败：$error', textAlign: TextAlign.center),
                  ],
                ),
              ),
              data: (tracks) {
                // 目录为空且无扫描状态时，显示引导页
                if (tracks.isEmpty &&
                    directories.isEmpty &&
                    scanState is! ScanInProgress) {
                  return _buildEmptyDirectoryGuide(context, ref);
                }
                // 有目录但无曲目时，显示空列表提示
                if (tracks.isEmpty) {
                  return _buildEmptyTracksView(
                      context, ref, directories.isNotEmpty);
                }
                return ListView.separated(
                  // 虚拟化优化：scrollCacheExtent 预加载可见区域外的项
                  scrollCacheExtent: const ScrollCacheExtent.pixels(500),
                  itemCount: tracks.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final track = tracks[index];
                    final subtitle = [
                      if (track.artist.isNotEmpty) track.artist,
                      if (track.album.isNotEmpty) track.album,
                    ].join(' · ');
                    return ListTile(
                      key: Key('local-track-${track.sourceId}-${track.id}'),
                      leading: const Icon(Icons.music_note),
                      title: Text(track.title),
                      subtitle: subtitle.isEmpty ? null : Text(subtitle),
                      onTap: () async {
                        if (track.url != null) {
                          await ref
                              .read(playerProvider.notifier)
                              .play(track, track.url!);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('该歌曲没有播放地址')),
                          );
                        }
                      },
                      trailing: IconButton(
                        key: Key('local-remove-${track.sourceId}-${track.id}'),
                        icon: const Icon(Icons.delete_outline),
                        tooltip: '删除',
                        onPressed: () async {
                          await ref
                              .read(musicRepositoryProvider)
                              .remove(sourceId: track.sourceId, id: track.id);
                          ref.invalidate(catalogListProvider);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanStatusBar(
      BuildContext context, WidgetRef ref, ScanState scanState) {
    if (scanState is ScanInProgress) {
      return _buildScanProgressBar(context, ref, scanState);
    } else if (scanState is ScanDone) {
      return _buildScanDoneBanner(context, ref, scanState.result);
    } else if (scanState is ScanFailed) {
      return _buildScanErrorBanner(context, ref, scanState.error);
    }
    return const SizedBox.shrink();
  }

  Widget _buildScanProgressBar(
      BuildContext context, WidgetRef ref, ScanInProgress state) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      color: colorScheme.primaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '正在扫描：${state.currentDir}',
                  style: textTheme.bodyMedium
                      ?.copyWith(color: colorScheme.onPrimaryContainer),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${state.foundTracks} 首',
                style: textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onPrimaryContainer),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: state.processedFiles > 0
                ? (state.foundTracks / state.processedFiles).clamp(0.0, 1.0)
                : null,
            backgroundColor:
                colorScheme.onPrimaryContainer.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation(colorScheme.onPrimaryContainer),
          ),
          TextButton(
            onPressed: () => _cancelScan(ref),
            child: Text('取消',
                style: TextStyle(color: colorScheme.onPrimaryContainer)),
          ),
        ],
      ),
    );
  }

  Widget _buildScanDoneBanner(
      BuildContext context, WidgetRef ref, ScanResult result) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      color: colorScheme.tertiaryContainer,
      child: Row(
        children: [
          Icon(Icons.check_circle, color: colorScheme.onTertiaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '扫描完成：${result.totalFiles} 个文件，新增 ${result.newTracks} 首，耗时 ${result.duration.inSeconds}s',
              style: textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onTertiaryContainer),
            ),
          ),
          TextButton(
            onPressed: () => _resetScanState(ref),
            child: Text('关闭',
                style: TextStyle(color: colorScheme.onTertiaryContainer)),
          ),
        ],
      ),
    );
  }

  Widget _buildScanErrorBanner(
      BuildContext context, WidgetRef ref, String error) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      color: colorScheme.errorContainer,
      child: Row(
        children: [
          Icon(Icons.error, color: colorScheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '扫描失败：$error',
              style: textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onErrorContainer),
            ),
          ),
          TextButton(
            onPressed: () => _resetScanState(ref),
            child: Text('关闭',
                style: TextStyle(color: colorScheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDirectoryGuide(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.folder_open,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            '尚未配置扫描目录',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '添加包含音乐文件的文件夹，开始扫描建立本地曲库',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _showDirectoryManager(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('添加扫描目录'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTracksView(
      BuildContext context, WidgetRef ref, bool hasDirectories) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_off,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              hasDirectories ? '目录中暂无音乐文件' : '尚未配置扫描目录',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasDirectories ? '尝试点击右上角菜单执行扫描，或检查目录是否包含支持的音频格式' : '请先添加扫描目录',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (!hasDirectories)
              FilledButton.icon(
                onPressed: () => _showDirectoryManager(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('添加扫描目录'),
              )
            else
              OutlinedButton.icon(
                onPressed: () => _startScan(ref, context),
                icon: const Icon(Icons.refresh),
                label: const Text('开始扫描'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _startScan(WidgetRef ref, BuildContext context) async {
    final scanner = ref.read(localMusicScannerProvider);
    final notifier = ref.read(scanStateProvider.notifier);

    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    notifier.state = const ScanInProgress(
      currentDir: '准备中...',
      processedFiles: 0,
      foundTracks: 0,
    );

    try {
      final result = await scanner.scan();
      // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
      notifier.state = ScanDone(result: result);
      ref.invalidate(catalogListProvider);
    } catch (e) {
      // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
      notifier.state = ScanFailed(error: e.toString());
    }
  }

  void _cancelScan(WidgetRef ref) {
    final scanner = ref.read(localMusicScannerProvider);
    scanner.cancel();
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    ref.read(scanStateProvider.notifier).state = const ScanIdle();
  }

  void _resetScanState(WidgetRef ref) {
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    ref.read(scanStateProvider.notifier).state = const ScanIdle();
  }

  void _showDirectoryManager(BuildContext context, WidgetRef ref) {
    final directories = ref.read(scanDirectoriesProvider);
    final notifier = ref.read(scanDirectoriesProvider.notifier);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => StatefulBuilder(
          builder: (context, setState) => Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      '扫描目录管理',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: '添加目录',
                      onPressed: () =>
                          _pickDirectory(context, notifier, setState),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: directories.isEmpty
                    ? Center(
                        child: Text(
                          '暂无配置目录',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      )
                    : ListView.separated(
                        scrollCacheExtent: const ScrollCacheExtent.pixels(500),
                        controller: scrollController,
                        itemCount: directories.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final dir = directories[index];
                          return ListTile(
                            leading: const Icon(Icons.folder),
                            title: Text(
                              dir,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () {
                                notifier.removeDirectory(dir);
                                setState(() {});
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDirectory(
    BuildContext context,
    dynamic notifier,
    StateSetter setState,
  ) async {
    // 使用 file_picker 或原生目录选择器
    // 这里简化为文本输入
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加扫描目录'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '输入文件夹绝对路径',
            labelText: '目录路径',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('添加'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final dir = Directory(result);
      if (await dir.exists()) {
        notifier.addDirectory(result);
        setState(() {});
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('目录不存在')),
        );
      }
    }
  }
}
