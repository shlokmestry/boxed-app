import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class UserCryptoState {
  static SecretKey? _userMasterKey;
  static String? _currentUserId; // ✅ track who is logged in
  static const _storage = FlutterSecureStorage();
  static const _keyPrefix = 'boxed_master_key_';

  static SecretKey? get userMasterKeyOrNull => _userMasterKey;
  static String? get currentUserId => _currentUserId; // ✅ expose userId

  static SecretKey get userMasterKey {
    if (_userMasterKey == null) throw Exception('Master key not initialized');
    return _userMasterKey!;
  }

  static final Pbkdf2 _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 100000,
    bits: 256,
  );

  static Future<void> initializeForUser({
    required String userId,
    required String password,
    required String salt,
  }) async {
    final key = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: utf8.encode('$userId:$salt'),
    );
    _userMasterKey = key;
    _currentUserId = userId; // ✅ set on login
    final bytes = await key.extractBytes();
    await _storage.write(
      key: '$_keyPrefix$userId',
      value: base64Encode(bytes),
    );
  }

  static Future<void> loadFromStorage(String userId) async {
    _currentUserId = userId; // ✅ set on session restore
    if (_userMasterKey != null) return;
    final encoded = await _storage.read(key: '$_keyPrefix$userId');
    if (encoded == null) throw Exception('Master key not found. Please log in again.');
    _userMasterKey = SecretKey(base64Decode(encoded));
  }

  static Future<void> clearForUser(String userId) async {
    _userMasterKey = null;
    _currentUserId = null; // ✅ clear on logout
    await _storage.delete(key: '$_keyPrefix$userId');
  }

  static void clear() {
    _userMasterKey = null;
    _currentUserId = null;
  }
}