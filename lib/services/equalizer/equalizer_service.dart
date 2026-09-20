import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 均衡器预设
class EqualizerPreset {
  final String id;
  final String name;
  final List<double> gains; // 10 bands: 31, 62, 125, 250, 500, 1k, 2k, 4k, 8k, 16k Hz
  final bool isCustom;

  const EqualizerPreset({
    required this.id,
    required this.name,
    required this.gains,
    this.isCustom = false,
  });

  EqualizerPreset copyWith({
    String? id,
    String? name,
    List<double>? gains,
    bool? isCustom,
  }) {
    return EqualizerPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      gains: gains ?? this.gains,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'gains': gains,
    'isCustom': isCustom,
  };

  factory EqualizerPreset.fromJson(Map<String, dynamic> json) => EqualizerPreset(
    id: json['id'] as String,
    name: json['name'] as String,
    gains: (json['gains'] as List).map((e) => (e as num).toDouble()).toList(),
    isCustom: json['isCustom'] as bool? ?? false,
  );

  /// 生成 FFmpeg 均衡器滤镜字符串
  String toFfmpegFilter() {
    final frequencies = [31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];
    final parts = <String>[];
    for (int i = 0; i < gains.length; i++) {
      if (gains[i] != 0) {
        parts.add('equalizer=f=${frequencies[i]}:width_type=o:width=1:g=${gains[i]}');
      }
    }
    return parts.join(',');
  }
}

/// 内置预设
class EqualizerPresets {
  static final List<EqualizerPreset> builtin = <EqualizerPreset>[
    EqualizerPreset(
      id: 'flat',
      name: '平坦',
      gains: List.filled(10, 0.0),
    ),
    EqualizerPreset(
      id: 'bass_boost',
      name: '低音增强',
      gains: [6.0, 4.0, 2.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    ),
    EqualizerPreset(
      id: 'treble_boost',
      name: '高音增强',
      gains: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 2.0, 4.0, 6.0],
    ),
    EqualizerPreset(
      id: 'rock',
      name: '摇滚',
      gains: [4.0, 2.0, 1.0, -1.0, -2.0, 0.0, 1.0, 2.0, 4.0, 5.0],
    ),
    EqualizerPreset(
      id: 'pop',
      name: '流行',
      gains: [1.0, 2.0, 3.0, 2.0, 1.0, 0.0, -1.0, -2.0, -1.0, 0.0],
    ),
    EqualizerPreset(
      id: 'jazz',
      name: '爵士',
      gains: [3.0, 2.0, 1.0, 0.0, -1.0, 0.0, 1.0, 2.0, 3.0, 2.0],
    ),
    EqualizerPreset(
      id: 'classical',
      name: '古典',
      gains: [2.0, 1.0, 0.0, -1.0, -2.0, -1.0, 0.0, 1.0, 2.0, 3.0],
    ),
    EqualizerPreset(
      id: 'electronic',
      name: '电子',
      gains: [5.0, 3.0, 1.0, 0.0, -1.0, 0.0, 1.0, 3.0, 5.0, 4.0],
    ),
    EqualizerPreset(
      id: 'vocal',
      name: '人声',
      gains: [0.0, 0.0, 1.0, 2.0, 3.0, 4.0, 3.0, 2.0, 1.0, 0.0],
    ),
    EqualizerPreset(
      id: 'acoustic',
      name: '原声',
      gains: [1.0, 2.0, 2.0, 1.0, 0.0, 0.0, 1.0, 2.0, 2.0, 1.0],
    ),
  ];

  static EqualizerPreset getById(String id) {
    return builtin.firstWhere((p) => p.id == id, orElse: () => builtin.first);
  }
}

/// 均衡器服务
class EqualizerService {
  EqualizerService(this._prefs);

  /// Test constructor - creates a no-op service without SharedPreferences
  EqualizerService.test() : _prefs = _TestPrefs();

  final SharedPreferences _prefs;

  static const _kEnabledKey = 'equalizer_enabled';
  static const _kCurrentPresetKey = 'equalizer_current_preset';
  static const _kCustomPresetsKey = 'equalizer_custom_presets';
  static const _kCustomGainsKey = 'equalizer_custom_gains';

  /// 当前是否启用
  bool get enabled => _prefs.getBool(_kEnabledKey) ?? false;

  /// 当前预设 ID
  String get currentPresetId => _prefs.getString(_kCurrentPresetKey) ?? 'flat';

  /// 当前自定义增益（未选择预设时使用）
  List<double> get customGains {
    final json = _prefs.getString(_kCustomGainsKey);
    if (json == null) return List.filled(10, 0.0);
    return (jsonDecode(json) as List).map((e) => (e as num).toDouble()).toList();
  }

  /// 所有自定义预设
  List<EqualizerPreset> get customPresets {
    final json = _prefs.getString(_kCustomPresetsKey);
    if (json == null) return [];
    return (jsonDecode(json) as List)
        .map((e) => EqualizerPreset.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 获取当前生效的增益
  List<double> get activeGains {
    if (!enabled) return List.filled(10, 0.0);
    final preset = _findPreset(currentPresetId);
    if (preset != null) return preset.gains;
    return customGains;
  }

  EqualizerPreset? _findPreset(String id) {
    for (final p in EqualizerPresets.builtin) {
      if (p.id == id) return p;
    }
    for (final p in customPresets) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// 启用/禁用均衡器
  Future<void> setEnabled(bool value) async {
    await _prefs.setBool(_kEnabledKey, value);
    await _apply();
  }

  /// 选择预设
  Future<void> selectPreset(String presetId) async {
    await _prefs.setString(_kCurrentPresetKey, presetId);
    await _apply();
  }

  /// 设置自定义增益
  Future<void> setCustomGains(List<double> gains) async {
    await _prefs.setString(_kCustomGainsKey, jsonEncode(gains));
    await _prefs.setString(_kCurrentPresetKey, 'custom');
    await _apply();
  }

  /// 保存自定义预设
  Future<void> saveCustomPreset(String name, List<double> gains) async {
    final presets = customPresets;
    final newPreset = EqualizerPreset(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      gains: gains,
      isCustom: true,
    );
    presets.add(newPreset);
    await _prefs.setString(
      _kCustomPresetsKey,
      jsonEncode(presets.map((p) => p.toJson()).toList()),
    );
  }

  /// 删除自定义预设
  Future<void> deleteCustomPreset(String id) async {
    final presets = customPresets.where((p) => p.id != id).toList();
    await _prefs.setString(
      _kCustomPresetsKey,
      jsonEncode(presets.map((p) => p.toJson()).toList()),
    );
    // 如果当前选中的是被删除的预设，回退到 flat
    if (currentPresetId == id) {
      await selectPreset('flat');
    }
  }

  /// 重置为平坦
  Future<void> reset() async {
    await _prefs.setString(_kCurrentPresetKey, 'flat');
    await _prefs.setString(_kCustomGainsKey, jsonEncode(List.filled(10, 0.0)));
    await _apply();
  }

  /// 应用当前设置到播放器
  /// 注意：media_kit 的 Player 在运行时不支持动态更换滤镜。
  /// 均衡器设置会在下次播放新曲目时生效（通过 MediaKitAudioEngine.open 传递）。
  Future<void> _apply() async {
    // 设置已保存，下次播放时生效
    // 这里不做实时滤镜切换，避免播放中断
  }

  /// 获取当前的 FFmpeg 滤镜字符串，供 MediaKitAudioEngine.open 使用
  String? getCurrentFilter() {
    final gains = activeGains;
    if (!enabled || !gains.any((g) => g != 0)) return null;
    return EqualizerPreset(id: '', name: '', gains: gains).toFfmpegFilter();
  }

  /// 获取所有可用预设（内置 + 自定义）
  List<EqualizerPreset> getAllPresets() {
    return [...EqualizerPresets.builtin, ...customPresets];
  }
}

/// Test-only mock prefs that returns defaults
class _TestPrefs implements SharedPreferences {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Riverpod providers
final equalizerServiceProvider = Provider<EqualizerService>((ref) {
  // 由 main.dart 初始化时注入
  throw UnimplementedError('EqualizerService must be overridden in main.dart');
});

final equalizerEnabledProvider = StateNotifierProvider<EqualizerEnabledNotifier, bool>((ref) {
  return EqualizerEnabledNotifier(ref);
});

final equalizerCurrentPresetProvider = StateNotifierProvider<EqualizerPresetNotifier, String>((ref) {
  return EqualizerPresetNotifier(ref);
});

final equalizerCustomGainsProvider = StateNotifierProvider<EqualizerGainsNotifier, List<double>>((ref) {
  return EqualizerGainsNotifier(ref);
});

class EqualizerEnabledNotifier extends StateNotifier<bool> {
  EqualizerEnabledNotifier(this._ref) : super(false) {
    _init();
  }

  final Ref _ref;

  Future<void> _init() async {
    final service = _ref.read(equalizerServiceProvider);
    state = service.enabled;
  }

  Future<void> toggle() async {
    final service = _ref.read(equalizerServiceProvider);
    final newValue = !state;
    await service.setEnabled(newValue);
    state = newValue;
  }

  Future<void> setEnabled(bool value) async {
    final service = _ref.read(equalizerServiceProvider);
    await service.setEnabled(value);
    state = value;
  }
}

class EqualizerPresetNotifier extends StateNotifier<String> {
  EqualizerPresetNotifier(this._ref) : super('flat') {
    _init();
  }

  final Ref _ref;

  Future<void> _init() async {
    final service = _ref.read(equalizerServiceProvider);
    state = service.currentPresetId;
  }

  Future<void> selectPreset(String presetId) async {
    final service = _ref.read(equalizerServiceProvider);
    await service.selectPreset(presetId);
    state = presetId;
    // 同步自定义增益
    if (presetId != 'custom') {
      _ref.read(equalizerCustomGainsProvider.notifier).setGains(service.activeGains);
    }
  }
}

class EqualizerGainsNotifier extends StateNotifier<List<double>> {
  EqualizerGainsNotifier(this._ref) : super(List.filled(10, 0.0)) {
    _init();
  }

  final Ref _ref;

  Future<void> _init() async {
    final service = _ref.read(equalizerServiceProvider);
    state = service.customGains;
  }

  Future<void> setGains(List<double> gains) async {
    state = gains;
  }

  Future<void> updateBand(int index, double gain) async {
    final newGains = List<double>.from(state);
    newGains[index] = gain.clamp(-12.0, 12.0);
    state = newGains;

    final service = _ref.read(equalizerServiceProvider);
    await service.setCustomGains(newGains);
    _ref.read(equalizerCurrentPresetProvider.notifier).state = 'custom';
  }

  Future<void> reset() async {
    final service = _ref.read(equalizerServiceProvider);
    await service.reset();
    state = List.filled(10, 0.0);
    _ref.read(equalizerCurrentPresetProvider.notifier).state = 'flat';
    _ref.read(equalizerEnabledProvider.notifier).state = false;
  }
}