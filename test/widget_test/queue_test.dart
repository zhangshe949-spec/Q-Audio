import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import 'package:q_audio/domain/entities/track.dart';
import 'package:q_audio/presentation/providers/player_providers.dart';
import 'package:q_audio/services/playback/player_controller.dart';

import '../test_app.dart';

/// Fake engine whose load() returns a short duration so the auto-next
/// positionStream test can complete deterministically.
class ShortEngine extends FakeAudioEngine {
  @override
  Future<Duration?> load(String url, {String? audioFilter}) async {
    duration = const Duration(seconds: 10);
    return duration;
  }
}

Track _track(String id, {String? url}) =>
    Track(id: id, sourceId: 'test', title: 'Track $id', url: url);

/// Wait for playerProvider state to reach expected track using Riverpod listener.
Future<void> waitForTrack(WidgetTester tester, ProviderContainer container,
    String expectedTrackId) async {
  final completer = Completer<void>();
  final subscription = container.listen<PlaybackState>(
    playerProvider,
    (_, next) {
      if (next.track?.id == expectedTrackId && !completer.isCompleted) {
        completer.complete();
      }
    },
    fireImmediately: true,
  );
  // Pump to process any pending state updates
  await tester.pump(const Duration(milliseconds: 16));
  // Wait for the listener to fire, with timeout
  await completer.future.timeout(const Duration(seconds: 10));
  subscription.close();
}

void main() {
  testWidgets('setQueue + playAt lights the mini player', (tester) async {
    final engine = FakeAudioEngine();
    final tracks = [
      _track('1', url: 'https://a.test/1'),
      _track('2', url: 'https://a.test/2'),
    ];
    await mountApp(
      tester,
      additionalOverrides: [audioEngineProvider.overrideWithValue(engine)],
    );
    final context = tester.element(find.byType(Navigator).first);
    final container = ProviderScope.containerOf(context, listen: false);
    final notifier = container.read(playerProvider.notifier);
    notifier.setQueue(tracks);
    await waitForTrack(tester, container, '2');
    notifier.playAt(1);
    await tester.pumpAndSettle();
    expect(container.read(playerProvider).track?.id, '2');
    expect(find.byKey(const Key('mini-player')), findsOneWidget);
    expect(find.text('Track 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('next/previous stay in bounds', (tester) async {
    final engine = FakeAudioEngine();
    final tracks = [
      _track('1', url: 'https://a.test/1'),
      _track('2', url: 'https://a.test/2'),
      _track('3', url: 'https://a.test/3'),
    ];
    await mountApp(
      tester,
      additionalOverrides: [audioEngineProvider.overrideWithValue(engine)],
    );
    final context = tester.element(find.byType(Navigator).first);
    final container = ProviderScope.containerOf(context, listen: false);
    final notifier = container.read(playerProvider.notifier);
    notifier.setQueue(tracks);
    notifier.playAt(0);
    await waitForTrack(tester, container, '1');
    await tester.pumpAndSettle();
    expect(container.read(playerProvider).track?.id, '1');
    expect(container.read(playerProvider.notifier).currentIndex, 0);

    notifier.next();
    await waitForTrack(tester, container, '2');
    await tester.pumpAndSettle();
    expect(container.read(playerProvider).track?.id, '2');
    expect(container.read(playerProvider.notifier).currentIndex, 1);

    notifier.next();
    await waitForTrack(tester, container, '3');
    await tester.pumpAndSettle();
    expect(container.read(playerProvider).track?.id, '3');
    expect(container.read(playerProvider.notifier).currentIndex, 2);

    // At the tail: next() must not throw and must not move.
    notifier.next();
    await waitForTrack(tester, container, '3');
    await tester.pumpAndSettle();
    expect(container.read(playerProvider).track?.id, '3');
    expect(container.read(playerProvider.notifier).currentIndex, 2);

    notifier.previous();
    await waitForTrack(tester, container, '2');
    await tester.pumpAndSettle();
    expect(container.read(playerProvider).track?.id, '2');
    expect(container.read(playerProvider.notifier).currentIndex, 1);

    notifier.previous();
    await waitForTrack(tester, container, '1');
    await tester.pumpAndSettle();
    expect(container.read(playerProvider).track?.id, '1');
    expect(container.read(playerProvider.notifier).currentIndex, 0);

    // At the head: previous() must not throw and must not move.
    notifier.previous();
    await waitForTrack(tester, container, '1');
    await tester.pumpAndSettle();
    expect(container.read(playerProvider).track?.id, '1');
    expect(container.read(playerProvider.notifier).currentIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('null-url row shows a snackbar and stays idle', (tester) async {
    final engine = FakeAudioEngine();
    final tracks = [_track('1', url: 'https://a.test/1'), _track('2')];
    await mountApp(
      tester,
      additionalOverrides: [audioEngineProvider.overrideWithValue(engine)],
    );
    final context = tester.element(find.byType(Navigator).first);
    final container = ProviderScope.containerOf(context, listen: false);
    final notifier = container.read(playerProvider.notifier);
    notifier.setQueue(tracks);
    notifier.playAt(1);
    await waitForTrack(tester, container, '1'); // Should stay on track 1
    await tester.pumpAndSettle();
    expect(container.read(playerProvider).status, PlaybackStatus.idle);
    expect(container.read(playerProvider).error, '该歌曲没有播放地址');
    expect(find.byKey(const Key('mini-player')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reaching duration auto-advances to the next track', (
    tester,
  ) async {
    final engine = ShortEngine();
    final tracks = [
      _track('1', url: 'https://a.test/1'),
      _track('2', url: 'https://a.test/2'),
    ];
    await mountApp(
      tester,
      additionalOverrides: [audioEngineProvider.overrideWithValue(engine)],
    );
    final context = tester.element(find.byType(Navigator).first);
    final container = ProviderScope.containerOf(context, listen: false);
    final notifier = container.read(playerProvider.notifier);
    notifier.setQueue(tracks);
    notifier.playAt(0);
    await waitForTrack(tester, container, '1');
    await tester.pumpAndSettle();
    expect(container.read(playerProvider).track?.id, '1');
    expect(container.read(playerProvider).status, PlaybackStatus.playing);

    // Simulate playback reaching the end of the 10s track.
    engine.tick(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    await waitForTrack(tester, container, '2');
    expect(container.read(playerProvider).status, PlaybackStatus.playing);
    expect(container.read(playerProvider.notifier).currentIndex, 1);

    // Last track: reaching the end pauses instead of throwing.
    engine.tick(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    await waitForTrack(tester, container, '2');
    expect(container.read(playerProvider).status, PlaybackStatus.paused);
    expect(tester.takeException(), isNull);
  });
}