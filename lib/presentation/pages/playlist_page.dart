import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:q_audio/presentation/widgets/cached_artwork.dart';
import '../../services/playlist/playlist_providers.dart'
    show
        PlaylistService,
        Playlist,
        playlistRepositoryProvider,
        playlistServiceProvider;

/// 播放列表管理页面
class PlaylistPage extends ConsumerWidget {
  const PlaylistPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlistsAsync = ref.watch(playlistsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('播放列表'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '新建播放列表',
            onPressed: () => _showCreateDialog(context, ref),
          ),
        ],
      ),
      body: playlistsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text('加载失败：$error', textAlign: TextAlign.center),
            ],
          ),
        ),
        data: (playlists) {
          if (playlists.isEmpty) {
            return _buildEmptyState(context, ref);
          }

          return ListView.separated(
                                // 虚拟化优化
                                cacheExtent: 500.0,
                                itemCount: playlists.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, index) {
              final playlist = playlists[index];
              return _buildPlaylistTile(context, ref, playlist);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.playlist_play_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无播放列表',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '点击右上角 + 创建第一个播放列表',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('创建播放列表'),
            onPressed: () => _showCreateDialog(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistTile(BuildContext context, WidgetRef ref, Playlist playlist) {
    final service = ref.read(playlistServiceProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: Key('playlist-${playlist.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: colorScheme.errorContainer,
        child: Icon(Icons.delete, color: colorScheme.onErrorContainer),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('删除播放列表'),
                content: Text('确定要删除 "${playlist.name}" 吗？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
                    child: const Text('删除'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => service.delete(playlist.id),
      child: ListTile(
        leading: _buildCover(playlist, colorScheme),
        title: Text(playlist.name),
        subtitle: Text(
          '${playlist.trackCount} 首${playlist.description != null ? ' · ${playlist.description}' : ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(context, ref, service, playlist, value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text('重命名')]),
            ),
            const PopupMenuItem(
              value: 'cover',
              child: Row(children: [Icon(Icons.image, size: 20), SizedBox(width: 8), Text('更换封面')]),
            ),
            const PopupMenuItem(
              value: 'clear',
              child: Row(children: [Icon(Icons.clear_all, size: 20), SizedBox(width: 8), Text('清空列表')]),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(children: [Icon(Icons.delete, size: 20, color: Colors.red), SizedBox(width: 8), Text('删除', style: TextStyle(color: Colors.red))]),
            ),
          ],
        ),
        onTap: () => _openPlaylistDetail(context, ref, playlist),
        onLongPress: () => _openPlaylistDetail(context, ref, playlist),
      ),
    );
  }

  Widget _buildCover(Playlist playlist, ColorScheme colorScheme) {
      if (playlist.coverUrl != null && playlist.coverUrl!.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedArtwork(
                      url: playlist.coverUrl!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorWidget: _defaultCover(colorScheme),
                    ),
        );
      }
      return _defaultCover(colorScheme);
    }

  Widget _defaultCover(ColorScheme colorScheme) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          colors: [colorScheme.primaryContainer, colorScheme.secondaryContainer],
        ),
      ),
      child: Icon(Icons.music_note, color: colorScheme.onPrimaryContainer, size: 24),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final service = ref.read(playlistServiceProvider);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新建播放列表'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '播放列表名称',
            hintText: '输入名称',
          ),
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.pop(context);
              service.create(name: value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                service.create(name: name);
                Navigator.pop(context);
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    PlaylistService service,
    Playlist playlist,
    String action,
  ) async {
    switch (action) {
      case 'edit':
        await _showRenameDialog(context, service, playlist);
        break;
      case 'cover':
        await _showCoverDialog(context, service, playlist);
        break;
      case 'clear':
        await _confirmClear(context, service, playlist);
        break;
      case 'delete':
        await service.delete(playlist.id);
        break;
    }
  }

  Future<void> _showRenameDialog(BuildContext context, PlaylistService service, Playlist playlist) async {
    final controller = TextEditingController(text: playlist.name);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: '新名称'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty && name != playlist.name) {
                service.rename(playlist.id, name);
              }
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCoverDialog(BuildContext context, PlaylistService service, Playlist playlist) async {
    final controller = TextEditingController(text: playlist.coverUrl ?? '');
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('更换封面'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '封面图片 URL',
            hintText: 'https://example.com/cover.jpg',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final url = controller.text.trim();
              service.updateCover(playlist.id, url.isEmpty ? null : url);
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, PlaylistService service, Playlist playlist) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('清空播放列表'),
            content: Text('确定要清空 "${playlist.name}" 中的所有歌曲吗？'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                child: const Text('清空'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      await service.clearTracks(playlist.id);
    }
  }

  void _openPlaylistDetail(BuildContext context, WidgetRef ref, Playlist playlist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaylistDetailPage(playlist: playlist),
      ),
    );
  }
}

/// 播放列表详情页（可编辑曲目顺序）
class PlaylistDetailPage extends ConsumerStatefulWidget {
  const PlaylistDetailPage({super.key, required this.playlist});
  final Playlist playlist;

  @override
  ConsumerState<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends ConsumerState<PlaylistDetailPage> {
  late Playlist _playlist;

  @override
  void initState() {
    super.initState();
    _playlist = widget.playlist;
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.read(playlistServiceProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_playlist.name),
        actions: [
          if (_playlist.trackIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.play_arrow),
              tooltip: '播放全部',
              onPressed: () => _playAll(ref),
            ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'rename':
                  await _showRenameDialog(context, service, _playlist);
                  break;
                case 'cover':
                  await _showCoverDialog(context, service, _playlist);
                  break;
                case 'clear':
                  await _confirmClear(context, service, _playlist);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'rename', child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text('重命名')])),
              const PopupMenuItem(value: 'cover', child: Row(children: [Icon(Icons.image, size: 20), SizedBox(width: 8), Text('更换封面')])),
              const PopupMenuItem(value: 'clear', child: Row(children: [Icon(Icons.clear_all, size: 20), SizedBox(width: 8), Text('清空')])),
            ],
          ),
        ],
      ),
      body: _playlist.trackIds.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.music_off, size: 64, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text('播放列表为空', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('在其他页面长按歌曲可添加到播放列表', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
                ],
              ),
            )
          : ReorderableListView.builder(
                                  // 虚拟化优化：使用 builder 版本
                                  itemCount: _playlist.trackIds.length,
                                  onReorderItem: (oldIndex, newIndex) async {
                                    if (oldIndex < newIndex) newIndex--;
                                    await service.moveTrack(_playlist.id, oldIndex, newIndex);
                                    setState(() {
                                      _playlist = _playlist.moveTrack(oldIndex, newIndex);
                                    });
                                  },
                                  itemBuilder: (context, index) => _buildTrackTile(
                                    context,
                                    ref,
                                    service,
                                    _playlist.trackIds[index],
                                    index,
                                  ),
                                ),
    );
  }

  Widget _buildTrackTile(BuildContext context, WidgetRef ref, PlaylistService service, String trackKey, int index) {
    final parts = trackKey.split(':');
    final sourceId = parts.isNotEmpty ? parts[0] : '';
    final id = parts.length > 1 ? parts[1] : trackKey;

    return ListTile(
      key: Key('playlist-track-$trackKey'),
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text('${index + 1}', style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer)),
      ),
      title: Text('$sourceId:$id'),
      subtitle: Text('来源: $sourceId'),
      trailing: IconButton(
        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
        onPressed: () async {
          await service.removeTrackAt(_playlist.id, index);
          if (mounted) setState(() {});
        },
      ),
    );
  }

  Future<void> _playAll(WidgetRef ref) async {
    // TODO: 解析 trackIds 并加入播放队列
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('播放全部功能待实现')));
  }

  Future<void> _showRenameDialog(BuildContext context, PlaylistService service, Playlist playlist) async {
    final controller = TextEditingController(text: playlist.name);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: '新名称'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(onPressed: () { final name = controller.text.trim(); if (name.isNotEmpty) service.rename(playlist.id, name); Navigator.pop(context); }, child: const Text('确定')),
        ],
      ),
    );
  }

  Future<void> _showCoverDialog(BuildContext context, PlaylistService service, Playlist playlist) async {
    final controller = TextEditingController(text: playlist.coverUrl ?? '');
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('更换封面'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: '封面图片 URL', hintText: 'https://example.com/cover.jpg'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(onPressed: () { final url = controller.text.trim(); service.updateCover(playlist.id, url.isEmpty ? null : url); Navigator.pop(context); }, child: const Text('确定')),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, PlaylistService service, Playlist playlist) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('清空播放列表'),
            content: Text('确定要清空 "${playlist.name}" 中的所有歌曲吗？'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
              FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error), child: const Text('清空')),
            ],
          ),
        ) ??
        false;
    if (confirmed) await service.clearTracks(playlist.id);
  }
}

/// 所有播放列表 Provider
final playlistsProvider = StreamProvider<List<Playlist>>((ref) {
  final repository = ref.watch(playlistRepositoryProvider);
  return repository.watch();
});