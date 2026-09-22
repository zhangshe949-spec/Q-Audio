import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/lyrics.dart';
import '../../presentation/providers/catalog_providers.dart'
    show lyricsServiceProvider;
import '../../presentation/providers/player_providers.dart' show playerProvider;

/// 歌词面板组件：同步高亮、自动滚动、点击跳转
class LyricsPanel extends ConsumerStatefulWidget {
  const LyricsPanel({
    super.key,
    this.showTranslation = true,
    this.compact = false,
    this.onTapFullscreen,
  });

  final bool showTranslation;
  final bool compact;
  final VoidCallback? onTapFullscreen;

  @override
  ConsumerState<LyricsPanel> createState() => _LyricsPanelState();
}

class _LyricsPanelState extends ConsumerState<LyricsPanel> {
  final ScrollController _scrollController = ScrollController();
  Timer? _positionTimer;
  int _lastHighlightedIndex = -1;

  @override
  void initState() {
    super.initState();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(playerProvider);
    final lyricsAsync = playback.track != null
        ? ref.watch(lyricsServiceProvider).watchLyrics(playback.track!)
        : null;

    final positionMs = playback.position.inMilliseconds;

    return lyricsAsync == null
        ? _buildPlaceholder(context)
        : StreamBuilder<Lyrics?>(
            stream: lyricsAsync,
            builder: (context, snapshot) {
              final lyrics = snapshot.data;
              if (lyrics == null || lyrics.lines.isEmpty) {
                return _buildPlaceholder(context, message: '暂无歌词');
              }

              final currentIndex = lyrics.indexAt(positionMs);
              _scrollToCurrent(currentIndex);

              return _buildLyricsList(context, lyrics, currentIndex);
            },
          );
  }

  Widget _buildPlaceholder(BuildContext context,
      {String message = '播放音乐以显示歌词'}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lyrics_outlined,
            size: 48,
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant
                .withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.7),
                ),
            textAlign: TextAlign.center,
          ),
          if (widget.onTapFullscreen != null) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: widget.onTapFullscreen,
              icon: const Icon(Icons.fullscreen, size: 18),
              label: const Text('全屏歌词'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLyricsList(
      BuildContext context, Lyrics lyrics, int currentIndex) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyLarge?.copyWith(
          height: 1.6,
        ) ??
        const TextStyle(fontSize: 16, height: 1.6);
    final highlightStyle = textStyle.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w600,
      fontSize: textStyle.fontSize! + 2,
    );
    final translationStyle = theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.5,
        ) ??
        const TextStyle(fontSize: 13, height: 1.5, color: Colors.grey);

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(
        vertical: widget.compact ? 8 : 24,
        horizontal: 16,
      ),
      itemCount: lyrics.lines.length,
      itemBuilder: (context, index) {
        final line = lyrics.lines[index];
        final isCurrent = index == currentIndex;
        final translation = widget.showTranslation &&
                lyrics.hasTranslation &&
                index < lyrics.translatedLines.length
            ? lyrics.translatedLines[index].text
            : null;

        return GestureDetector(
          onTap: () => _seekToLine(line.time),
          behavior: HitTestBehavior.translucent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: isCurrent
                ? BoxDecoration(
                    color: theme.colorScheme.primaryContainer
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  line.text.isEmpty ? '♪' : line.text,
                  style: isCurrent ? highlightStyle : textStyle,
                  textAlign: TextAlign.center,
                  maxLines: widget.compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (translation != null && translation.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    translation,
                    style: isCurrent
                        ? translationStyle.copyWith(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.8))
                        : translationStyle,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _scrollToCurrent(int index) {
    if (index < 0 || index == _lastHighlightedIndex) return;
    _lastHighlightedIndex = index;

    // 计算目标位置：让当前行居中
    final itemHeight = 56.0; // 估算行高
    final targetOffset = (index * itemHeight) -
        (_scrollController.position.viewportDimension / 2) +
        (itemHeight / 2);

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _seekToLine(int timeMs) {
    final player = ref.read(playerProvider.notifier);
    player.seek(Duration(milliseconds: timeMs));
  }
}

/// 全屏歌词页面
class LyricsPage extends ConsumerWidget {
  const LyricsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playerProvider);
    final track = playback.track;

    if (track == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('歌词')),
        body: const Center(child: Text('暂无播放内容')),
      );
    }

    final lyricsAsync = ref.watch(lyricsServiceProvider).watchLyrics(track);

    return Scaffold(
      appBar: AppBar(
        title: const Text('歌词'),
        actions: [
          PopupMenuButton<bool>(
            initialValue: true,
            onSelected: (value) {
              // TODO: 保存用户偏好
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: true, child: Text('显示译文')),
              const PopupMenuItem(value: false, child: Text('仅原文')),
            ],
          ),
        ],
      ),
      body: StreamBuilder<Lyrics?>(
        stream: lyricsAsync,
        builder: (context, snapshot) {
          final lyrics = snapshot.data;
          if (lyrics == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在获取歌词...'),
                ],
              ),
            );
          }

          if (lyrics.lines.isEmpty) {
            return _buildEmptyLyrics(context, lyrics);
          }

          return LyricsPanel(
            showTranslation: true,
            compact: false,
            onTapFullscreen: null,
          );
        },
      ),
    );
  }

  Widget _buildEmptyLyrics(BuildContext context, Lyrics lyrics) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lyrics_outlined,
              size: 80,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            Text(
              lyrics.title ?? '未知曲目',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            if (lyrics.artist != null) ...[
              const SizedBox(height: 8),
              Text(
                lyrics.artist!,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
            const SizedBox(height: 32),
            Text(
              '暂无可用歌词',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              '尝试切换音乐源或手动搜索',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.5),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
