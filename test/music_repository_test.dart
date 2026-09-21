import 'package:flutter_test/flutter_test.dart';
import 'package:q_audio/domain/entities/track.dart';
import 'package:q_audio/data/repositories/in_memory_music_repository.dart';

void main() {
  Track track(
    String id, {
    String source = 'local',
    String title = 'Test song',
    String artist = 'Test artist',
    String album = 'Test album',
  }) =>
      Track(
        id: id,
        sourceId: source,
        title: title,
        artist: artist,
        album: album,
      );

  test('empty repository has no fabricated songs', () async {
    final repository = InMemoryMusicRepository();
    expect(await repository.search(''), isEmpty);
    expect(await repository.findById(sourceId: 'local', id: 'missing'), isNull);
  });
  test('IDs are scoped to their source', () async {
    final repository = InMemoryMusicRepository();
    await repository.save(track('1', source: 'a', title: 'First'));
    await repository.save(track('1', source: 'b', title: 'Second'));
    expect((await repository.search('')).length, 2);
    expect(
      (await repository.findById(sourceId: 'b', id: '1'))?.title,
      'Second',
    );
  });
  test('record key cannot collide on separators', () async {
    final repository = InMemoryMusicRepository(
      initialTracks: [
        track('b:c', source: 'a'),
        track('c', source: 'a:b'),
      ],
    );
    expect((await repository.search('')).length, 2);
  });
  test('save replaces same key without reordering', () async {
    final repository = InMemoryMusicRepository(
      initialTracks: [track('1'), track('2')],
    );
    await repository.save(track('1', title: 'Updated'));
    final result = await repository.search('');
    expect(result.map((t) => t.id), ['1', '2']);
    expect(result.first.title, 'Updated');
  });
  test('search covers title artist album and source filter', () async {
    final repository = InMemoryMusicRepository(
      initialTracks: [
        track('1', title: '晨光', artist: 'Alice', album: 'Dawn'),
        track('2', source: 'radio', title: '晨光'),
      ],
    );
    expect((await repository.search(' 晨光 ', sourceId: 'local')).single.id, '1');
    expect((await repository.search('ALICE')).single.id, '1');
    expect((await repository.search('dAwN')).single.id, '1');
    expect(await repository.search('missing'), isEmpty);
  });
  test('pagination is bounded and results are immutable', () async {
    final repository = InMemoryMusicRepository(
      initialTracks: [track('1'), track('2'), track('3')],
    );
    final page = await repository.search('', offset: 1, limit: 1);
    expect(page.single.id, '2');
    expect(() => page.add(track('4')), throwsUnsupportedError);
    expect(await repository.search('', offset: 10), isEmpty);
    expect((await repository.search('')).length, 3);
  });
  test('invalid pagination reports argument errors', () async {
    final repository = InMemoryMusicRepository();
    await expectLater(repository.search('', offset: -1), throwsArgumentError);
    await expectLater(repository.search('', limit: 0), throwsArgumentError);
    await expectLater(repository.search('', limit: 201), throwsArgumentError);
  });
  test('remove is idempotent and isolated by source', () async {
    final repository = InMemoryMusicRepository(
      initialTracks: [
        track('1'),
        track('1', source: 'other'),
      ],
    );
    expect(await repository.remove(sourceId: 'local', id: '1'), isTrue);
    expect(await repository.remove(sourceId: 'local', id: '1'), isFalse);
    expect((await repository.search('')).single.sourceId, 'other');
  });
  test('track JSON round trip preserves all fields', () {
    final original = Track(
      id: '1',
      sourceId: 'local',
      title: '晨光',
      artist: 'Artist',
      album: 'Album',
      duration: const Duration(milliseconds: 123456),
    );
    final restored = Track.fromJson(original.toJson());
    expect(restored.toJson(), original.toJson());
    expect(restored.key, original.key);
  });
  test('track rejects invalid metadata', () {
    expect(() => track(' '), throwsArgumentError);
    expect(() => track('1', source: ''), throwsArgumentError);
    expect(() => track('1', title: ''), throwsArgumentError);
    expect(
      () => Track(
        id: '1',
        sourceId: 'local',
        title: 'x',
        duration: const Duration(seconds: -1),
      ),
      throwsArgumentError,
    );
    expect(() => Track.fromJson({'id': 1}), throwsFormatException);
    expect(
      () => Track.fromJson({
        'id': '1',
        'sourceId': 'local',
        'title': 'x',
        'durationMs': -1,
      }),
      throwsFormatException,
    );
  });
}
