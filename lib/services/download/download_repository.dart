import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/download_task.dart';
import '../../presentation/providers/catalog_providers.dart'
    show sharedPreferencesProvider;

/// 基于 SharedPreferences 的下载仓库实现
class SharedPreferencesDownloadRepository implements DownloadRepository {
  SharedPreferencesDownloadRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _kPrefix = 'q_audio.downloads.';

  final _controller = StreamController<List<DownloadTask>>.broadcast();

  @override
  Future<List<DownloadTask>> getAll() async {
    final keys = _prefs.getKeys().where((k) => k.startsWith(_kPrefix)).toList();
    final tasks = <DownloadTask>[];
    for (final key in keys) {
      final json = _prefs.getString(key);
      if (json != null) {
        try {
          tasks.add(
              DownloadTask.fromJson(jsonDecode(json) as Map<String, dynamic>));
        } catch (_) {
          // 忽略损坏的条目
        }
      }
    }
    // 按创建时间倒序
    tasks.sort((a, b) {
      final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime);
    });
    return tasks;
  }

  @override
  Future<DownloadTask?> getById(String id) async {
    final json = _prefs.getString('$_kPrefix$id');
    if (json == null) return null;
    try {
      return DownloadTask.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(DownloadTask task) async {
    final key = '$_kPrefix${task.id}';
    final updated = task.copyWith(updatedAt: DateTime.now());
    await _prefs.setString(key, jsonEncode(updated.toJson()));
    _notify();
  }

  @override
  Future<void> delete(String id) async {
    await _prefs.remove('$_kPrefix$id');
    _notify();
  }

  @override
  Future<int> clearCompleted({bool includeFailed = true}) async {
    final tasks = await getAll();
    int count = 0;
    for (final task in tasks) {
      if (task.status == DownloadStatus.completed ||
          (includeFailed && task.status == DownloadStatus.failed) ||
          task.status == DownloadStatus.cancelled) {
        await delete(task.id);
        count++;
      }
    }
    return count;
  }

  @override
  Stream<List<DownloadTask>> watch() {
    // 初始发射
    getAll().then(_controller.add);
    return _controller.stream;
  }

  void _notify() {
    getAll().then(_controller.add);
  }

  void dispose() {
    _controller.close();
  }
}

/// Provider
final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SharedPreferencesDownloadRepository(prefs);
});

// 保持引用以便 dispose
final downloadRepositoryInstanceProvider =
    Provider<SharedPreferencesDownloadRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SharedPreferencesDownloadRepository(prefs);
});
