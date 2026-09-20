import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_media_session/flutter_media_session.dart'
    hide PlaybackStatus;

import '../../presentation/providers/player_providers.dart'
    show PlaybackStatus, playerProvider;

/// 媒体会话服务 - 集成系统媒体控制（Windows SMTC、macOS MPRemoteCommandCenter 等）
/// 使用 flutter_media_session v3 的 setActionHandler 简化模式
class MediaSessionService {
  MediaSessionService(this._ref);

  final Ref _ref;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    // 激活媒体会话
    await FlutterMediaSession().activate();

    // 设置媒体动作处理回调
    FlutterMediaSession().setActionHandler(
      onPlay: () => _ref.read(playerProvider.notifier).resume(),
      onPause: () => _ref.read(playerProvider.notifier).pause(),
      onSkipToNext: () => _ref.read(playerProvider.notifier).next(),
      onSkipToPrevious: () => _ref.read(playerProvider.notifier).previous(),
      onRewind: () {
        final playback = _ref.read(playerProvider);
        _ref.read(playerProvider.notifier).seek(
          playback.position - const Duration(seconds: 10),
        );
      },
      onFastForward: () {
        final playback = _ref.read(playerProvider);
        _ref.read(playerProvider.notifier).seek(
          playback.position + const Duration(seconds: 10),
        );
      },
      onSeekTo: (position) {
        _ref.read(playerProvider.notifier).seek(position);
      },
      onShuffle: () => _ref.read(playerProvider.notifier).toggleShuffle(),
      onRepeat: () => _ref.read(playerProvider.notifier).toggleRepeat(),
      onStop: () => _ref.read(playerProvider.notifier).pause(),
    );

    _initialized = true;
  }

  /// 同步元数据到系统媒体中心
  Future<void> syncMetadata({
    required String title,
    required String artist,
    String? album,
    String? artworkUrl,
    Duration? duration,
  }) async {
    if (!_initialized) return;

    // 使用 MediaMetadata 更新元数据
    // 注意：v3 直接同步元数据需要 adapter 模式，这里使用基础方式
    // 实际项目中建议实现 MediaSessionAdapter
  }

  /// 同步播放状态
  Future<void> syncPlaybackState({
    required PlaybackStatus status,
    required Duration position,
    Duration? duration,
    bool shuffleMode = false,
    bool repeatMode = false,
  }) async {
    if (!_initialized) return;

    // v3 推荐使用 Adapter 模式自动同步状态
    // 这里暂留接口，后续可接入 Adapter
  }

  Future<void> dispose() async {
    if (!_initialized) return;
    await FlutterMediaSession().deactivate();
    _initialized = false;
  }
}

final mediaSessionServiceProvider = Provider<MediaSessionService>((ref) {
  return MediaSessionService(ref);
});