import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/track.dart';
import '../../services/equalizer/equalizer_providers.dart';

/// Engine binding. Production: main.dart overrides with the real media_kit
/// engine. Tests: override with FakeAudioEngine.
final audioEngineProvider = Provider<AudioEngine>((ref) {
  throw UnimplementedError('audioEngineProvider must be overridden.');
});

/// Playback states for the mini-player and future full player page.
enum PlaybackStatus { idle, loading, playing, paused }

/// Immutable snapshot consumed by UI widgets.
class PlaybackState {
  const PlaybackState({
    this.track,
    this.status = PlaybackStatus.idle,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.error,
    this.shuffleMode = false,
    this.repeatMode = false,
    this.volume = 1.0,
  });

  final Track? track;
  final PlaybackStatus status;
  final Duration position;
  final Duration duration;
  final String? error;
  final bool shuffleMode;
  final bool repeatMode;
  final double volume;

  bool get hasTrack => track != null;

  PlaybackState copyWith({
    Track? track,
    PlaybackStatus? status,
    Duration? position,
    Duration? duration,
    String? error,
    bool? shuffleMode,
    bool? repeatMode,
    double? volume,
    bool clearError = false,
  }) => PlaybackState(
    track: track ?? this.track,
    status: status ?? this.status,
    position: position ?? this.position,
    duration: duration ?? this.duration,
    error: clearError ? null : (error ?? this.error),
    shuffleMode: shuffleMode ?? this.shuffleMode,
    repeatMode: repeatMode ?? this.repeatMode,
    volume: volume ?? this.volume,
  );
}

/// Platform media engines stay behind this interface; UI never touches them.
abstract interface class AudioEngine {
  Future<Duration?> load(String url, {String? audioFilter});
  Future<void> play();
  Future<void> pause();
  Future<void> dispose();
  Stream<Duration> get positionStream;
  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);
  double get volume;
}

/// Deterministic fake engine for tests and offline UI work. No audio device
/// access; position only advances when tests push values into positionStream.
class FakeAudioEngine implements AudioEngine {
  final StreamController<Duration> _positions =
      StreamController<Duration>.broadcast();

  Duration? duration;
  double _volume = 1.0;

  @override
    Future<Duration?> load(String url, {String? audioFilter}) {
      duration = const Duration(minutes: 3);
      return Future.value(duration);
    }

  @override
  Future<void> play() => Future.value(null);

  @override
  Future<void> pause() => Future.value(null);

  @override
  Future<void> seek(Duration position) => Future.value(null);

  @override
  Future<void> setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    return Future.value(null);
  }

  @override
  Stream<Duration> get positionStream => _positions.stream;

  @override
  Future<void> dispose() async {
    await _positions.close();
  }

  /// Test hook: emits progress as if the media were playing.
  void tick(Duration elapsed) {
      if (!_positions.isClosed) _positions.add(elapsed);
    }

    @override
    double get volume => _volume;
  }

/// Owns engine lifecycle and exposes playback state to widgets.
/// The engine is resolved from the provider graph; errors land in state,
/// never thrown into build.
class PlayerController extends Notifier<PlaybackState> {
  AudioEngine? _engine;
  StreamSubscription<Duration>? _positionSub;
  List<Track>? _queue;
  int? _currentIndex;
  List<int>? _shuffleOrder;
  int? _shufflePosition;
  int _playGeneration = 0; // Incremented on each play() call to detect stale continuations

  @override
  PlaybackState build() => const PlaybackState();

  // Public getters for UI
  List<Track>? get queue => _queue;
  int? get currentIndex => _currentIndex;
  bool get shuffleMode => state.shuffleMode;
  bool get repeatMode => state.repeatMode;
  double get volume => state.volume;

  void setQueue(List<Track> tracks, {int startIndex = 0}) {
    if (tracks.isEmpty) {
      throw ArgumentError('Queue must not be empty.');
    }
    if (startIndex < 0 || startIndex >= tracks.length) {
      throw RangeError('startIndex must be within [0, ${tracks.length}).');
    }
    _queue = tracks;
    _currentIndex = startIndex;
    _resetShuffle();
    state = state.copyWith(shuffleMode: false, repeatMode: false);
  }

  void _resetShuffle() {
    if (_queue == null) return;
    _shuffleOrder = List.generate(_queue!.length, (i) => i);
    _shuffleOrder!.shuffle(Random());
    _shufflePosition = _shuffleOrder!.indexOf(_currentIndex ?? 0);
  }

  Future<void> playAt(int index) async {
    final queue = _queue;
    if (queue == null) {
      throw RangeError('No queue set.');
    }
    if (index < 0 || index >= queue.length) {
      throw RangeError('Index $index is out of range [0, ${queue.length}).');
    }
    final track = queue[index];
    if (track.url == null) {
      state = state.copyWith(
        track: track,
        status: PlaybackStatus.idle,
        error: '该歌曲没有播放地址',
      );
      return;
    }
    await play(track, track.url!);
    _currentIndex = index;
    if (state.shuffleMode) {
      _shufflePosition = _shuffleOrder!.indexOf(index);
    }
  }

  Future<void> next() {
      final queue = _queue;
      final index = _currentIndex;
      if (queue == null || index == null) return Future.value(null);

      int nextIndex;
      if (state.shuffleMode && _shuffleOrder != null) {
        final nextPos = (_shufflePosition ?? 0) + 1;
        if (nextPos < _shuffleOrder!.length) {
          _shufflePosition = nextPos;
          nextIndex = _shuffleOrder![nextPos];
        } else if (state.repeatMode) {
          _shufflePosition = 0;
          nextIndex = _shuffleOrder!.first;
        } else {
          state = state.copyWith(status: PlaybackStatus.paused);
          return Future.value(null);
        }
      } else {
        nextIndex = index + 1;
        if (nextIndex >= queue.length) {
          if (state.repeatMode) {
            nextIndex = 0;
          } else {
            state = state.copyWith(status: PlaybackStatus.paused);
            return Future.value(null);
          }
        }
      }
      return playAt(nextIndex);
    }

    Future<void> previous() {
      final queue = _queue;
      final index = _currentIndex;
      if (queue == null || index == null) return Future.value(null);

      int prevIndex;
      if (state.shuffleMode && _shuffleOrder != null) {
        final prevPos = (_shufflePosition ?? 0) - 1;
        if (prevPos >= 0) {
          _shufflePosition = prevPos;
          prevIndex = _shuffleOrder![prevPos];
        } else if (state.repeatMode) {
          _shufflePosition = _shuffleOrder!.length - 1;
          prevIndex = _shuffleOrder!.last;
        } else {
          return Future.value(null);
        }
      } else {
        prevIndex = index - 1;
        if (prevIndex < 0) {
          if (state.repeatMode) {
            prevIndex = queue.length - 1;
          } else {
            return Future.value(null);
          }
        }
      }
      return playAt(prevIndex);
    }

  Future<void> play(Track track, String url) async {
    final generation = ++_playGeneration;
    try {
      await _positionSub?.cancel();
            _positionSub?.cancel(); // fire-and-forget; broadcast stream cancel is sync
            final engine = ref.read(audioEngineProvider);
      _engine = engine;

      String? filter;
      try {
        final eqService = ref.read(equalizerServiceProvider);
        filter = eqService.getCurrentFilter();
      } catch (e) {
        // ignore
      }

      if (generation != _playGeneration) {
        return;
      }

      state = PlaybackState(
        track: track,
        status: PlaybackStatus.loading,
        shuffleMode: state.shuffleMode,
        repeatMode: state.repeatMode,
        volume: state.volume,
      );

      final duration = await engine.load(url, audioFilter: filter) ?? Duration.zero;

      if (generation != _playGeneration) {
        return;
      }

      await engine.play();

      if (generation != _playGeneration) {
        return;
      }

      await engine.setVolume(state.volume);

      if (generation != _playGeneration) {
        return;
      }

      await _positionSub?.cancel();
      _positionSub = engine.positionStream.listen(
        (position) {
          if (generation != _playGeneration) {
            return;
          }
          if (duration > Duration.zero && position >= duration) {
            _autoNext();
            return;
          }
          state = state.copyWith(
            position: position,
            status: PlaybackStatus.playing,
            clearError: true,
          );
        },
        onError: (Object error) {
          if (generation != _playGeneration) {
            return;
          }
          state = state.copyWith(
            status: PlaybackStatus.idle,
            error: error.toString(),
          );
        },
      );

      if (generation != _playGeneration) {
        return;
      }

      state = state.copyWith(
        duration: duration,
        status: PlaybackStatus.playing,
        clearError: true,
      );
    } catch (error) {
      if (generation == _playGeneration) {
        state = PlaybackState(
          track: track,
          status: PlaybackStatus.idle,
          error: error.toString(),
          shuffleMode: state.shuffleMode,
          repeatMode: state.repeatMode,
          volume: state.volume,
        );
      }
    }
  }

  Future<void> _autoNext() async {
    final queue = _queue;
    final index = _currentIndex;
    if (queue == null || index == null) return;
    // Defer to microtask to avoid deadlock: play() awaits _positionSub?.cancel()
    // which waits for this listener to finish.
    await Future.microtask(() => next());
  }

  Future<void> pause() async {
    await _engine?.pause();
    if (state.status == PlaybackStatus.playing) {
      state = state.copyWith(status: PlaybackStatus.paused);
    }
  }

  Future<void> resume() async {
    await _engine?.play();
    state = state.copyWith(status: PlaybackStatus.playing, clearError: true);
  }

  Future<void> toggleShuffle() async {
    final newShuffle = !state.shuffleMode;
    if (newShuffle) {
      _resetShuffle();
    } else {
      _shuffleOrder = null;
      _shufflePosition = null;
    }
    state = state.copyWith(shuffleMode: newShuffle);
  }

  Future<void> toggleRepeat() async {
    state = state.copyWith(repeatMode: !state.repeatMode);
  }

  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    await _engine?.setVolume(clamped);
    state = state.copyWith(volume: clamped);
  }

  Future<void> seek(Duration position) async {
    await _engine?.seek(position);
    state = state.copyWith(position: position);
  }

  Future<void> removeFromQueue(int index) async {
    final queue = _queue;
    if (queue == null || index < 0 || index >= queue.length) return;

    final wasCurrent = index == _currentIndex;
    queue.removeAt(index);

    if (queue.isEmpty) {
      _queue = null;
      _currentIndex = null;
      _shuffleOrder = null;
      _shufflePosition = null;
      await shutdown();
      return;
    }

    if (wasCurrent) {
      // Play next track (which is now at same index)
      if (index >= queue.length) {
        _currentIndex = queue.length - 1;
      }
      await playAt(_currentIndex!);
    } else if (_currentIndex != null && index < _currentIndex!) {
      _currentIndex = _currentIndex! - 1;
    }

    if (state.shuffleMode) {
      _resetShuffle();
    }
  }

  Future<void> clearQueue() async {
    _queue = null;
    _currentIndex = null;
    _shuffleOrder = null;
    _shufflePosition = null;
    await shutdown();
  }

  Future<void> shutdown() async {
    await _positionSub?.cancel();
    await _engine?.dispose();
    _engine = null;
    state = const PlaybackState();
  }
}