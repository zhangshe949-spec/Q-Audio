import 'dart:async';
import 'dart:io';

import 'package:media_kit/media_kit.dart' hide Track;
import 'package:path/path.dart' as p;

import '../../domain/entities/track.dart';
import '../../domain/repositories/music_repository.dart';
import '../background/background_task_manager.dart';

/// 扫描进度事件
sealed class ScanProgress {
  const ScanProgress();
}

class ScanStarted extends ScanProgress {
  const ScanStarted({required this.totalDirectories});
  final int totalDirectories;
}

class ScanDirectory extends ScanProgress {
  const ScanDirectory({required this.path, required this.index, required this.total});
  final String path;
  final int index;
  final int total;
}

class ScanFileFound extends ScanProgress {
  const ScanFileFound({required this.file, required this.track});
  final File file;
  final Track track;
}

class ScanError extends ScanProgress {
  const ScanError({required this.file, required this.error});
  final File file;
  final Object error;
}

class ScanCompleted extends ScanProgress {
  const ScanCompleted({required this.totalFiles, required this.newTracks, required this.duration});
  final int totalFiles;
  final int newTracks;
  final Duration duration;
}

/// 本地音乐扫描器
class LocalMusicScanner {
  LocalMusicScanner({
    required MusicRepository repository,
    required List<String> scanDirectories,
    this.extensions = const ['.mp3', '.flac', '.m4a', '.ogg', '.wav', '.ape'],
  }) : _repository = repository,
       _scanDirectories = scanDirectories;

  final MusicRepository _repository;
  final List<String> _scanDirectories;
  final List<String> extensions;

  final _progressController = StreamController<ScanProgress>.broadcast();
  bool _isScanning = false;
  bool _cancelled = false;
  BackgroundTask? _currentTask;

  Stream<ScanProgress> get progressStream => _progressController.stream;
  bool get isScanning => _isScanning;

  /// 执行全量扫描（正常优先级）
  Future<ScanResult> scan() async {
    if (_isScanning) return ScanResult(skipped: true);

    final completer = Completer<ScanResult>();
    _currentTask = BackgroundTasks.createTask(
      id: 'local_music_scan',
      priority: TaskPriority.normal,
      description: '本地音乐全量扫描',
      action: () => _performScan(completer),
    );

    await BackgroundTaskManager.instance.submitAndWait(_currentTask!);
    return completer.future;
  }

  /// 增量扫描：只检查新增/修改的文件（低优先级）
  Future<ScanResult> incrementalScan({Duration? since}) async {
    if (_isScanning) return ScanResult(skipped: true);

    final completer = Completer<ScanResult>();
    _currentTask = BackgroundTasks.createTask(
      id: 'local_music_incremental_scan',
      priority: TaskPriority.low,
      description: '本地音乐增量扫描',
      action: () => _performScan(completer, incremental: true, since: since),
    );

    await BackgroundTaskManager.instance.submitAndWait(_currentTask!);
    return completer.future;
  }

  /// 核心扫描逻辑
  Future<void> _performScan(
    Completer<ScanResult> completer, {
    bool incremental = false,
    Duration? since,
  }) async {
    _isScanning = true;
    _cancelled = false;
    final stopwatch = Stopwatch()..start();

    try {
      final allFiles = <File>[];
      final directories = _collectDirectories(_scanDirectories);

      _progressController.add(ScanStarted(totalDirectories: directories.length));

      for (var i = 0; i < directories.length; i++) {
        if (_cancelled || _currentTask?.isCancelled == true) break;
        final dir = directories[i];
        _progressController.add(ScanDirectory(path: dir.path, index: i, total: directories.length));

        final files = await _collectAudioFiles(dir);
        allFiles.addAll(files);
      }

      int newTracks = 0;
      for (final file in allFiles) {
        if (_cancelled || _currentTask?.isCancelled == true) break;
        try {
          final track = await _extractMetadata(file);
          if (track != null) {
            final exists = await _repository.findById(sourceId: 'local', id: track.id);
            if (exists == null) {
              await _repository.save(track);
              newTracks++;
            }
            _progressController.add(ScanFileFound(file: file, track: track));
          }
        } catch (e) {
          _progressController.add(ScanError(file: file, error: e));
        }
      }

      stopwatch.stop();
      final result = ScanResult(
        totalFiles: allFiles.length,
        newTracks: newTracks,
        duration: stopwatch.elapsed,
      );

      _progressController.add(ScanCompleted(
        totalFiles: allFiles.length,
        newTracks: newTracks,
        duration: stopwatch.elapsed,
      ));

      completer.complete(result);
    } catch (e) {
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    } finally {
      _isScanning = false;
    }
  }

  void cancel() {
    _cancelled = true;
    _currentTask?.cancel();
  }

  void dispose() {
    cancel();
    _progressController.close();
  }

  /// 全量重扫：清空数据库并重新扫描所有目录（高优先级，用户主动触发）
  Future<ScanResult> fullRescan() async {
    if (_isScanning) return ScanResult(skipped: true);

    final completer = Completer<ScanResult>();
    _currentTask = BackgroundTasks.createTask(
      id: 'local_music_full_rescan',
      priority: TaskPriority.high,
      description: '本地音乐全量重扫',
      action: () async {
        await _repository.clearAll();
        await _performScan(completer);
      },
    );

    await BackgroundTaskManager.instance.submitAndWait(_currentTask!);
    return completer.future;
  }

  List<Directory> _collectDirectories(List<String> paths) {
    final dirs = <Directory>[];
    for (final path in paths) {
      final dir = Directory(path);
      if (dir.existsSync()) {
        dirs.add(dir);
        _addSubdirectories(dir, dirs);
      }
    }
    return dirs;
  }

  void _addSubdirectories(Directory dir, List<Directory> dirs) {
    try {
      for (final entity in dir.listSync(followLinks: false)) {
        if (entity is Directory) {
          dirs.add(entity);
          _addSubdirectories(entity, dirs);
        }
      }
    } catch (_) {
      // 忽略权限错误等
    }
  }

  Future<List<File>> _collectAudioFiles(Directory dir) async {
    final files = <File>[];
    try {
      for (final entity in dir.listSync(followLinks: false)) {
        if (entity is File) {
          final ext = p.extension(entity.path).toLowerCase();
          if (extensions.contains(ext)) {
            files.add(entity);
          }
        }
      }
    } catch (_) {}
    return files;
  }

  Future<Track?> _extractMetadata(File file) async {
    try {
      // 使用 media_kit 提取时长
      Duration? duration;
      try {
        final player = Player();
        await player.open(Media(file.path));
        await Future.delayed(const Duration(milliseconds: 200));
        duration = player.state.duration;
        await player.dispose();
      } catch (_) {
        // 忽略时长提取错误
      }

      // 生成稳定 ID：基于文件路径哈希
      final id = _generateTrackId(file.path);

      return Track(
        id: id,
        sourceId: 'local',
        title: _guessTitleFromFilename(file.path),
        artist: '未知艺术家',
        album: '未知专辑',
        duration: duration ?? Duration.zero,
        url: file.path,
        filePath: file.path,
        fileSize: await file.length(),
        modifiedAt: await file.lastModified(),
      );
    } catch (e) {
      // 兜底：仅用文件名
      return Track(
        id: _generateTrackId(file.path),
        sourceId: 'local',
        title: _guessTitleFromFilename(file.path),
        artist: '未知艺术家',
        url: file.path,
        filePath: file.path,
        fileSize: await file.length(),
        modifiedAt: await file.lastModified(),
      );
    }
  }

  String _guessTitleFromFilename(String filePath) {
    final name = p.basenameWithoutExtension(filePath);
    return name.replaceFirst(RegExp(r'^\d+[\s\-\.]+'), '');
  }

  String _generateTrackId(String filePath) {
    return filePath.hashCode.toRadixString(36);
  }
}

/// 扫描结果
class ScanResult {
  const ScanResult({
    this.totalFiles = 0,
    this.newTracks = 0,
    this.duration = Duration.zero,
    this.skipped = false,
  });

  final int totalFiles;
  final int newTracks;
  final Duration duration;
  final bool skipped;

  @override
  String toString() => 'ScanResult(files: $totalFiles, new: $newTracks, ${duration.inSeconds}s, skipped: $skipped)';
}