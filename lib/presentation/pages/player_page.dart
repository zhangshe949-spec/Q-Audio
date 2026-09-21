import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:q_audio/presentation/providers/player_providers.dart';
import 'package:q_audio/presentation/widgets/cached_artwork.dart';
import 'package:q_audio/presentation/widgets/equalizer_panel.dart';
import 'package:q_audio/presentation/widgets/lyrics_panel.dart';

/// 全屏播放器页面：进度条、音量、队列、控制栏
class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({super.key});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _artworkController;
  Timer? _positionTimer;

  @override
  void initState() {
    super.initState();
    _artworkController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);
    // Keep progress bar smooth between positionStream updates
    _positionTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    _artworkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(playerProvider);
    final controller = ref.read(playerProvider.notifier);
    final queue = controller.queue;
    final currentIndex = controller.currentIndex;
    final hasQueue = queue != null && queue.isNotEmpty;
    final currentTrack = playback.track;
    final playing = playback.status == PlaybackStatus.playing;
    final loading = playback.status == PlaybackStatus.loading;
    final position = playback.position;
    final duration = playback.duration;

    if (!playback.hasTrack && !hasQueue) {
      return Scaffold(
        appBar: AppBar(title: const Text('播放器')),
        body: const Center(child: Text('暂无播放内容')),
      );
    }

    final track = currentTrack;
    final album = track?.album;

    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('正在播放'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.queue_music_rounded),
            tooltip: '播放队列',
            onPressed: hasQueue ? _showQueueBottomSheet : null,
          ),
          const EqualizerButton(),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // 专辑封面/歌词切换
              Expanded(
                flex: 5,
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      // Tab bar
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: TabBar(
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                          indicator: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          labelColor:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          unselectedLabelColor:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                          tabs: const [
                            Tab(icon: Icon(Icons.album_rounded), text: '封面'),
                            Tab(icon: Icon(Icons.lyrics_rounded), text: '歌词'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Tab content
                      Expanded(
                        child: TabBarView(
                          children: [
                            // 封面页
                            Center(
                              child: AnimatedBuilder(
                                animation: _artworkController,
                                builder: (context, child) => Transform.rotate(
                                  angle: _artworkController.value * 0.05,
                                  child: Container(
                                    width: 280,
                                    height: 280,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Theme.of(context)
                                              .colorScheme
                                              .primaryContainer,
                                          Theme.of(context)
                                              .colorScheme
                                              .secondaryContainer,
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withOpacity(0.3),
                                          blurRadius: 30,
                                          spreadRadius: 5,
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: CachedArtwork(
                                        url: track?.artworkUrl ?? '',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // 歌词页
                            const LyricsPanel(
                              showTranslation: true,
                              compact: false,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // 曲目信息
              Text(
                track?.title ?? '未知曲目',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                track?.artist ?? '未知艺术家',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if ((album?.isNotEmpty ?? false))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    track?.album ?? '',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              const SizedBox(height: 32),

              // 进度条
              Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 16,
                      ),
                      activeTrackColor: Theme.of(context).colorScheme.primary,
                      inactiveTrackColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      thumbColor: Theme.of(context).colorScheme.primary,
                    ),
                    child: Slider(
                      value: progress.clamp(0.0, 1.0),
                      onChanged: (value) {
                        final newPos = Duration(
                          milliseconds:
                              (value * duration.inMilliseconds).round(),
                        );
                        controller.seek(newPos);
                      },
                      onChangeStart: (_) => _positionTimer?.cancel(),
                      onChangeEnd: (_) {
                        _positionTimer = Timer.periodic(
                            const Duration(milliseconds: 200), (_) {
                          if (mounted) setState(() {});
                        });
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(position),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          _formatDuration(duration),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 主控制栏
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Shuffle
                  IconButton(
                    icon: Icon(
                      Icons.shuffle_rounded,
                      color: controller.shuffleMode
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () => controller.toggleShuffle(),
                    tooltip: '随机播放',
                  ),
                  const SizedBox(width: 16),

                  // Previous
                  IconButton(
                    icon: const Icon(Icons.skip_previous_rounded, size: 40),
                    onPressed: hasQueue && (currentIndex ?? 0) > 0
                        ? () => controller.previous()
                        : null,
                    tooltip: '上一首',
                  ),
                  const SizedBox(width: 8),

                  // Play/Pause
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    child: IconButton(
                      iconSize: 48,
                      icon: loading
                          ? SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation(
                                  Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                            )
                          : Icon(
                              playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                      onPressed: loading
                          ? null
                          : () {
                              if (playing) {
                                controller.pause();
                              } else {
                                controller.resume();
                              }
                            },
                      tooltip: playing ? '暂停' : '播放',
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Next
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded, size: 40),
                    onPressed: hasQueue &&
                            (currentIndex != null) &&
                            currentIndex < queue.length - 1
                        ? () => controller.next()
                        : null,
                    tooltip: '下一首',
                  ),
                  const SizedBox(width: 16),

                  // Repeat
                  IconButton(
                    icon: Icon(
                      Icons.repeat_rounded,
                      color: controller.repeatMode
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () => controller.toggleRepeat(),
                    tooltip: '循环模式',
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 音量控制
              Row(
                children: [
                  Icon(
                    Icons.volume_down_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Slider(
                      value: controller.volume,
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      label: '${(controller.volume * 100).round()}%',
                      onChanged: (value) => controller.setVolume(value),
                      activeColor: Theme.of(context).colorScheme.primary,
                      inactiveColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.volume_up_rounded,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 队列预览
              if (hasQueue)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.list_rounded, size: 18),
                    label: Text(
                      '播放队列 (${queue.length} 首)${currentIndex != null ? " · 当前第 ${currentIndex + 1} 首" : ""}',
                    ),
                    onPressed: _showQueueBottomSheet,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? "${d.inHours}:" : ""}$minutes:$seconds';
  }

  void _showQueueBottomSheet() {
    final controller = ref.read(playerProvider.notifier);
    final queue = controller.queue;
    final currentIndex = controller.currentIndex;
    if (queue == null || queue.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Column(
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
                    '播放队列 (${queue.length} 首)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.clear_all_rounded),
                    tooltip: '清空队列',
                    onPressed: () => controller.clearQueue(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                itemCount: queue.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final track = queue[index];
                  final isCurrent = index == currentIndex;
                  final isPlaying = isCurrent &&
                      (ref.read(playerProvider).status ==
                          PlaybackStatus.playing);
                  return ListTile(
                    key: Key('queue-${track.sourceId}-${track.id}'),
                    leading: isPlaying
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          )
                        : Icon(
                            Icons.music_note_rounded,
                            color: isCurrent
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                          ),
                    title: Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight:
                            isCurrent ? FontWeight.w600 : FontWeight.normal,
                        color: isCurrent
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    subtitle: track.artist.isNotEmpty
                        ? Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      onPressed: () async {
                        await controller.removeFromQueue(index);
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                    onTap: () async {
                      await controller.playAt(index);
                      if (context.mounted) Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
