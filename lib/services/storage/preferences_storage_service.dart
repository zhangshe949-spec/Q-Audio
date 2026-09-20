import 'package:shared_preferences/shared_preferences.dart';

import 'storage_service.dart';

/// Namespaced adapter. Never clears unrelated application preferences.
class PreferencesStorageService implements StorageService {
  PreferencesStorageService(this.preferences);
  final SharedPreferences preferences;
  static const prefix = 'q_audio.v1.';

  String _key(String key) {
    if (key.trim().isEmpty) throw ArgumentError.value(key, 'key');
    return '$prefix$key';
  }

  @override
  Future<String?> read(String key) async {
    final qualified = _key(key);
    try {
      await preferences.reload();
      return preferences.getString(qualified);
    } catch (_) {
      throw const StorageException('read');
    }
  }

  @override
  Future<void> write(String key, String value) async {
    final qualified = _key(key);
    try {
      if (!await preferences.setString(qualified, value)) {
        throw const StorageException('write');
      }
    } catch (_) {
      throw const StorageException('write');
    }
  }

  @override
  Future<void> remove(String key) async {
    final qualified = _key(key);
    try {
      if (!await preferences.remove(qualified)) {
        throw const StorageException('remove');
      }
    } catch (_) {
      throw const StorageException('remove');
    }
  }
}
