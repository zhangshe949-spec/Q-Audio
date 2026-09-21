import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/local_music/local_music_scanner.dart'
    show LocalMusicScanner, ScanProgress, ScanResult;
import 'catalog_providers.dart';

// Re-export ScanResult for consumers
export '../../services/local_music/local_music_scanner.dart' show ScanResult;

/// 配置的扫描目录列表（持久化到 SharedPreferences）
final scanDirectoriesProvider =
    StateNotifierProvider<ScanDirectoriesNotifier, List<String>>((ref) {
  return ScanDirectoriesNotifier(ref.watch(sharedPreferencesProvider));
});

class ScanDirectoriesNotifier extends StateNotifier<List<String>> {
  ScanDirectoriesNotifier(this._prefs) : super(_load(_prefs));

  final SharedPreferences _prefs;

  static List<String> _load(SharedPreferences prefs) {
    return prefs.getStringList('scan_directories') ?? [];
  }

  void addDirectory(String path) {
    if (!state.contains(path)) {
      state = [...state, path];
      _save();
    }
  }

  void removeDirectory(String path) {
    state = state.where((p) => p != path).toList();
    _save();
  }

  void clear() {
    state = [];
    _save();
  }

  void _save() {
    _prefs.setStringList('scan_directories', state);
  }
}

/// 本地音乐扫描器 Provider
final localMusicScannerProvider = Provider<LocalMusicScanner>((ref) {
  final repository = ref.watch(musicRepositoryProvider);
  final directories = ref.watch(scanDirectoriesProvider);
  return LocalMusicScanner(
      repository: repository, scanDirectories: directories);
});

/// 扫描进度流 Provider
final scanProgressProvider = StreamProvider<ScanProgress>((ref) {
  final scanner = ref.watch(localMusicScannerProvider);
  return scanner.progressStream;
});

/// 扫描状态
sealed class ScanState {
  const ScanState();
}

class ScanIdle extends ScanState {
  const ScanIdle();
}

class ScanInProgress extends ScanState {
  const ScanInProgress(
      {required this.currentDir,
      required this.processedFiles,
      required this.foundTracks});
  final String currentDir;
  final int processedFiles;
  final int foundTracks;
}

class ScanDone extends ScanState {
  const ScanDone({required this.result});
  final ScanResult result;
}

class ScanFailed extends ScanState {
  const ScanFailed({required this.error});
  final String error;
}

/// 扫描状态修改器
class ScanStateNotifier extends StateNotifier<ScanState> {
  ScanStateNotifier() : super(const ScanIdle());
}

/// 扫描状态 Provider
final scanStateProvider =
    StateNotifierProvider<ScanStateNotifier, ScanState>((ref) {
  return ScanStateNotifier();
});
