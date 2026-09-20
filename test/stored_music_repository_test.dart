import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:q_audio/domain/entities/track.dart';
import 'package:q_audio/data/repositories/stored_music_repository.dart';
import 'package:q_audio/services/storage/storage_service.dart';
import 'package:q_audio/services/storage/preferences_storage_service.dart';

class FailingStore implements StorageService {
  final Map<String, String> values = {};
  bool fail = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    if (fail) throw const StorageException('write');
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async => values.remove(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Track track(String id, {String title = 'Test'}) =>
      Track(id: id, sourceId: 'local', title: title);
  setUp(
    () => SharedPreferences.setMockInitialValues({'unrelated': 'preserve'}),
  );

  test(
    'saved catalog reloads through a new repository and storage adapter',
    () async {
      final first = StoredMusicRepository(
        PreferencesStorageService(await SharedPreferences.getInstance()),
      );
      await first.save(track('1', title: '晨光'));
      final second = StoredMusicRepository(
        PreferencesStorageService(await SharedPreferences.getInstance()),
      );
      expect((await second.findById(sourceId: 'local', id: '1'))?.title, '晨光');
      expect((await second.search('晨')).length, 1);
      expect(
        (await SharedPreferences.getInstance()).getString('unrelated'),
        'preserve',
      );
    },
  );
  test('delete persists and is idempotent', () async {
    final storage = PreferencesStorageService(
      await SharedPreferences.getInstance(),
    );
    final first = StoredMusicRepository(storage);
    await first.save(track('1'));
    expect(await first.remove(sourceId: 'local', id: '1'), isTrue);
    final second = StoredMusicRepository(storage);
    expect(await second.search(''), isEmpty);
    expect(await second.remove(sourceId: 'local', id: '1'), isFalse);
  });
  test('concurrent calls on shared repository retain every write', () async {
    final storage = FailingStore();
    final repository = StoredMusicRepository(storage);
    await Future.wait(List.generate(20, (i) => repository.save(track('$i'))));
    expect((await StoredMusicRepository(storage).search('')).length, 20);
  });
  test(
    'corrupt catalog is reported and preserved rather than overwritten',
    () async {
      final storage = FailingStore()
        ..values[StoredMusicRepository.storageKey] = '{bad';
      final repository = StoredMusicRepository(storage);
      await expectLater(repository.search(''), throwsFormatException);
      await expectLater(repository.save(track('1')), throwsFormatException);
      expect(storage.values[StoredMusicRepository.storageKey], '{bad');
    },
  );
  test('unsupported schema and invalid rows are rejected', () async {
    for (final raw in [
      '{"version":2,"tracks":[]}',
      '{"version":1,"tracks":[12]}',
      '{"version":1,"tracks":[{"id":"1"}]}',
    ]) {
      final storage = FailingStore()
        ..values[StoredMusicRepository.storageKey] = raw;
      await expectLater(
        StoredMusicRepository(storage).search(''),
        throwsFormatException,
      );
    }
  });
  test('failed write leaves previous data intact and queue recovers', () async {
    final storage = FailingStore();
    final repository = StoredMusicRepository(storage);
    await repository.save(track('1'));
    storage.fail = true;
    await expectLater(
      repository.save(track('2')),
      throwsA(isA<StorageException>()),
    );
    expect((await repository.search('')).map((t) => t.id), ['1']);
    storage.fail = false;
    await repository.save(track('2'));
    expect((await repository.search('')).length, 2);
  });
  test(
    'storage operations are namespaced and do not clear unrelated data',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final storage = PreferencesStorageService(preferences);
      await storage.write('theme', 'dark');
      expect(await storage.read('theme'), 'dark');
      await storage.remove('theme');
      expect(await storage.read('theme'), isNull);
      expect(preferences.getString('unrelated'), 'preserve');
      await expectLater(storage.write('', 'x'), throwsArgumentError);
    },
  );
  test(
    'bounded snapshot rejects growth beyond capacity without data loss',
    () async {
      final storage = FailingStore();
      final repository = StoredMusicRepository(storage);
      for (var i = 0; i < StoredMusicRepository.maxTracks; i++) {
        await repository.save(track('$i'));
      }
      await expectLater(repository.save(track('overflow')), throwsStateError);
      expect((await repository.search('', limit: 200)).length, 200);
      await repository.save(track('0', title: 'Updated'));
      expect(
        (await repository.findById(sourceId: 'local', id: '0'))?.title,
        'Updated',
      );
    },
  );
}
