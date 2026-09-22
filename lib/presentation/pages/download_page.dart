import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/download_task.dart';
import '../../services/download/download_providers.dart'
    show
        DownloadService,
        DownloadStatus,
        downloadRepositoryProvider,
        downloadServiceProvider;

/// 下载管理页面
class DownloadPage extends ConsumerWidget {
  const DownloadPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(downloadTasksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('下载管理'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'clear_completed':
                  await _clearCompleted(ref, context);
                  break;
                case 'clear_all':
                  await _clearAll(ref, context);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_completed',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services, size: 20),
                    SizedBox(width: 8),
                    Text('清理已完成'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, size: 20),
                    SizedBox(width: 8),
                    Text('清空所有'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: tasksAsync.when(
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
        data: (tasks) {
          if (tasks.isEmpty) {
            return _buildEmptyState(context);
          }

          // 分组：进行中、已完成、其他
          final activeTasks = tasks
              .where((t) =>
                  t.status == DownloadStatus.downloading ||
                  t.status == DownloadStatus.pending)
              .toList();
          final completedTasks =
              tasks.where((t) => t.status == DownloadStatus.completed).toList();
          final otherTasks = tasks
              .where((t) =>
                  t.status == DownloadStatus.paused ||
                  t.status == DownloadStatus.failed ||
                  t.status == DownloadStatus.cancelled)
              .toList();

          return ListView(
            children: [
              if (activeTasks.isNotEmpty)
                _buildSection(context, '下载中', activeTasks, ref),
              if (completedTasks.isNotEmpty)
                _buildSection(context, '已完成', completedTasks, ref),
              if (otherTasks.isNotEmpty)
                _buildSection(context, '其他', otherTasks, ref),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.download_outlined,
            size: 64,
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant
                .withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无下载任务',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '在搜索或播放列表中长按歌曲可下载',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title,
      List<DownloadTask> tasks, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '$title (${tasks.length})',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        ...tasks.map((task) => _buildTaskTile(context, ref, task)),
        const Divider(height: 8),
      ],
    );
  }

  Widget _buildTaskTile(
      BuildContext context, WidgetRef ref, DownloadTask task) {
    final service = ref.read(downloadServiceProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: Key('download-${task.id}'),
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
                title: const Text('删除下载任务'),
                content: Text(
                    '确定要删除 "${task.title ?? task.filePath.split('/').last}" 吗？'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.error),
                    child: const Text('删除'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => service.deleteDownload(task.id),
      child: ListTile(
        leading: _buildStatusIcon(context, task, colorScheme),
        title: Text(
          task.title ?? task.filePath.split('/').last,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.artist != null)
              Text(
                task.artist!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            _buildProgressBar(context, task, colorScheme),
          ],
        ),
        trailing: _buildActionButtons(context, ref, service, task),
        onTap: task.status == DownloadStatus.completed
            ? () => _openFile(context, task)
            : null,
      ),
    );
  }

  Widget _buildStatusIcon(
      BuildContext context, DownloadTask task, ColorScheme colorScheme) {
    IconData icon;
    Color color;

    switch (task.status) {
      case DownloadStatus.downloading:
        icon = Icons.downloading;
        color = colorScheme.primary;
        break;
      case DownloadStatus.pending:
        icon = Icons.schedule;
        color = colorScheme.primary.withValues(alpha: 0.7);
        break;
      case DownloadStatus.paused:
        icon = Icons.pause_circle;
        color = colorScheme.tertiary;
        break;
      case DownloadStatus.completed:
        icon = Icons.check_circle;
        color = colorScheme.primary;
        break;
      case DownloadStatus.failed:
        icon = Icons.error;
        color = colorScheme.error;
        break;
      case DownloadStatus.cancelled:
        icon = Icons.cancel;
        color = colorScheme.onSurfaceVariant;
        break;
    }

    return Icon(icon, size: 32, color: color);
  }

  Widget _buildProgressBar(
      BuildContext context, DownloadTask task, ColorScheme colorScheme) {
    if (task.status == DownloadStatus.completed) {
      return Text(
        '已完成 · ${_formatBytes(task.totalBytes)}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
      );
    }

    if (task.status == DownloadStatus.failed) {
      return Text(
        '失败：${task.error ?? '未知错误'}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.error,
            ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: task.progress,
          backgroundColor: colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation(colorScheme.primary),
          minHeight: 4,
        ),
        const SizedBox(height: 4),
        Text(
          '${(task.progress * 100).toStringAsFixed(1)}% · ${_formatBytes(task.downloadedBytes)} / ${_formatBytes(task.totalBytes)}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    WidgetRef ref,
    DownloadService service,
    DownloadTask task,
  ) {
    switch (task.status) {
      case DownloadStatus.downloading:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.pause),
              tooltip: '暂停',
              onPressed: () => service.pauseDownload(task.id),
            ),
            IconButton(
              icon: const Icon(Icons.cancel),
              tooltip: '取消',
              onPressed: () => service.cancelDownload(task.id),
            ),
          ],
        );
      case DownloadStatus.pending:
        return IconButton(
          icon: const Icon(Icons.cancel),
          tooltip: '取消',
          onPressed: () => service.cancelDownload(task.id),
        );
      case DownloadStatus.paused:
      case DownloadStatus.failed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow),
              tooltip: '继续',
              onPressed: () => service.resumeDownload(task.id),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: '删除',
              onPressed: () => service.deleteDownload(task.id),
            ),
          ],
        );
      case DownloadStatus.completed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.folder_open),
              tooltip: '打开文件夹',
              onPressed: () => _openFile(context, task),
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: '删除',
              onPressed: () => service.deleteDownload(task.id),
            ),
          ],
        );
      case DownloadStatus.cancelled:
        return IconButton(
          icon: const Icon(Icons.delete),
          tooltip: '删除',
          onPressed: () => service.deleteDownload(task.id),
        );
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _clearCompleted(WidgetRef ref, BuildContext context) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('清理已完成'),
            content: const Text('确定要清理所有已完成的下载任务吗？文件将保留。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('清理'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed && context.mounted) {
      final repository = ref.read(downloadRepositoryProvider);
      final count = await repository.clearCompleted(includeFailed: false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已清理 $count 个任务')),
        );
      }
    }
  }

  Future<void> _clearAll(WidgetRef ref, BuildContext context) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('清空所有'),
            content: const Text('确定要删除所有下载任务吗？文件也将被删除。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error),
                child: const Text('全部删除'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed && context.mounted) {
      final tasks = await ref.read(downloadRepositoryProvider).getAll();
      final service = ref.read(downloadServiceProvider);
      for (final task in tasks) {
        await service.deleteDownload(task.id);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已清空所有任务')),
        );
      }
    }
  }

  void _openFile(BuildContext context, DownloadTask task) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('文件位置：${task.filePath}')),
    );
    // TODO: 使用 open_file 或 path_provider 打开文件夹
  }
}

/// 下载任务列表 Provider
final downloadTasksProvider = StreamProvider<List<DownloadTask>>((ref) {
  final repository = ref.watch(downloadRepositoryProvider);
  return repository.watch();
});
