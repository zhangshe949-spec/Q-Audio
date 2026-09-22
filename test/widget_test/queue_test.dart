import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Pumps until [playerProvider] state reaches [expectedTrackId] with the
/// given status, or fails the test after [maxPumps] iterations.
///
/// FakeAsync note: never await a bare future here — timers only advance when
/// the tester pumps, so a `.timeout()` would deadlock instead of firing.
Future<void> waitForTrack(
  WidgetTester tester,
  ProviderContainer container,
  String expectedTrackId, {
  PlaybackStatus? status,
  int maxPumps = 100,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    final state = container.read(playerProvider);
    if (state.track?.id == expectedTrackId &&
        (status == null || state.status == status)) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 16));
  }
  final state = container.read(playerProvider);
  fail(
    'playerProvider never reached track=$expectedTrackId'
    '${status != null ? ' status=$status' : ''} '
    'after $maxPumps pumps (got track=${state.track?.id} '
    'status=${state.status}).',
  );
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
    // setQueue only stages the queue; the track appears once playAt runs.
    notifier.playAt(1);
    await waitForTrack(tester, container, '2');
    await tester.pumpAndSettle();
    expect(container.read(playerProvider).track?.id, '2');
    expect(find.byKey(const Key('mini-player')), findsOneWidget);
    // Track title now appears in both the home "now playing" card and the
    // mini player bar.
    expect(find.text('Track 2'), findsWidgets);
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
    await notifier.next();
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
    await notifier.previous();
    await tester.pumpAndSettle();
    expect(container.read(playerProvider).track?.id, '1');
    expect(container.read(playerProvider.notifier).currentIndex, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('null-url row shows an error and stays idle', (tester) async {
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
    // playAt(1) targets the null-url track '2': the controller records it
    // with status idle and an error message; it never plays.
    await waitForTrack(tester, container, '2', status: PlaybackStatus.idle);
    await tester.pumpAndSettle();
    expect(container.read(playerProvider).status, PlaybackStatus.idle);
    expect(container.read(playerProvider).error, '该歌曲没有播放地址');
    // Mini player renders whenever a track is present, idle included.
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
    expect(container.read(playerProvider).status, PlaybackStatus.paused);
    expect(tester.takeException(), isNull);
  });
}
