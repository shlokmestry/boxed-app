import 'package:cryptography/cryptography.dart';

class CapsuleCryptoState {
  static final Map<String, SecretKey> _keys = {};

  static void setKey(String capsuleId, SecretKey key) {
    _keys[capsuleId] = key;
  }

  static SecretKey getKey(String capsuleId) {
    final key = _keys[capsuleId];
    if (key == null) throw Exception('Capsule key not loaded for $capsuleId');
    return key;
  }

  static SecretKey? getKeyOrNull(String capsuleId) => _keys[capsuleId];

  static void clearKey(String capsuleId) => _keys.remove(capsuleId);

  static void clearAll() => _keys.clear();
}