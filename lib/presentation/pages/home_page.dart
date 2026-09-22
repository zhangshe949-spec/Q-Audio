import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/catalog_providers.dart' show musicSearchProvider;
import '../providers/player_providers.dart' show playerProvider;
import '../../domain/entities/track.dart';
import '../../services/music_source/chart_service.dart'
    show hotChartProvider, newChartProvider, playHistoryProvider;
import '../../services/download/download_providers.dart'
    show downloadServiceProvider;
import '../../services/playback/player_controller.dart';

/// 首页：搜索直达 + 榜单（热歌榜/新歌榜）+ 播放历史 + 快捷入口。
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  static const _hotKeywords = [
    '周杰伦',
    '薛之谦',
    '林俊杰',
    '邓紫棋',
    '陈奕迅',
    '毛不易',
    '告五人',
    'Taylor Swift',
    '五月天',
    '许嵩',
    '王菲',
    '朴树',
  ];

  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<Track> _results = const [];
  bool _isSearching = false;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final q = _controller.text.trim();
      setState(() => _query = q);
      if (q.isEmpty) {
        setState(() {
          _results = const [];
          _isSearching = false;
        });
        return;
      }
      _doSearch(q);
    });
  }

  Future<void> _doSearch(String query) async {
    setState(() => _isSearching = true);
    try {
      final service = ref.read(musicSearchProvider);
      final results = await service.search(query);
      if (mounted && _query == query) {
        setState(() {
          _results = results;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _searchKeyword(String keyword) async {
    _controller.text = keyword;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: keyword.length),
    );
    setState(() => _query = keyword);
    _doSearch(keyword);
  }

  Future<void> _playTrack(Track track) async {
    final service = ref.read(musicSearchProvider);
    final player = ref.read(playerProvider.notifier);
    ref.read(playHistoryProvider.notifier).record(track);
    final url = await service.resolveUrl(track);
    if (!mounted) return;
    if (url != null) {
      await player.play(track, url);
      if (!mounted) return;
      context.go('/player');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '「${track.title}」该来源（${track.sourceId}）暂无法播放，'
            '试试其他来源的同名歌曲',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _downloadTrack(Track track) async {
    final service = ref.read(musicSearchProvider);
    final url = await service.resolveUrl(track);
    if (!mounted) return;
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「${track.title}」无法获取下载地址')),
      );
      return;
    }
    final safeName = '${track.artist.isNotEmpty ? '${track.artist} - ' : ''}'
        '${track.title}'
        '.mp3';
    await ref.read(downloadServiceProvider).startDownload(
          url: url,
          fileName: safeName,
          title: track.title,
          artist: track.artist,
          album: track.album,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已开始下载：${track.title}'),
        action: SnackBarAction(
          label: '查看',
          onPressed: () => context.go('/downloads'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = ref.watch(playerProvider);
    final history = ref.watch(playHistoryProvider);
    final hotChart = ref.watch(hotChartProvider);
    final newChart = ref.watch(newChartProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Q-Audio'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: ListView(
        scrollCacheExtent: const ScrollCacheExtent.pixels(500),
        children: [
          // 搜索框
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              key: const Key('home-search'),
              controller: _controller,
              onChanged: (_) => _onQueryChanged(),
              decoration: InputDecoration(
                hintText: '搜索歌曲 / 歌手 / 专辑',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : (_query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _controller.clear();
                              setState(() {
                                _query = '';
                                _results = const [];
                              });
                            },
                          )),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),

          // 正在播放卡片
          if (player.hasTrack) ...[
            Card(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: ListTile(
                leading: const Icon(Icons.graphic_eq, size: 32),
                title: Text(
                  player.track!.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  player.status == PlaybackStatus.playing ? '正在播放' : '已暂停',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go('/player'),
              ),
            ),
            const SizedBox(height: 4),
          ],

          // 搜索结果 / 推荐内容
          if (_query.isNotEmpty) ...[
            if (_isSearching)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_results.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Text('没有找到「$_query」的相关结果')),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  '「$_query」的搜索结果（${_results.length}）',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              ..._results.map(
                (track) => _TrackTile(
                  track: track,
                  onTap: () => _playTrack(track),
                  onDownload: () => _downloadTrack(track),
                ),
              ),
            ],
          ] else ...[
            // 播放历史
            if (history.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('最近播放', style: theme.textTheme.titleSmall),
                    ),
                    TextButton(
                      onPressed: () =>
                          ref.read(playHistoryProvider.notifier).clear(),
                      child: const Text('清空'),
                    ),
                  ],
                ),
              ),
              ...history.take(5).map(
                    (track) => _TrackTile(
                      track: track,
                      onTap: () => _playTrack(track),
                      onDownload: () => _downloadTrack(track),
                    ),
                  ),
            ],

            // 快捷入口
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('快捷入口', style: theme.textTheme.titleSmall),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _QuickEntry(
                    icon: Icons.library_music,
                    label: '本地音乐',
                    onTap: () => context.go('/local'),
                  ),
                  _QuickEntry(
                    icon: Icons.queue_music,
                    label: '播放列表',
                    onTap: () => context.go('/playlist'),
                  ),
                  _QuickEntry(
                    icon: Icons.download,
                    label: '下载',
                    onTap: () => context.go('/downloads'),
                  ),
                  _QuickEntry(
                    icon: Icons.search,
                    label: '高级搜索',
                    onTap: () => context.go('/search'),
                  ),
                ],
              ),
            ),

            // 热歌榜
            _ChartSection(
              title: '热歌榜',
              icon: Icons.local_fire_department,
              asyncTracks: hotChart,
              onPlay: _playTrack,
            ),

            // 新歌榜
            _ChartSection(
              title: '新歌榜',
              icon: Icons.fiber_new,
              asyncTracks: newChart,
              onPlay: _playTrack,
            ),

            // 热门搜索
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('热门搜索', style: theme.textTheme.titleSmall),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                children: _hotKeywords
                    .map(
                      (k) => Padding(
                        padding: const EdgeInsets.all(4),
                        child: ActionChip(
                          label: Text(k),
                          onPressed: () => _searchKeyword(k),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '搜索聚合网易云 / QQ音乐 / 酷我；榜单来自网易云',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// 榜单区块：加载中转圈、失败显示提示、成功显示前 10 首。
class _ChartSection extends StatelessWidget {
  const _ChartSection({
    required this.title,
    required this.icon,
    required this.asyncTracks,
    required this.onPlay,
  });

  final String title;
  final IconData icon;
  final AsyncValue<List<Track>> asyncTracks;
  final void Function(Track) onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(title, style: theme.textTheme.titleSmall),
            ],
          ),
        ),
        asyncTracks.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '榜单加载失败，稍后再试',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          data: (tracks) {
            if (tracks.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '暂无数据',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            return Column(
              children: tracks.take(10).toList().asMap().entries.map((entry) {
                final index = entry.key;
                final track = entry.value;
                final rankColor = switch (index) {
                  0 => Colors.red.shade600,
                  1 => Colors.orange.shade600,
                  2 => Colors.amber.shade700,
                  _ => theme.colorScheme.onSurfaceVariant,
                };
                return ListTile(
                  dense: true,
                  key: Key('chart-$title-$index'),
                  leading: SizedBox(
                    width: 28,
                    child: Text(
                      '${index + 1}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: rankColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.play_circle_outline),
                  onTap: () => onPlay(track),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _TrackTile extends StatelessWidget {
  const _TrackTile({
    required this.track,
    required this.onTap,
    this.onDownload,
  });

  final Track track;
  final VoidCallback onTap;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Color sourceColor;
    switch (track.sourceId) {
      case 'netease':
        sourceColor = const Color(0xFFE60026);
      case 'qq':
        sourceColor = const Color(0xFF0099E8);
      case 'kuwo':
        sourceColor = const Color(0xFFC40000);
      default:
        sourceColor = Colors.grey;
    }
    return ListTile(
      key: Key('home-${track.sourceId}-${track.id}'),
      leading: Icon(Icons.music_note, color: sourceColor),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          if (track.artist.isNotEmpty) track.artist,
          if (track.album.isNotEmpty) track.album,
          track.sourceId,
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onDownload != null)
            IconButton(
              key: Key('download-${track.sourceId}-${track.id}'),
              icon: const Icon(Icons.download_outlined, size: 20),
              tooltip: '下载',
              onPressed: onDownload,
            ),
          Icon(Icons.play_circle_outline, color: colorScheme.primary),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _QuickEntry extends StatelessWidget {
  const _QuickEntry({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icon, size: 28, color: theme.colorScheme.primary),
              const SizedBox(height: 6),
              Text(label, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
