/// Small application settings only. Not a music database or secret vault.
abstract interface class StorageService {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
}

class StorageException implements Exception {
  const StorageException(this.operation);
  final String operation;
  @override
  String toString() => 'StorageException: $operation failed';
}
