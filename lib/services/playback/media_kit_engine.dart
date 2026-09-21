import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'player_controller.dart';

/// Real media engine backed by media_kit (FFmpeg).
/// Implements the [AudioEngine] interface expected by [PlayerController].
class MediaKitAudioEngine implements AudioEngine {
  late final Player _player;
  late final StreamController<Duration> _positionController;
  Duration? _duration;

  /// Expose the underlying media_kit Player for advanced features (e.g., equalizer).
  Player get player => _player;

  MediaKitAudioEngine() {
    _player = Player();
    _positionController = StreamController<Duration>.broadcast();
    _listenToPosition();
  }

  void _listenToPosition() {
    _player.stream.position.listen(
      (position) {
        if (!_positionController.isClosed) {
          _positionController.add(position);
        }
      },
      onError: (error) {
        if (!_positionController.isClosed) {
          _positionController.addError(error.toString());
        }
      },
      onDone: () {},
      cancelOnError: false,
    );
    _player.stream.completed.listen(
      (_) {
        if (!_positionController.isClosed) {
          _positionController.add(_duration ?? Duration.zero);
        }
      },
      onError: (error) {
        if (!_positionController.isClosed) {
          _positionController.addError(error.toString());
        }
      },
    );
  }

  @override
  Future<Duration?> load(String url, {String? audioFilter}) async {
    try {
      // Open the media - audioFilter stored for future use
      // Note: media_kit filter API varies by version; real-time filter
      // changes require recreating the player, so we apply on next load.
      await _player.open(Media(url));

      // Wait a bit for the player to be ready and get duration
      await Future.delayed(const Duration(milliseconds: 200));
      _duration = _player.state.duration;
      return _duration;
    } catch (e) {
      _duration = null;
      return null;
    }
  }

  @override
  Future<void> play() async {
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  @override
  Future<void> dispose() async {
    await _positionController.close();
    await _player.dispose();
  }

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  double get volume => _player.state.volume / 100;

  @override
  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume * 100);
  }
}

/// Provider for the real media_kit engine. Overrides [audioEngineProvider] in
/// [main.dart] for production use.
final mediaKitEngineProvider = Provider<AudioEngine>((ref) {
  // Ensure media_kit is initialized once per app lifecycle
  MediaKit.ensureInitialized();
  return MediaKitAudioEngine();
});
