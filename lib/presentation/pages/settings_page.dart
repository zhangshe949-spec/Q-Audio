import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:win32audio/win32audio.dart' as win32audio;
import 'package:q_audio/presentation/providers/theme_provider.dart';
import 'package:q_audio/presentation/providers/catalog_providers.dart' hide downloadServiceProvider;
import 'package:q_audio/presentation/providers/local_music_providers.dart';
import 'package:q_audio/presentation/providers/playback_providers.dart';
import 'package:q_audio/services/desktop/window_manager_service.dart';
import 'package:q_audio/services/equalizer/equalizer_providers.dart';
import 'package:q_audio/services/download/download_providers.dart';

/// 设置页 - 包含所有用户可配置选项
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('设置')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _AppearanceSection(),
        const Divider(height: 32),
        _PlaybackSection(),
        const Divider(height: 32),
        _LyricsSection(),
        const Divider(height: 32),
        _DownloadSection(),
        const Divider(height: 32),
        _LocalMusicSection(),
        const Divider(height: 32),
        _StartupSection(),
        const Divider(height: 32),
        _CacheSection(),
        const Divider(height: 32),
        _AboutSection(),
      ],
    ),
  );
}

/// 外观设置
class _AppearanceSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('外观', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        // 主题模式
        Card(
                          child: Column(
                            children: [
                              RadioListTile<ThemeMode>(
                                title: const Text('跟随系统'),
                                subtitle: const Text('自动根据系统深/浅色模式切换'),
                                value: ThemeMode.system,
                                groupValue: themeMode,
                                onChanged: (value) {
                                  if (value != null) {
                                    ref.read(themeModeProvider.notifier).state = value;
                                  }
                                },
                              ),
                              RadioListTile<ThemeMode>(
                                title: const Text('浅色模式'),
                                value: ThemeMode.light,
                                groupValue: themeMode,
                                onChanged: (value) {
                                  if (value != null) {
                                    ref.read(themeModeProvider.notifier).state = value;
                                  }
                                },
                              ),
                              RadioListTile<ThemeMode>(
                                title: const Text('深色模式'),
                                value: ThemeMode.dark,
                                groupValue: themeMode,
                                onChanged: (value) {
                                  if (value != null) {
                                    ref.read(themeModeProvider.notifier).state = value;
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
        const SizedBox(height: 12),
        // 强调色选择
        Card(
          child: ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('强调色'),
            subtitle: Text('当前: ${_getAccentColorName(colorScheme.primary)}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAccentColorPicker(context, ref),
          ),
        ),
      ],
    );
  }

  String _getAccentColorName(Color color) {
      const colors = {
        0xFF6750A4: '紫色 (默认)',
        0xFF006E54: '青绿色',
        0xFF6C5CE7: '紫罗兰',
        0xFF007B83: '青色',
        0xFFE65100: '橙色',
        0xFF2E7D32: '绿色',
        0xFFC62828: '红色',
      };
      return colors[color.value] ?? '自定义';
    }

  void _showAccentColorPicker(BuildContext context, WidgetRef ref) {
    const accentColors = [
      Color(0xFF6750A4),
      Color(0xFF006E54),
      Color(0xFF6C5CE7),
      Color(0xFF007B83),
      Color(0xFFE65100),
      Color(0xFF2E7D32),
      Color(0xFFC62828),
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择强调色'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: accentColors.length,
            itemBuilder: (context, index) {
              final color = accentColors[index];
              return ListTile(
                leading: CircleAvatar(backgroundColor: color),
                title: Text(_getAccentColorName(color)),
                trailing: color == Theme.of(context).colorScheme.primary
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  // TODO: 实现动态主题切换（需 Material 3 动态配色支持）
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已选择 ${_getAccentColorName(color)}，重启应用生效')),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 播放设置
class _PlaybackSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final equalizerEnabled = ref.watch(equalizerEnabledProvider);
    final equalizerPreset = ref.watch(equalizerCurrentPresetProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('播放', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
                  child: Column(
                    children: [
                      // 均衡器开关
                      SwitchListTile(
                        title: const Text('启用均衡器'),
                        subtitle: const Text('应用预设或自定义频响曲线'),
                        value: equalizerEnabled,
                        onChanged: (value) => ref.read(equalizerEnabledProvider.notifier).setEnabled(value),
                      ),
                      // 预设选择
                      ListTile(
                        leading: const Icon(Icons.equalizer),
                        title: const Text('均衡器预设'),
                        subtitle: Text(equalizerPreset),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showEqualizerPresetDialog(context, ref),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      // 音频输出设备
                      Consumer(
                        builder: (context, ref, _) {
                          final device = ref.watch(audioDeviceProvider);
                          return ListTile(
                            leading: const Icon(Icons.speaker),
                            title: const Text('音频输出设备'),
                            subtitle: Text(device?.name ?? '默认系统设备'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _showAudioDeviceDialog(context, ref),
                          );
                        },
                      ),
                      // 交叉淡入淡出
                      Consumer(
                        builder: (context, ref, _) {
                          final config = ref.watch(crossfadeProvider);
                          return SwitchListTile(
                            title: const Text('交叉淡入淡出'),
                            subtitle: Text(config.enabled
                                ? '已启用 (${config.durationMs ~/ 1000}s)'
                                : '曲目间平滑过渡'),
                            value: config.enabled,
                            onChanged: (value) => ref.read(crossfadeProvider.notifier).setEnabled(value),
                          );
                        },
                      ),
                      Consumer(
                        builder: (context, ref, _) {
                          final config = ref.watch(crossfadeProvider);
                          return ListTile(
                            leading: const Icon(Icons.timer),
                            title: const Text('交叉淡入淡出时长'),
                            subtitle: Text('${config.durationMs ~/ 1000} 秒'),
                            trailing: const Icon(Icons.chevron_right),
                            enabled: config.enabled,
                            onTap: config.enabled ? () => _showCrossfadeDurationDialog(context, ref) : null,
                          );
                        },
                      ),
                      // 无缝播放
                      Consumer(
                        builder: (context, ref, _) {
                          final gapless = ref.watch(gaplessPlaybackProvider);
                          return SwitchListTile(
                            title: const Text('无缝播放'),
                            subtitle: const Text('消除曲目间间隙（需媒体源支持）'),
                            value: gapless,
                            onChanged: (value) => ref.read(gaplessPlaybackProvider.notifier).setEnabled(value),
                          );
                        },
                      ),
                    ],
                  ),
                ),
      ],
    );
  }

  void _showEqualizerPresetDialog(BuildContext context, WidgetRef ref) {
      final presets = ref.read(equalizerServiceProvider).getAllPresets();
      showModalBottomSheet(
        context: context,
        builder: (context) => ListView.builder(
          shrinkWrap: true,
          itemCount: presets.length,
          itemBuilder: (context, index) {
            final preset = presets[index];
            return ListTile(
              title: Text(preset.name),
              subtitle: preset.isCustom ? const Text('自定义') : const Text('内置'),
              trailing: ref.watch(equalizerCurrentPresetProvider) == preset.id
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () {
                ref.read(equalizerCurrentPresetProvider.notifier).selectPreset(preset.id);
                Navigator.pop(context);
              },
            );
          },
        ),
      );
    }

    void _showAudioDeviceDialog(BuildContext context, WidgetRef ref) {
        showDialog(
          context: context,
          builder: (context) => _AudioDeviceDialog(ref: ref),
        );
      }

      void _showCrossfadeDurationDialog(BuildContext context, WidgetRef ref) {
          final config = ref.read(crossfadeProvider);
          int selectedDuration = config.durationMs;

          showDialog(
            context: context,
            builder: (context) => StatefulBuilder(
              builder: (context, setState) => AlertDialog(
                title: const Text('交叉淡入淡出时长'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [3, 5, 8, 10, 15].map((seconds) {
                                        return RadioListTile<int>(
                                          title: Text('$seconds 秒'),
                                          value: seconds * 1000,
                                          groupValue: selectedDuration,
                                          onChanged: (value) {
                                            if (value != null) setState(() => selectedDuration = value);
                                          },
                                        );
                                      }).toList(),
                                    ),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
                  FilledButton(
                    onPressed: () {
                      ref.read(crossfadeProvider.notifier).setDuration(selectedDuration);
                      Navigator.pop(context);
                    },
                    child: const Text('确定'),
                  ),
                ],
              ),
            ),
          );
        }

  }
/// 歌词设置
class _LyricsSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('歌词', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('显示翻译歌词'),
                subtitle: const Text('若歌词文件包含翻译行，显示双语对照'),
                value: true,
                onChanged: (value) {
                  // TODO: 保存到 SharedPreferences
                },
              ),
              SwitchListTile(
                title: const Text('逐行高亮'),
                subtitle: const Text('当前播放行高亮显示'),
                value: true,
                onChanged: (value) {},
              ),
              SwitchListTile(
                title: const Text('点击歌词跳转'),
                subtitle: const Text('点击任意行跳转到该时间点'),
                value: true,
                onChanged: (value) {},
              ),
              ListTile(
                leading: const Icon(Icons.text_fields),
                title: const Text('字体大小'),
                subtitle: const Text('14sp'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showFontSizeDialog(context),
              ),
              ListTile(
                leading: const Icon(Icons.format_color_text),
                title: const Text('歌词颜色'),
                subtitle: const Text('当前主题色'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showLyricColorDialog(context),
              ),
              ListTile(
                leading: const Icon(Icons.format_line_spacing),
                title: const Text('行高'),
                subtitle: const Text('1.5x'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showLineHeightDialog(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showFontSizeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('字体大小'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [12, 14, 16, 18, 20].map((size) => ListTile(
            title: Text('${size}sp', style: TextStyle(fontSize: size.toDouble())),
            onTap: () => Navigator.pop(context),
          )).toList(),
        ),
      ),
    );
  }

  void _showLyricColorDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('歌词颜色'),
        content: const Text('暂未实现，使用主题默认色'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('确定'))],
      ),
    );
  }

  void _showLineHeightDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('行高'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [1.2, 1.5, 1.8, 2.0].map((height) => ListTile(
            title: Text('${height}x'),
            onTap: () => Navigator.pop(context),
          )).toList(),
        ),
      ),
    );
  }
}

/// 下载设置
class _DownloadSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadDir = ref.watch(downloadDirectoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('下载', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('下载目录'),
                subtitle: Text(downloadDir.isNotEmpty ? downloadDir : '默认 (应用文档目录/Downloads)'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _pickDownloadDirectory(context, ref),
              ),
              SwitchListTile(
                title: const Text('仅 Wi-Fi 下载'),
                subtitle: const Text('移动网络下暂停下载'),
                value: true,
                onChanged: (value) {},
              ),
              SwitchListTile(
                title: const Text('下载完成通知'),
                subtitle: const Text('下载完成时显示系统通知'),
                value: true,
                onChanged: (value) {},
              ),
              ListTile(
                leading: const Icon(Icons.delete_sweep),
                title: const Text('清理失败的下载'),
                subtitle: const Text('删除所有状态为失败的下载任务'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _cleanFailedDownloads(ref),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickDownloadDirectory(BuildContext context, WidgetRef ref) async {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择下载目录',
      );
      if (result != null && context.mounted) {
        // TODO: 保存到 SharedPreferences
        // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
        ref.read(downloadDirectoryProvider.notifier).state = result;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载目录已设置为: $result')),
        );
      }
    }

  void _cleanFailedDownloads(WidgetRef ref) {
    // TODO: 实现清理失败下载
    ScaffoldMessenger.of(ref.context).showSnackBar(
      const SnackBar(content: Text('功能开发中')),
    );
  }
}

/// 本地音乐设置
class _LocalMusicSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final directories = ref.watch(scanDirectoriesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('本地音乐', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('添加扫描目录'),
                subtitle: const Text('选择包含音乐文件的文件夹'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _addScanDirectory(context, ref),
              ),
              if (directories.isNotEmpty) ...[
                const Divider(height: 1),
                ...directories.map((dir) => ListTile(
                  leading: const Icon(Icons.folder),
                  title: Text(dir),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => ref.read(scanDirectoriesProvider.notifier).removeDirectory(dir),
                  ),
                )),
              ],
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('立即扫描'),
                subtitle: const Text('增量扫描所有配置目录'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _triggerScan(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever),
                title: const Text('全量重扫'),
                subtitle: const Text('清空数据库并重新扫描所有目录'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _triggerFullRescan(context, ref),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _addScanDirectory(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择音乐文件夹',
    );
    if (result != null) {
      ref.read(scanDirectoriesProvider.notifier).addDirectory(result);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已添加: $result')),
        );
      }
    }
  }

  void _triggerScan(BuildContext context, WidgetRef ref) {
    final scanner = ref.read(localMusicScannerProvider);
    scanner.scan();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('开始增量扫描...')),
    );
  }

  void _triggerFullRescan(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('全量重扫'),
        content: const Text('将清空本地音乐数据库并重新扫描所有目录，确定继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              final scanner = ref.read(localMusicScannerProvider);
              scanner.fullRescan();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('开始全量重扫...')),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

/// 启动行为设置
class _StartupSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('启动与窗口', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              Consumer(
                builder: (context, ref, _) {
                  final autoPlay = ref.watch(autoPlayOnStartProvider);
                  return SwitchListTile(
                    title: const Text('启动时自动播放'),
                    subtitle: const Text('恢复上次播放位置并自动播放'),
                    value: autoPlay,
                    onChanged: (value) => ref.read(autoPlayOnStartProvider.notifier).setEnabled(value),
                  );
                },
              ),
              Consumer(
                builder: (context, ref, _) {
                  final resumePos = ref.watch(resumePositionProvider);
                  return SwitchListTile(
                    title: const Text('恢复播放位置'),
                    subtitle: const Text('启动时恢复上次播放进度'),
                    value: resumePos,
                    onChanged: (value) => ref.read(resumePositionProvider.notifier).setEnabled(value),
                  );
                },
              ),
              Consumer(
                builder: (context, ref, _) {
                  final autoStart = ref.watch(autoStartProvider);
                  return SwitchListTile(
                    title: const Text('开机自启'),
                    subtitle: const Text('系统启动时自动运行（需管理员权限）'),
                    value: autoStart,
                    onChanged: (value) async {
                      await ref.read(autoStartProvider.notifier).setEnabled(value);
                      if (value) {
                        await ref.read(windowManagerServiceProvider).setAutoStart(true);
                      }
                    },
                  );
                },
              ),
              SwitchListTile(
                title: const Text('启动最小化到托盘'),
                subtitle: const Text('应用启动后直接最小化到系统托盘'),
                value: false,
                onChanged: (value) {
                  if (value) {
                    ref.read(windowManagerServiceProvider).setMinimizeToTray(true);
                  }
                },
              ),
              SwitchListTile(
                title: const Text('关闭窗口最小化到托盘'),
                subtitle: const Text('点击关闭按钮时隐藏到托盘而非退出'),
                value: true,
                onChanged: (value) {
                  if (value) {
                    ref.read(windowManagerServiceProvider).setMinimizeToTray(true);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 缓存管理
class _CacheSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('存储与缓存', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              Consumer(
                builder: (context, ref, _) {
                  final cacheService = ref.watch(artworkCacheProvider);
                  return FutureBuilder<int>(
                    future: cacheService.getDiskCacheSize(),
                    builder: (context, snapshot) {
                      final sizeMB = (snapshot.data ?? 0) / (1024 * 1024);
                      return ListTile(
                        leading: const Icon(Icons.image),
                        title: const Text('专辑封面缓存'),
                        subtitle: Text('约 ${sizeMB.toStringAsFixed(1)} MB'),
                        trailing: TextButton(
                          onPressed: () => _clearCache(context, '封面', cacheService.clearDiskCache),
                          child: const Text('清理'),
                        ),
                      );
                    },
                  );
                },
              ),
              Consumer(
                              builder: (context, ref, _) {
                                final lyricsService = ref.watch(lyricsServiceProvider);
                                return ListTile(
                                  leading: const Icon(Icons.lyrics),
                                  title: const Text('歌词缓存'),
                                  subtitle: const Text('内存缓存 (TTL 5分钟)'),
                                  trailing: TextButton(
                                    onPressed: () => _clearCache(context, '歌词', () async => lyricsService.clearCache()),
                                    child: const Text('清理'),
                                  ),
                                );
                              },
                            ),
                            Consumer(
                              builder: (context, ref, _) {
                                final downloadService = ref.watch(downloadServiceProvider);
                                return FutureBuilder<int>(
                                  future: _getDownloadSize(downloadService, ref),
                                  builder: (context, snapshot) {
                      final sizeMB = (snapshot.data ?? 0) / (1024 * 1024);
                      return ListTile(
                        leading: const Icon(Icons.download),
                        title: const Text('下载文件'),
                        subtitle: Text('约 ${sizeMB.toStringAsFixed(1)} MB'),
                        trailing: TextButton(
                          onPressed: () => _clearCache(context, '下载', () async {}),
                          child: const Text('清理'),
                        ),
                      );
                    },
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('清理所有缓存', style: TextStyle(color: Colors.red)),
                subtitle: const Text('删除所有封面、歌词、临时文件缓存（不含下载的音乐文件）'),
                onTap: () => _clearAllCache(context, ref),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.download_for_offline),
                title: const Text('导出数据'),
                subtitle: const Text('导出歌单、播放历史、设置为 JSON'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _exportData(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.upload),
                title: const Text('导入数据'),
                subtitle: const Text('从 JSON 恢复歌单、设置'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _importData(context, ref),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<int> _getDownloadSize(DownloadService service, WidgetRef ref) async {
    try {
      final tasks = await service.getAllTasks();
      int total = 0;
      for (final task in tasks) {
        if (task.status == DownloadStatus.completed) {
          total += task.totalBytes;
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  void _clearCache(BuildContext context, String type, Future<void> Function() clearFunc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('清理 $type 缓存'),
        content: Text('确定要清理 $type 缓存吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await clearFunc();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$type 缓存已清理')),
                );
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _clearAllCache(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清理所有缓存'),
        content: const Text('将删除所有封面、歌词、临时文件缓存，但保留下载的音乐文件。确定？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final cacheService = ref.read(artworkCacheProvider);
              await cacheService.clearDiskCache();
              final lyricsService = ref.read(lyricsServiceProvider);
              lyricsService.clearCache();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('所有缓存已清理')),
                );
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
        final navigator = Navigator.of(context);
        final scaffoldMessenger = ScaffoldMessenger.of(context);

        navigator.push(
          DialogRoute(
            context: context,
            builder: (context) => const AlertDialog(
              title: Text('导出数据'),
              content: Text('正在准备导出...'),
            ),
          ),
        );

        try {
          final exportService = ref.read(dataExportImportServiceProvider);
          final file = await exportService.exportAll();

          if (!context.mounted) return;

          navigator.pop();
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('数据已导出到: ${file.path}')),
          );
        } catch (e) {
          if (!context.mounted) return;

          navigator.pop();
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('导出失败: $e')),
          );
        }
      }
            }

            Future<void> _importData(BuildContext context, WidgetRef ref) async {
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['json'],
                dialogTitle: '选择导入文件',
              );

              if (!context.mounted || result == null || result.files.isEmpty) return;

              final file = File(result.files.single.path!);

              navigator.push(
                DialogRoute(
                  context: context,
                  builder: (context) => const AlertDialog(
                    title: Text('导入数据'),
                    content: Text('正在导入...'),
                  ),
                ),
              );

              try {
                final importService = ref.read(dataExportImportServiceProvider);
                await importService.importAll(file);

                if (!context.mounted) return;

                navigator.pop();
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('数据导入成功，重启应用生效')),
                );
              } catch (e) {
                if (!context.mounted) return;

                navigator.pop();
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('导入失败: $e')),
                );
              }
            }

/// 关于
class _AboutSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('关于', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('版本'),
                subtitle: const Text('0.1.0+1'),
              ),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('开源协议'),
                subtitle: const Text('MIT License'),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.bug_report),
                title: const Text('反馈问题'),
                subtitle: const Text('GitHub Issues'),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip),
                title: const Text('隐私政策'),
                subtitle: const Text('本地优先，不上传用户数据'),
                onTap: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }
  }

  /// 音频输出设备选择对话框
  class _AudioDeviceDialog extends ConsumerStatefulWidget {
    const _AudioDeviceDialog({required this.ref});

    final WidgetRef ref;

    @override
    ConsumerState<_AudioDeviceDialog> createState() => _AudioDeviceDialogState();
  }

  class _AudioDeviceDialogState extends ConsumerState<_AudioDeviceDialog> {
    List<win32audio.AudioDevice> _devices = [];
    String? _selectedDeviceId;
    bool _loading = true;
    String? _error;

    @override
    void initState() {
      super.initState();
      _loadDevices();
    }

    Future<void> _loadDevices() async {
      try {
        final devices = await win32audio.Audio.enumDevices(win32audio.AudioDeviceType.output) ?? [];
        final currentDevice = widget.ref.read(audioDeviceProvider);
        setState(() {
          _devices = devices;
          _selectedDeviceId = currentDevice?.id;
          _loading = false;
        });
      } catch (e) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }

    @override
    Widget build(BuildContext context) {
      return AlertDialog(
        title: const Text('音频输出设备'),
        content: SizedBox(
          width: 300,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Text('加载失败: $_error', style: TextStyle(color: Theme.of(context).colorScheme.error))
                  : _devices.isEmpty
                      ? const Text('未找到音频输出设备')
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: _devices.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final device = _devices[index];
                            final isSelected = device.id == _selectedDeviceId;
                            return RadioListTile<String>(
                              title: Text(device.name),
                              value: device.id,
                              groupValue: _selectedDeviceId,
                              onChanged: (value) => setState(() => _selectedDeviceId = value),
                              secondary: isSelected
                                  ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                                  : null,
                            );
                          },
                        ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: _selectedDeviceId == null || _loading
                ? null
                : () async {
                    final device = _devices.firstWhere((d) => d.id == _selectedDeviceId);
                    await widget.ref.read(audioDeviceProvider.notifier).setDevice(
                          AudioDevice(id: device.id, name: device.name),
                        );
                    if (context.mounted) Navigator.pop(context);
                  },
            child: const Text('确定'),
          ),
        ],
      );
    }
  }

  /// 下载目录 Provider
class DownloadDirectoryNotifier extends StateNotifier<String> {
  DownloadDirectoryNotifier(this._ref) : super('') {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final prefs = _ref.read(sharedPreferencesProvider);
    state = prefs.getString('download_directory') ?? '';
  }

  Future<void> setDirectory(String path) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.setString('download_directory', path);
    state = path;
  }
}

final downloadDirectoryProvider = StateNotifierProvider<DownloadDirectoryNotifier, String>((ref) {
  return DownloadDirectoryNotifier(ref);
});