import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SessionStore {
  Future<String?> read();
  Future<void> write(String? value);
}

abstract interface class ProviderModeStore {
  Future<String?> readMode(String userId);
  Future<void> writeMode(String userId, String mode);
}

class SecureSessionStore implements SessionStore, ProviderModeStore {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const _key = 'infurnus_provider_session';
  @override
  Future<String?> readMode(String userId) =>
      _storage.read(key: 'infurnus_mode_$userId');
  @override
  Future<void> writeMode(String userId, String mode) =>
      _storage.write(key: 'infurnus_mode_$userId', value: mode);
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String? value) => value == null
      ? _storage.delete(key: _key)
      : _storage.write(key: _key, value: value);
}

class MemorySessionStore implements SessionStore, ProviderModeStore {
  final Map<String, String> modes = {};
  @override
  Future<String?> readMode(String userId) async => modes[userId];
  @override
  Future<void> writeMode(String userId, String mode) async {
    modes[userId] = mode;
  }

  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? next) async => value = next;
}
