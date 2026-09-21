import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/playlist/playlist_providers.dart';
import '../../../presentation/providers/catalog_providers.dart';
import '../../../domain/entities/download_task.dart';
import '../../../domain/entities/track.dart';
import '../../../services/equalizer/equalizer_service.dart';
import '../../../services/equalizer/equalizer_providers.dart';

/// 数据导出/导入服务
class DataExportImportService {
  DataExportImportService(this._ref);

  final Ref _ref;

  Future<File> exportAll() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/q_audio_export_${DateTime.now().millisecondsSinceEpoch}.json');

    final data = <String, dynamic>{};

    // 1. 导出播放列表
    final playlistRepo = _ref.read(playlistRepositoryProvider);
    final playlists = await playlistRepo.getAll();
    data['playlists'] = playlists.map((p) => p.toJson()).toList();

    // 2. 导出本地音乐库
    final musicRepo = _ref.read(musicRepositoryProvider);
    final tracks = await musicRepo.search('');
    data['local_tracks'] = tracks.map((t) => t.toJson()).toList();

    // 3. 导出设置
    final prefs = _ref.read(sharedPreferencesProvider);
    data['settings'] = _exportSettings(prefs);

    // 4. 导出下载历史
    final downloadService = _ref.read(downloadServiceProvider);
    final downloadTasks = await downloadService.getAllTasks();
    data['download_tasks'] = downloadTasks.map((t) => t.toJson()).toList();

    // 5. 导出均衡器设置
    final eqService = _ref.read(equalizerServiceProvider);
    data['equalizer'] = {
      'enabled': eqService.enabled,
      'current_preset': eqService.currentPresetId,
      'custom_presets': eqService.customPresets.map((p) => p.toJson()).toList(),
      'custom_gains': eqService.customGains,
    };

    final json = const JsonEncoder.withIndent('  ').convert(data);
    await file.writeAsString(json);
    return file;
  }

  Map<String, dynamic> _exportSettings(SharedPreferences prefs) {
    final keys = [
      'theme_mode',
      'accent_color',
      'download_directory',
      'audio_output_device_id',
      'audio_output_device_name',
      'crossfade_enabled',
      'crossfade_duration_ms',
      'gapless_playback_enabled',
      'auto_start_enabled',
      'auto_play_on_start',
      'resume_position_enabled',
      'scan_directories',
      'lyrics_font_size',
      'lyrics_line_height',
      'lyrics_show_translation',
      'lyrics_highlight_current',
      'lyrics_tap_to_seek',
    ];

    final map = <String, dynamic>{};
    for (final key in keys) {
      if (prefs.containsKey(key)) {
        map[key] = prefs.get(key);
      }
    }
    return map;
  }

  Future<void> importAll(File file) async {
    final jsonStr = await file.readAsString();
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;

    // 1. 导入播放列表
    if (data['playlists'] is List) {
      final playlistRepo = _ref.read(playlistRepositoryProvider);
      for (final p in data['playlists']) {
        try {
          await playlistRepo.save(Playlist.fromJson(p as Map<String, dynamic>));
        } catch (_) {}
      }
    }

    // 2. 导入本地音乐库
    if (data['local_tracks'] is List) {
      final musicRepo = _ref.read(musicRepositoryProvider);
      for (final t in data['local_tracks']) {
        try {
          await musicRepo.save(Track.fromJson(t as Map<String, dynamic>));
        } catch (_) {}
      }
    }

    // 3. 导入设置
    if (data['settings'] is Map<String, dynamic>) {
      final prefs = _ref.read(sharedPreferencesProvider);
      final settings = data['settings'] as Map<String, dynamic>;
      for (final entry in settings.entries) {
        final value = entry.value;
        if (value is String) {
          await prefs.setString(entry.key, value);
        } else if (value is bool) {
          await prefs.setBool(entry.key, value);
        } else if (value is int) {
          await prefs.setInt(entry.key, value);
        } else if (value is double) {
          await prefs.setDouble(entry.key, value);
        } else if (value is List<String>) {
          await prefs.setStringList(entry.key, value);
        }
      }
    }

    // 4. 导入下载历史
    if (data['download_tasks'] is List) {
      final downloadService = _ref.read(downloadServiceProvider);
      for (final t in data['download_tasks']) {
        try {
          final task = DownloadTask.fromJson(t as Map<String, dynamic>);
          await downloadService.getRepository().save(task);
        } catch (_) {}
      }
    }

    // 5. 导入均衡器设置
    if (data['equalizer'] is Map<String, dynamic>) {
      final eq = data['equalizer'] as Map<String, dynamic>;
      final eqService = _ref.read(equalizerServiceProvider);

      if (eq['enabled'] is bool) {
        await eqService.setEnabled(eq['enabled'] as bool);
      }
      if (eq['current_preset'] is String) {
        await eqService.selectPreset(eq['current_preset'] as String);
      }
      if (eq['custom_presets'] is List) {
        for (final p in eq['custom_presets']) {
          try {
            final preset = EqualizerPreset.fromJson(p as Map<String, dynamic>);
            await eqService.saveCustomPreset(preset.name, preset.gains);
          } catch (_) {}
        }
      }
      if (eq['custom_gains'] is List) {
        final gains = (eq['custom_gains'] as List).cast<double>();
        if (gains.length == 10) {
          await eqService.setCustomGains(gains);
        }
      }
    }
  }
}
