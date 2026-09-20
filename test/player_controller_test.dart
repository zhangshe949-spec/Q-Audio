import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import 'package:q_audio/domain/entities/track.dart';
import 'package:q_audio/presentation/providers/player_providers.dart';
import 'package:q_audio/presentation/providers/catalog_providers.dart';
import 'package:q_audio/services/playback/player_controller.dart';
import 'package:q_audio/services/equalizer/equalizer_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fake engine for tests.
class TestAudioEngine implements AudioEngine {
  final StreamController<Duration> _positions = StreamController<Duration>.broadcast();
  Duration? _presetDuration;
  double _volume = 1.0;
  int loadCallCount = 0;

  @override
  Future<Duration?> load(String url, {String? audioFilter}) {
    loadCallCount++;
    // Return preset duration if set, otherwise default 3 minutes
    final d = _presetDuration ?? const Duration(minutes: 3);
    return Future.value(d);
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

  void tick(Duration elapsed) {
    if (!_positions.isClosed) _positions.add(elapsed);
  }

  void setPresetDuration(Duration d) {
    _presetDuration = d;
  }

  @override
  double get volume => _volume;
}

/// Test-only equalizer service
class TestEqualizerService extends EqualizerService {
  TestEqualizerService() : super.test();

  @override
  String? getCurrentFilter() => null;
}

Future<ProviderContainer> createTestContainer(TestAudioEngine engine) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      audioEngineProvider.overrideWithValue(engine),
      equalizerServiceProvider.overrideWith((ref) => TestEqualizerService()),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
}

Track _track(String id, {String? url}) =>
    Track(id: id, sourceId: 'test', title: 'Track $id', url: url);

void main() {
  group('PlayerController', () {
    late ProviderContainer container;
    late TestAudioEngine engine;

    setUp(() async {
      engine = TestAudioEngine();
      container = await createTestContainer(engine);
    });

    tearDown(() {
      container.dispose();
    });

    test('setQueue + playAt sets track and plays', () async {
      final notifier = container.read(playerProvider.notifier);
      final tracks = [_track('1', url: 'https://a.test/1'), _track('2', url: 'https://a.test/2')];

      notifier.setQueue(tracks);
      await notifier.playAt(1);

      final state = container.read(playerProvider);
      expect(state.track?.id, '2');
      expect(state.status, PlaybackStatus.playing);
      expect(notifier.currentIndex, 1);
    });

    test('next/previous stay in bounds', () async {
      final notifier = container.read(playerProvider.notifier);
      final tracks = [
        _track('1', url: 'https://a.test/1'),
        _track('2', url: 'https://a.test/2'),
        _track('3', url: 'https://a.test/3'),
      ];

      notifier.setQueue(tracks);
      await notifier.playAt(0);
      expect(container.read(playerProvider).track?.id, '1');
      expect(notifier.currentIndex, 0);

      await notifier.next();
      expect(container.read(playerProvider).track?.id, '2');
      expect(notifier.currentIndex, 1);

      await notifier.next();
      expect(container.read(playerProvider).track?.id, '3');
      expect(notifier.currentIndex, 2);

      // At the tail: next() must not throw and must not move.
      await notifier.next();
      expect(container.read(playerProvider).track?.id, '3');
      expect(notifier.currentIndex, 2);

      await notifier.previous();
      expect(container.read(playerProvider).track?.id, '2');
      expect(notifier.currentIndex, 1);

      await notifier.previous();
      expect(container.read(playerProvider).track?.id, '1');
      expect(notifier.currentIndex, 0);

      // At the head: previous() must not throw and must not move.
      await notifier.previous();
      expect(container.read(playerProvider).track?.id, '1');
      expect(notifier.currentIndex, 0);
    });

    test('null-url row shows error and stays idle', () async {
      final notifier = container.read(playerProvider.notifier);
      final tracks = [_track('1', url: 'https://a.test/1'), _track('2')];

      notifier.setQueue(tracks);
      await notifier.playAt(1);

      final state = container.read(playerProvider);
      expect(state.status, PlaybackStatus.idle);
      expect(state.error, '该歌曲没有播放地址');
    });

    test('auto-advance when reaching duration', () async {
      final shortEngine = TestAudioEngine()..setPresetDuration(const Duration(seconds: 10));
      final testContainer = await createTestContainer(shortEngine);
      final notifier = testContainer.read(playerProvider.notifier);
      final tracks = [
        _track('1', url: 'https://a.test/1'),
        _track('2', url: 'https://a.test/2'),
      ];

      notifier.setQueue(tracks);
      await notifier.playAt(0);
      expect(testContainer.read(playerProvider).track?.id, '1');
      expect(testContainer.read(playerProvider).status, PlaybackStatus.playing);

      // Simulate playback reaching the end.
      shortEngine.tick(const Duration(seconds: 10));
      // Allow microtasks for auto-advance to run (play() has multiple awaits)
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 10));
      }

      expect(testContainer.read(playerProvider).track?.id, '2');
      expect(testContainer.read(playerProvider).status, PlaybackStatus.playing);
      expect(notifier.currentIndex, 1);

      // Last track: reaching the end pauses.
      shortEngine.tick(const Duration(seconds: 10));
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 10));
      }

      expect(testContainer.read(playerProvider).track?.id, '2');
      expect(testContainer.read(playerProvider).status, PlaybackStatus.paused);

      testContainer.dispose();
    });
  });
}