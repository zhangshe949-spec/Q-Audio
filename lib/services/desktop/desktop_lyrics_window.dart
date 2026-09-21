import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import '../../domain/entities/lyrics.dart';
import '../../presentation/providers/catalog_providers.dart'
    show lyricsServiceProvider, playbackStateStreamProvider;
import '../../presentation/providers/player_providers.dart'
    show playerProvider, PlaybackStatus, PlaybackState;

/// 桌面歌词悬浮窗服务
class DesktopLyricsWindowService {
  DesktopLyricsWindowService(this._ref);

  final Ref _ref;
  bool _initialized = false;
  bool _isVisible = false;
  Timer? _syncTimer;
  StreamSubscription? _lyricsSubscription;
  StreamSubscription? _playbackSubscription;

  final GlobalKey<_DesktopLyricsOverlayState> _overlayKey = GlobalKey();

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    // 监听播放状态变化流
    _playbackSubscription =
        _ref.read(playbackStateStreamProvider).listen(_onPlaybackChanged);

    _initialized = true;
  }

  void _onPlaybackChanged(PlaybackState? playback) {
    if (playback == null) return;
    if (playback.track != null &&
        playback.status == PlaybackStatus.playing &&
        !_isVisible) {
      show();
    } else if (playback.status != PlaybackStatus.playing && _isVisible) {
      hide();
    }
  }

  Future<void> show() async {
    if (!_initialized || _isVisible || kIsWeb) return;

    _isVisible = true;
    _startSyncTimer();

    // 加载当前播放歌曲的歌词
    final playback = _ref.read(playerProvider);
    if (playback.track != null) {
      final lyrics =
          await _ref.read(lyricsServiceProvider).getLyrics(playback.track!);
      _overlayKey.currentState?.updateLyrics(lyrics);
    }

    // 创建悬浮窗
    await _createOverlayWindow();
  }

  Future<void> hide() async {
    if (!_isVisible || kIsWeb) return;

    _isVisible = false;
    _stopSyncTimer();
    await windowManager.close();
  }

  Future<void> _createOverlayWindow() async {
    await windowManager.setSize(const Size(400, 200));
    await windowManager.setPosition(const Offset(100, 100));
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(true);
    await windowManager.setResizable(false);
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.setTitle('');
    await windowManager.setAsFrameless();

    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _DesktopLyricsOverlay(
          key: _overlayKey,
          ref: _ref,
        ),
      ),
    );
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _overlayKey.currentState?.syncPosition();
    });
  }

  void _stopSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  Future<void> toggle() async {
    if (_isVisible) {
      await hide();
    } else {
      await show();
    }
  }

  Future<void> dispose() async {
    _stopSyncTimer();
    await _lyricsSubscription?.cancel();
    await _playbackSubscription?.cancel();
    if (_isVisible) {
      await hide();
    }
    _initialized = false;
  }
}

final desktopLyricsWindowProvider = Provider<DesktopLyricsWindowService>((ref) {
  return DesktopLyricsWindowService(ref);
});

/// 桌面歌词悬浮窗组件
class _DesktopLyricsOverlay extends ConsumerStatefulWidget {
  const _DesktopLyricsOverlay({
    super.key,
    required this.ref,
  });

  final Ref ref;

  @override
  ConsumerState<_DesktopLyricsOverlay> createState() =>
      _DesktopLyricsOverlayState();
}

class _DesktopLyricsOverlayState extends ConsumerState<_DesktopLyricsOverlay>
    with WindowListener {
  Lyrics? _lyrics;
  int _currentLineIndex = -1;
  double _opacity = 0.9;
  double _fontSize = 16.0;
  bool _showTranslation = true;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  void updateLyrics(Lyrics? lyrics) {
    if (mounted) {
      setState(() {
        _lyrics = lyrics;
        _currentLineIndex = -1;
      });
    }
  }

  void syncPosition() {
    if (_lyrics == null || _lyrics!.lines.isEmpty) return;

    final playback = ref.read(playerProvider);
    final position = playback.position.inMilliseconds;

    int newIndex = -1;
    for (int i = 0; i < _lyrics!.lines.length; i++) {
      if (_lyrics!.lines[i].time <= position) {
        newIndex = i;
      } else {
        break;
      }
    }

    if (newIndex != _currentLineIndex && mounted) {
      setState(() => _currentLineIndex = newIndex);
    }
  }

  @override
  void onWindowFocus() {
    if (mounted) {
      setState(() => _opacity = 0.5);
    }
  }

  @override
  void onWindowBlur() {
    if (mounted) {
      setState(() => _opacity = 0.9);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) => windowManager.startDragging(),
      onDoubleTap: () => _showSettings(),
      child: Container(
        color: Colors.transparent,
        child: AnimatedOpacity(
          opacity: _opacity,
          duration: const Duration(milliseconds: 200),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: _buildLyricsContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildLyricsContent() {
    if (_lyrics == null || _lyrics!.lines.isEmpty) {
      return const Center(
        child: Text(
          '暂无歌词',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      );
    }

    final lines = _lyrics!.lines;
    final currentLine =
        _currentLineIndex >= 0 && _currentLineIndex < lines.length
            ? lines[_currentLineIndex]
            : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 上一行
        if (_currentLineIndex > 0)
          _LyricsLine(
            text: lines[_currentLineIndex - 1].text,
            translation: _showTranslation
                ? lines[_currentLineIndex - 1].translation
                : null,
            isCurrent: false,
            isPast: true,
            fontSize: _fontSize,
          ),
        // 当前行
        if (currentLine != null)
          _LyricsLine(
            text: currentLine.text,
            translation: _showTranslation ? currentLine.translation : null,
            isCurrent: true,
            fontSize: _fontSize + 2,
          ),
        // 下一行
        if (_currentLineIndex + 1 < lines.length)
          _LyricsLine(
            text: lines[_currentLineIndex + 1].text,
            translation: _showTranslation
                ? lines[_currentLineIndex + 1].translation
                : null,
            isCurrent: false,
            isFuture: true,
            fontSize: _fontSize,
          ),
      ],
    );
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('桌面歌词设置', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('透明度', style: TextStyle(color: Colors.white)),
              trailing: Slider(
                value: _opacity,
                min: 0.3,
                max: 1.0,
                onChanged: (v) => setState(() => _opacity = v),
              ),
            ),
            ListTile(
              title: const Text('字体大小', style: TextStyle(color: Colors.white)),
              trailing: Slider(
                value: _fontSize,
                min: 12.0,
                max: 28.0,
                onChanged: (v) => setState(() => _fontSize = v),
              ),
            ),
            SwitchListTile(
              title: const Text('显示翻译', style: TextStyle(color: Colors.white)),
              value: _showTranslation,
              onChanged: (v) => setState(() => _showTranslation = v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }
}

class _LyricsLine extends StatelessWidget {
  const _LyricsLine({
    required this.text,
    this.translation,
    this.isCurrent = false,
    this.isPast = false,
    this.isFuture = false,
    this.fontSize = 16.0,
  });

  final String text;
  final String? translation;
  final bool isCurrent;
  final bool isPast;
  final bool isFuture;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    Color textColor = Colors.white70;
    FontWeight weight = FontWeight.normal;

    if (isCurrent) {
      textColor = Colors.white;
      weight = FontWeight.w600;
    } else if (isPast) {
      textColor = Colors.white54;
    } else if (isFuture) {
      textColor = Colors.white38;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontWeight: weight,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
        if (translation != null && translation!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            translation!,
            style: TextStyle(
              color: textColor.withOpacity(0.7),
              fontSize: fontSize * 0.85,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
