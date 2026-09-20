import 'dart:async';

import 'package:flutter/foundation.dart';

/// 后台任务优先级枚举
enum TaskPriority {
  /// 关键任务：立即执行，阻塞 UI
  critical,

  /// 高优先级：用户可感知的任务（如播放、搜索）
  high,

  /// 正常优先级：默认任务（如扫描、下载）
  normal,

  /// 低优先级：后台维护任务（如缓存清理、索引重建）
  low,

  /// 空闲优先级：仅在设备空闲时执行
  idle,
}

/// 后台任务接口
abstract class BackgroundTask {
  /// 任务唯一标识
  String get id;

  /// 任务优先级
  TaskPriority get priority;

  /// 任务描述（用于调试）
  String get description;

  /// 执行任务
  Future<void> execute();

  /// 取消任务
  void cancel();

  /// 是否已取消
  bool get isCancelled;
}

/// 可取消的任务基类
abstract class CancellableTask implements BackgroundTask {
  CancellableTask({
    required String id,
    required TaskPriority priority,
    required String description,
  }) : _id = id,
       _priority = priority,
       _description = description;

  final String _id;
  final TaskPriority _priority;
  final String _description;

  @override
  String get id => _id;

  @override
  TaskPriority get priority => _priority;

  @override
  String get description => _description;

  final Completer<void> _completer = Completer<void>();
  bool _cancelled = false;

  @override
  bool get isCancelled => _cancelled;

  @override
  void cancel() {
    _cancelled = true;
    if (!_completer.isCompleted) {
      _completer.completeError(TaskCancelledException(_id));
    }
  }

  @override
  Future<void> execute() async {
    try {
      await run();
      if (!_completer.isCompleted) {
        _completer.complete();
      }
    } catch (e) {
      if (!_completer.isCompleted) {
        _completer.completeError(e);
      }
    }
  }

  /// 子类实现具体逻辑
  Future<void> run();

  /// 检查是否应取消
  void checkCancellation() {
    if (_cancelled) {
      throw TaskCancelledException(_id);
    }
  }

  Future<void> get future => _completer.future;
}

/// 任务取消异常
class TaskCancelledException implements Exception {
  TaskCancelledException(this.taskId);
  final String taskId;

  @override
  String toString() => 'Task cancelled: $taskId';
}

/// 基于列表的优先级队列（避免 PriorityQueue 解析问题）
class _TaskPriorityQueue {
  final List<BackgroundTask> _tasks = [];
  final int Function(BackgroundTask, BackgroundTask) _comparator;

  _TaskPriorityQueue(this._comparator);

  void add(BackgroundTask task) {
    _tasks.add(task);
    _tasks.sort(_comparator);
  }

  BackgroundTask removeFirst() {
    if (_tasks.isEmpty) throw StateError('Queue is empty');
    return _tasks.removeAt(0);
  }

  BackgroundTask get first {
    if (_tasks.isEmpty) throw StateError('Queue is empty');
    return _tasks.first;
  }

  bool get isNotEmpty => _tasks.isNotEmpty;

  bool get isEmpty => _tasks.isEmpty;

  int get length => _tasks.length;

  void removeWhere(bool Function(BackgroundTask) test) {
    _tasks.removeWhere(test);
  }

  Iterable<BackgroundTask> where(bool Function(BackgroundTask) test) {
    return _tasks.where(test);
  }
}

/// 后台任务管理器
/// 使用优先级队列，支持并发控制、任务去重、优先级抢占
class BackgroundTaskManager {
  BackgroundTaskManager._internal({
    int? maxConcurrentTasks,
  })  : _maxConcurrentTasks = maxConcurrentTasks ?? 3 {
    _startProcessor();
  }

  static final BackgroundTaskManager instance = BackgroundTaskManager._internal();

  /// 最大并发任务数
  final int _maxConcurrentTasks;

  // 待执行任务队列（按优先级排序）
  final _pendingQueue = _TaskPriorityQueue(_taskComparator);

  // 正在执行的任务
  final Set<BackgroundTask> _runningTasks = {};

  // 任务完成回调
  final Map<String, Completer<void>> _waiters = {};

  // 任务去重：相同 ID 的任务只保留最高优先级
  final Map<String, BackgroundTask> _taskMap = {};

  // 处理器运行标志
  bool _processorRunning = false;

  // 任务执行历史（用于调试）
  final List<TaskExecutionRecord> _executionHistory = [];
  static const int _maxHistorySize = 100;

  /// 任务比较器：优先级高的在前，同优先级按插入顺序
  static int _taskComparator(BackgroundTask a, BackgroundTask b) {
    final priorityOrder = {
      TaskPriority.critical: 0,
      TaskPriority.high: 1,
      TaskPriority.normal: 2,
      TaskPriority.low: 3,
      TaskPriority.idle: 4,
    };
    final aOrder = priorityOrder[a.priority] ?? 99;
    final bOrder = priorityOrder[b.priority] ?? 99;
    return aOrder.compareTo(bOrder);
  }

  /// 启动任务处理器
  void _startProcessor() {
    if (_processorRunning) return;
    _processorRunning = true;
    _processQueue();
  }

  /// 处理队列主循环
  Future<void> _processQueue() async {
    while (_processorRunning) {
      // 检查是否有可用并发槽位
      if (_runningTasks.length >= _maxConcurrentTasks) {
        await Future.delayed(const Duration(milliseconds: 100));
        continue;
      }

      // 获取下一个任务
      BackgroundTask? task;
      while (_pendingQueue.isNotEmpty) {
        final next = _pendingQueue.first;
        // 去重检查：如果已有同 ID 任务在运行，跳过
        if (_runningTasks.any((t) => t.id == next.id)) {
          _pendingQueue.removeFirst();
          continue;
        }
        task = _pendingQueue.removeFirst();
        _taskMap.remove(task.id);
        break;
      }

      if (task == null) {
        await Future.delayed(const Duration(milliseconds: 200));
        continue;
      }

      // 执行任务
      _runningTasks.add(task);
      unawaited(_executeTask(task));
    }
  }

  /// 执行单个任务
  Future<void> _executeTask(BackgroundTask task) async {
    final startTime = DateTime.now();
    try {
      debugPrint('BackgroundTaskManager: Starting task ${task.id} (${task.priority})');
      await task.execute();
      final duration = DateTime.now().difference(startTime);
      _recordExecution(task, true, duration);
      debugPrint('BackgroundTaskManager: Task ${task.id} completed in ${duration.inMilliseconds}ms');
    } catch (e) {
      final duration = DateTime.now().difference(startTime);
      _recordExecution(task, false, duration, error: e.toString());
      if (e is! TaskCancelledException) {
        debugPrint('BackgroundTaskManager: Task ${task.id} failed: $e');
      }
    } finally {
      _runningTasks.remove(task);
      _notifyWaiters(task.id);
    }
  }

  /// 记录执行历史
  void _recordExecution(BackgroundTask task, bool success, Duration duration, {String? error}) {
    _executionHistory.add(TaskExecutionRecord(
      taskId: task.id,
      priority: task.priority,
      description: task.description,
      startTime: DateTime.now().subtract(duration),
      duration: duration,
      success: success,
      error: error,
    ));
    if (_executionHistory.length > _maxHistorySize) {
      _executionHistory.removeAt(0);
    }
  }

  /// 通知等待者
  void _notifyWaiters(String taskId) {
    final waiter = _waiters.remove(taskId);
    waiter?.complete();
  }

  /// 提交任务
  /// 如果同 ID 任务已存在且优先级不低，则忽略新任务
  Future<void> submit(BackgroundTask task) async {
    // 去重：如果已有同 ID 任务
    if (_taskMap.containsKey(task.id)) {
      final existing = _taskMap[task.id]!;
      if (existing.priority.index <= task.priority.index) {
        // 现有任务优先级更高或相同，忽略新任务
        debugPrint('BackgroundTaskManager: Task ${task.id} skipped (existing has higher/equal priority)');
        return;
      } else {
        // 新任务优先级更高，替换
        _pendingQueue.removeWhere((t) => t.id == existing.id);
        debugPrint('BackgroundTaskManager: Task ${task.id} replaced with higher priority');
      }
    }

    _taskMap[task.id] = task;
    _pendingQueue.add(task);
    debugPrint('BackgroundTaskManager: Task ${task.id} queued (${task.priority})');
  }

  /// 提交并等待完成
  Future<void> submitAndWait(BackgroundTask task) async {
    final completer = Completer<void>();
    _waiters[task.id] = completer;
    await submit(task);
    return completer.future;
  }

  /// 取消任务
  void cancel(String taskId) {
    // 从待执行队列移除
    _pendingQueue.removeWhere((t) => t.id == taskId);
    _taskMap.remove(taskId);

    // 取消正在执行的任务
    for (final task in _runningTasks.where((t) => t.id == taskId)) {
      task.cancel();
    }
  }

  /// 取消指定优先级及以下的所有任务
  void cancelAll(TaskPriority priorityAndBelow) {
    final toCancel = _pendingQueue.where((t) => t.priority.index >= priorityAndBelow.index).toList();
    for (final task in toCancel) {
      cancel(task.id);
    }
    for (final task in _runningTasks.where((t) => t.priority.index >= priorityAndBelow.index)) {
      task.cancel();
    }
  }

  /// 获取队列状态
  TaskQueueStatus getStatus() {
    return TaskQueueStatus(
      pendingCount: _pendingQueue.length,
      runningCount: _runningTasks.length,
      maxConcurrent: _maxConcurrentTasks,
      runningTasks: _runningTasks.map((t) => TaskInfo(
        id: t.id,
        priority: t.priority,
        description: t.description,
      )).toList(),
      pendingTasks: _pendingQueue.where((_) => true).map((t) => TaskInfo(
        id: t.id,
        priority: t.priority,
        description: t.description,
      )).toList(),
    );
  }

  /// 获取执行历史
  List<TaskExecutionRecord> getExecutionHistory() => List.unmodifiable(_executionHistory);

  /// 清空历史
  void clearHistory() => _executionHistory.clear();

  /// 关闭管理器
  void shutdown() {
    _processorRunning = false;
    cancelAll(TaskPriority.critical);
  }
}

/// 任务信息
class TaskInfo {
  TaskInfo({required this.id, required this.priority, required this.description});
  final String id;
  final TaskPriority priority;
  final String description;
}

/// 队列状态
class TaskQueueStatus {
  TaskQueueStatus({
    required this.pendingCount,
    required this.runningCount,
    required this.maxConcurrent,
    required this.runningTasks,
    required this.pendingTasks,
  });
  final int pendingCount;
  final int runningCount;
  final int maxConcurrent;
  final List<TaskInfo> runningTasks;
  final List<TaskInfo> pendingTasks;
}

/// 执行记录
class TaskExecutionRecord {
  TaskExecutionRecord({
    required this.taskId,
    required this.priority,
    required this.description,
    required this.startTime,
    required this.duration,
    required this.success,
    this.error,
  });
  final String taskId;
  final TaskPriority priority;
  final String description;
  final DateTime startTime;
  final Duration duration;
  final bool success;
  final String? error;
}

/// 常用任务工厂
class BackgroundTasks {
  /// 创建扫描任务
  static BackgroundTask createScanTask({
    required String id,
    required Future<void> Function() scanner,
    TaskPriority priority = TaskPriority.normal,
  }) {
    return _ScanTask(id: id, priority: priority, scanner: scanner);
  }

  /// 创建下载任务
  static BackgroundTask createDownloadTask({
    required String id,
    required Future<void> Function() downloader,
    TaskPriority priority = TaskPriority.high,
  }) {
    return _DownloadTask(id: id, priority: priority, downloader: downloader);
  }

  /// 创建缓存清理任务
  static BackgroundTask createCacheCleanupTask({
    required String id,
    required Future<void> Function() cleaner,
    TaskPriority priority = TaskPriority.low,
  }) {
    return _CacheCleanupTask(id: id, priority: priority, cleaner: cleaner);
  }

  /// 创建通用任务
  static BackgroundTask createTask({
    required String id,
    required Future<void> Function() action,
    TaskPriority priority = TaskPriority.normal,
    String description = '',
  }) {
    return _GenericTask(id: id, priority: priority, action: action, description: description);
  }
}

// 内部任务实现
class _ScanTask extends CancellableTask {
  _ScanTask({required String id, required TaskPriority priority, required this.scanner})
      : super(id: id, priority: priority, description: '扫描任务: $id');

  final Future<void> Function() scanner;

  @override
  Future<void> run() async {
    checkCancellation();
    await scanner();
  }
}

class _DownloadTask extends CancellableTask {
  _DownloadTask({required String id, required TaskPriority priority, required this.downloader})
      : super(id: id, priority: priority, description: '下载任务: $id');

  final Future<void> Function() downloader;

  @override
  Future<void> run() async {
    checkCancellation();
    await downloader();
  }
}

class _CacheCleanupTask extends CancellableTask {
  _CacheCleanupTask({required String id, required TaskPriority priority, required this.cleaner})
      : super(id: id, priority: priority, description: '缓存清理: $id');

  final Future<void> Function() cleaner;

  @override
  Future<void> run() async {
    checkCancellation();
    await cleaner();
  }
}

class _GenericTask extends CancellableTask {
  _GenericTask({
    required String id,
    required TaskPriority priority,
    required this.action,
    String? description,
  }) : super(id: id, priority: priority, description: description ?? '通用任务: $id');

  final Future<void> Function() action;

  @override
  Future<void> run() async {
    checkCancellation();
    await action();
  }
}

/// 避免未使用的 future 警告
void unawaited(Future<void> future) {
  // ignore: unawaited_futures
  future;
}