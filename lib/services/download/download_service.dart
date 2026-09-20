import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/download_task.dart';
import '../background/background_task_manager.dart';
import 'download_repository.dart';

/// 下载服务（使用后台任务管理器）
class DownloadService {
  DownloadService(this._repository);

  final DownloadRepository _repository;
  final _activeDownloads = <String, _DownloadController>{};
  final _concurrency = 3; // 最大并发下载数

  /// 启动下载（高优先级，用户主动触发）
  Future<DownloadTask> startDownload({
    required String url,
    required String fileName,
    String? title,
    String? artist,
    String? album,
    String? artworkUrl,
    Map<String, dynamic>? metadata,
  }) async {
    // 确保下载目录存在
    final dir = await _getDownloadDir();
    final filePath = '${dir.path}/$fileName';

    // 检查是否已存在同名文件
    final existingFile = File(filePath);
    if (await existingFile.exists()) {
      // 生成唯一文件名
      int counter = 1;
      String newPath;
      do {
        final ext = fileName.contains('.') ? fileName.substring(fileName.lastIndexOf('.')) : '';
        final base = fileName.contains('.') ? fileName.substring(0, fileName.lastIndexOf('.')) : fileName;
        newPath = '${dir.path}/${base}_$counter$ext';
        counter++;
      } while (await File(newPath).exists());
      return startDownload(
        url: url,
        fileName: newPath.split('/').last,
        title: title,
        artist: artist,
        album: album,
        artworkUrl: artworkUrl,
        metadata: metadata,
      );
    }

    final id = _generateId();
    final task = DownloadTask(
      id: id,
      url: url,
      filePath: filePath,
      title: title,
      artist: artist,
      album: album,
      artworkUrl: artworkUrl,
      status: DownloadStatus.pending,
      createdAt: DateTime.now(),
      metadata: metadata ?? {},
    );

    await _repository.save(task);
    _scheduleDownload(task);
    return task;
  }

  /// 暂停下载
  Future<void> pauseDownload(String id) async {
    final controller = _activeDownloads[id];
    if (controller != null) {
      await controller.pause();
    } else {
      // 更新状态为暂停
      final task = await _repository.getById(id);
      if (task != null && task.status == DownloadStatus.downloading) {
        await _repository.save(task.copyWith(status: DownloadStatus.paused));
      }
    }
  }

  /// 继续下载（高优先级）
  Future<void> resumeDownload(String id) async {
    final task = await _repository.getById(id);
    if (task == null) return;

    if (task.status == DownloadStatus.paused || task.status == DownloadStatus.failed) {
      await _repository.save(task.copyWith(status: DownloadStatus.pending));
      _scheduleDownload(task);
    }
  }

  /// 取消下载
  Future<void> cancelDownload(String id) async {
    final controller = _activeDownloads.remove(id);
    if (controller != null) {
      await controller.cancel();
    }
    // 从后台任务管理器取消
    BackgroundTaskManager.instance.cancel('download_$id');
    
    final task = await _repository.getById(id);
    if (task != null) {
      await _repository.save(task.copyWith(status: DownloadStatus.cancelled));
    }
  }

  /// 删除任务（包括文件）
  Future<void> deleteDownload(String id) async {
    final task = await _repository.getById(id);
    if (task != null) {
      // 如果正在下载，先取消
      final controller = _activeDownloads.remove(id);
      if (controller != null) {
        await controller.cancel();
      }
      BackgroundTaskManager.instance.cancel('download_$id');
      // 删除文件
      try {
        await File(task.filePath).delete();
      } catch (_) {}
      // 删除记录
      await _repository.delete(id);
    }
  }

  /// 获取下载目录
  Future<Directory> _getDownloadDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${appDir.path}/downloads');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return downloadDir;
  }

  /// 调度下载（并发控制 + 任务队列）
  void _scheduleDownload(DownloadTask task) {
    final runningCount = _activeDownloads.values.where((c) => c.isRunning).length;
    if (runningCount >= _concurrency) {
      // 队列中等待，状态保持 pending
      return;
    }
    _startDownload(task);
  }

  /// 实际开始下载（提交到后台任务管理器，高优先级）
  void _startDownload(DownloadTask task) {
    final controller = _DownloadController(
      task: task,
      repository: _repository,
      onComplete: _onDownloadComplete,
      onError: _onDownloadError,
    );
    _activeDownloads[task.id] = controller;

    // 提交到后台任务管理器
    final bgTask = BackgroundTasks.createDownloadTask(
      id: 'download_${task.id}',
      downloader: controller.start,
    );
    BackgroundTaskManager.instance.submit(bgTask);
  }

  void _onDownloadComplete(String id) {
    _activeDownloads.remove(id);
    _checkQueue();
  }

  void _onDownloadError(String id, String error) {
    _activeDownloads.remove(id);
    _checkQueue();
  }

  void _checkQueue() {
    final runningCount = _activeDownloads.values.where((c) => c.isRunning).length;
    if (runningCount < _concurrency) {
      // 尝试启动下一个 pending 任务
      _repository.getAll().then((tasks) {
        for (final task in tasks) {
          if (task.status == DownloadStatus.pending && !_activeDownloads.containsKey(task.id)) {
            _startDownload(task);
            break;
          }
        }
      });
    }
  }

  String _generateId() => DateTime.now().millisecondsSinceEpoch.toString();

  /// 清理资源
  void dispose() {
    for (final controller in _activeDownloads.values) {
      controller.cancel();
    }
    _activeDownloads.clear();
    BackgroundTaskManager.instance.cancelAll(TaskPriority.high);
  }

  /// 获取所有下载任务（用于导出/显示）
  Future<List<DownloadTask>> getAllTasks() async {
    return _repository.getAll();
  }

  /// 获取仓库（用于导入）
  DownloadRepository getRepository() => _repository;
}

/// 内部下载控制器
class _DownloadController {
  _DownloadController({
    required this.task,
    required this.repository,
    required this.onComplete,
    required this.onError,
  });

  final DownloadTask task;
  final DownloadRepository repository;
  final void Function(String) onComplete;
  final void Function(String, String) onError;

  http.Client? _client;
  RandomAccessFile? _file;
  bool _cancelled = false;
  bool _paused = false;
  final _completer = Completer<void>();

  bool get isRunning => !_completer.isCompleted;

  Future<void> start() async {
    try {
      await repository.save(task.copyWith(status: DownloadStatus.downloading));

      _client = http.Client();
      final request = http.Request('GET', Uri.parse(task.url));

      // 支持断点续传
      int startByte = 0;
      if (task.downloadedBytes > 0) {
        startByte = task.downloadedBytes;
        request.headers['Range'] = 'bytes=$startByte-';
      }

      final response = await _client!.send(request);

      if (response.statusCode != 200 && response.statusCode != 206) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final totalBytes = startByte + (response.contentLength ?? 0);
      _file = await File(task.filePath).open(mode: FileMode.append);

      await repository.save(task.copyWith(
        totalBytes: totalBytes,
        status: DownloadStatus.downloading,
      ));

      final stream = response.stream;
      await for (final chunk in stream) {
        if (_cancelled) break;
        while (_paused) {
          await Future.delayed(const Duration(milliseconds: 100));
          if (_cancelled) break;
        }
        if (_cancelled) break;

        await _file!.writeFrom(chunk);

        final newDownloaded = task.downloadedBytes + chunk.length;
        await repository.save(task.copyWith(downloadedBytes: newDownloaded));
      }

      await _file!.close();
      _file = null;

      if (!_cancelled) {
        await repository.save(task.copyWith(
          status: DownloadStatus.completed,
          downloadedBytes: totalBytes,
        ));
        onComplete(task.id);
      }
    } catch (e) {
      await _file?.close();
      if (!_cancelled) {
        await repository.save(task.copyWith(
          status: DownloadStatus.failed,
          error: e.toString(),
        ));
        onError(task.id, e.toString());
      }
    } finally {
      _client?.close();
      _completer.complete();
    }
  }

  Future<void> pause() async {
    _paused = true;
    await repository.save(task.copyWith(status: DownloadStatus.paused));
  }

  Future<void> cancel() async {
    _cancelled = true;
    _paused = false;
    await _completer.future;
  }
}

/// Provider
final downloadServiceProvider = Provider<DownloadService>((ref) {
  final repository = ref.watch(downloadRepositoryProvider);
  return DownloadService(repository);
});