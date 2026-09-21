import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'catalog_providers.dart';

/// 音频输出设备模型
class AudioDevice {
  const AudioDevice({required this.id, required this.name});
  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioDevice &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AudioDevice(id: $id, name: $name)';
}

/// 音频输出设备 Provider
class AudioDeviceNotifier extends StateNotifier<AudioDevice?> {
  AudioDeviceNotifier(this._ref) : super(null) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final prefs = _ref.read(sharedPreferencesProvider);
    final deviceId = prefs.getString('audio_output_device_id');
    final deviceName = prefs.getString('audio_output_device_name');
    if (deviceId != null && deviceName != null) {
      state = AudioDevice(id: deviceId, name: deviceName);
    }
  }

  Future<void> setDevice(AudioDevice device) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.setString('audio_output_device_id', device.id);
    await prefs.setString('audio_output_device_name', device.name);
    state = device;
  }

  Future<void> clearDevice() async {
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.remove('audio_output_device_id');
    await prefs.remove('audio_output_device_name');
    state = null;
  }
}

final audioDeviceProvider =
    StateNotifierProvider<AudioDeviceNotifier, AudioDevice?>((ref) {
  return AudioDeviceNotifier(ref);
});

/// 交叉淡入淡出配置
class CrossfadeConfig {
  const CrossfadeConfig({this.enabled = false, this.durationMs = 5000});
  final bool enabled;
  final int durationMs; // 毫秒

  CrossfadeConfig copyWith({bool? enabled, int? durationMs}) {
    return CrossfadeConfig(
      enabled: enabled ?? this.enabled,
      durationMs: durationMs ?? this.durationMs,
    );
  }
}

/// 交叉淡入淡出 Provider
class CrossfadeNotifier extends StateNotifier<CrossfadeConfig> {
  CrossfadeNotifier(this._ref) : super(const CrossfadeConfig()) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final prefs = _ref.read(sharedPreferencesProvider);
    state = CrossfadeConfig(
      enabled: prefs.getBool('crossfade_enabled') ?? false,
      durationMs: prefs.getInt('crossfade_duration_ms') ?? 5000,
    );
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.setBool('crossfade_enabled', enabled);
    state = state.copyWith(enabled: enabled);
  }

  Future<void> setDuration(int durationMs) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.setInt('crossfade_duration_ms', durationMs);
    state = state.copyWith(durationMs: durationMs);
  }
}

final crossfadeProvider =
    StateNotifierProvider<CrossfadeNotifier, CrossfadeConfig>((ref) {
  return CrossfadeNotifier(ref);
});

/// 无缝播放 Provider
class GaplessPlaybackNotifier extends StateNotifier<bool> {
  GaplessPlaybackNotifier(this._ref) : super(false) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final prefs = _ref.read(sharedPreferencesProvider);
    state = prefs.getBool('gapless_playback_enabled') ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.setBool('gapless_playback_enabled', enabled);
    state = enabled;
  }
}

final gaplessPlaybackProvider =
    StateNotifierProvider<GaplessPlaybackNotifier, bool>((ref) {
  return GaplessPlaybackNotifier(ref);
});

/// 开机自启 Provider
class AutoStartNotifier extends StateNotifier<bool> {
  AutoStartNotifier(this._ref) : super(false) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final prefs = _ref.read(sharedPreferencesProvider);
    state = prefs.getBool('auto_start_enabled') ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.setBool('auto_start_enabled', enabled);
    state = enabled;
  }
}

final autoStartProvider = StateNotifierProvider<AutoStartNotifier, bool>((ref) {
  return AutoStartNotifier(ref);
});

/// 启动时自动播放 Provider
class AutoPlayOnStartNotifier extends StateNotifier<bool> {
  AutoPlayOnStartNotifier(this._ref) : super(false) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final prefs = _ref.read(sharedPreferencesProvider);
    state = prefs.getBool('auto_play_on_start') ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.setBool('auto_play_on_start', enabled);
    state = enabled;
  }
}

final autoPlayOnStartProvider =
    StateNotifierProvider<AutoPlayOnStartNotifier, bool>((ref) {
  return AutoPlayOnStartNotifier(ref);
});

/// 恢复播放位置 Provider
class ResumePositionNotifier extends StateNotifier<bool> {
  ResumePositionNotifier(this._ref) : super(true) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final prefs = _ref.read(sharedPreferencesProvider);
    state = prefs.getBool('resume_position_enabled') ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.setBool('resume_position_enabled', enabled);
    state = enabled;
  }
}

final resumePositionProvider =
    StateNotifierProvider<ResumePositionNotifier, bool>((ref) {
  return ResumePositionNotifier(ref);
});
