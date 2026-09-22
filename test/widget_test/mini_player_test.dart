import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:q_audio/domain/entities/track.dart';
import 'package:q_audio/presentation/providers/player_providers.dart';
import 'package:q_audio/services/playback/player_controller.dart';

import '../test_app.dart';

class ThrowingEngine implements AudioEngine {
  @override
  Future<Duration?> load(String url, {String? audioFilter}) async =>
      throw Exception('source broken');
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> dispose() async {}
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Future<void> seek(Duration position) async {}
  @override
  double get volume => 1.0;
  @override
  Future<void> setVolume(double volume) async {}
}

class FakeAudioEngine implements AudioEngine {
  final StreamController<Duration> _positions =
      StreamController<Duration>.broadcast();

  Duration? duration;
  double _volume = 1.0;

  @override
  Future<Duration?> load(String url, {String? audioFilter}) async {
    duration = const Duration(minutes: 3);
    return duration;
  }

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> dispose() async {
    await _positions.close();
  }

  @override
  Stream<Duration> get positionStream => _positions.stream;

  @override
  Future<void> seek(Duration position) async {}

  @override
  double get volume => _volume;

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
  }

  /// Test hook: emits progress as if the media were playing.
  void tick(Duration elapsed) {
    if (!_positions.isClosed) _positions.add(elapsed);
  }
}

void main() {
  testWidgets('mini player shows idle placeholder when nothing is playing', (
    tester,
  ) async {
    final engine = FakeAudioEngine();
    await mountApp(
      tester,
      additionalOverrides: [audioEngineProvider.overrideWithValue(engine)],
    );
    expect(find.textContaining('（占位）'), findsOneWidget);
    expect(find.byKey(const Key('mini-player')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('playing a track lights the mini player and toggles state', (
    tester,
  ) async {
    final engine = FakeAudioEngine();
    await mountApp(
      tester,
      additionalOverrides: [audioEngineProvider.overrideWithValue(engine)],
    );
    final context = tester.element(find.byType(Navigator).first);
    final widgetContainer = ProviderScope.containerOf(context, listen: false);
    final track = Track(
      id: '1',
      sourceId: 'test',
      title: '晨光',
      artist: 'Alice',
    );
    await widgetContainer
        .read(playerProvider.notifier)
        .play(track, 'https://example.test/a.mp3');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('mini-player')), findsOneWidget);
    // Title appears in the home "now playing" card and the mini player.
    expect(find.text('晨光'), findsWidgets);
    expect(find.text('Alice'), findsOneWidget);
    expect(widgetContainer.read(playerProvider).status, PlaybackStatus.playing);
    await tester.tap(find.byKey(const Key('mini-play-toggle')));
    await tester.pumpAndSettle();
    expect(widgetContainer.read(playerProvider).status, PlaybackStatus.paused);
    await tester.tap(find.byKey(const Key('mini-play-toggle')));
    await tester.pumpAndSettle();
    expect(widgetContainer.read(playerProvider).status, PlaybackStatus.playing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('position stream advances the playback state', (tester) async {
    final engine = FakeAudioEngine();
    await mountApp(
      tester,
      additionalOverrides: [audioEngineProvider.overrideWithValue(engine)],
    );
    final context = tester.element(find.byType(Navigator).first);
    final widgetContainer = ProviderScope.containerOf(context, listen: false);
    final track = Track(id: '2', sourceId: 'test', title: '夜航');
    await widgetContainer
        .read(playerProvider.notifier)
        .play(track, 'https://example.test/b.mp3');
    await tester.pumpAndSettle();
    engine.tick(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(
      widgetContainer.read(playerProvider).position,
      const Duration(seconds: 30),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('load failure lands in state error, UI stays alive', (
    tester,
  ) async {
    await mountApp(
      tester,
      additionalOverrides: [
        audioEngineProvider.overrideWithValue(ThrowingEngine()),
      ],
    );
    final context = tester.element(find.byType(Navigator).first);
    final widgetContainer = ProviderScope.containerOf(context, listen: false);
    final track = Track(id: '3', sourceId: 'test', title: '坏源');
    await widgetContainer
        .read(playerProvider.notifier)
        .play(track, 'https://example.test/c.mp3');
    await tester.pumpAndSettle();
    expect(widgetContainer.read(playerProvider).status, PlaybackStatus.idle);
    expect(widgetContainer.read(playerProvider).error, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
