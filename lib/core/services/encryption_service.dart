import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class EncryptionService {
  static final AesGcm _aesGcm = AesGcm.with256bits();
  static final Random _rng = Random.secure();

  static String generateSalt() {
    final bytes = List<int>.generate(32, (_) => _rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Future<SecretKey> generateCapsuleKey() async {
    return _aesGcm.newSecretKey();
  }

  static Future<String> encryptCapsuleKey({
    required SecretKey capsuleKey,
    required SecretKey userMasterKey,
  }) async {
    final keyBytes = await capsuleKey.extractBytes();
    final secretBox = await _aesGcm.encrypt(keyBytes, secretKey: userMasterKey);
    return _encodeBox(secretBox);
  }

  static Future<SecretKey> decryptCapsuleKey({
    required String encryptedKey,
    required SecretKey userMasterKey,
  }) async {
    final box = _decodeBox(encryptedKey);
    final bytes = await _aesGcm.decrypt(box, secretKey: userMasterKey);
    return SecretKey(bytes);
  }

  static Future<String> encryptText({
    required String plainText,
    required SecretKey capsuleKey,
  }) async {
    final box = await _aesGcm.encrypt(
      utf8.encode(plainText),
      secretKey: capsuleKey,
    );
    return _encodeBox(box);
  }

  static Future<String> decryptText({
    required String encryptedText,
    required SecretKey capsuleKey,
  }) async {
    final box = _decodeBox(encryptedText);
    final bytes = await _aesGcm.decrypt(box, secretKey: capsuleKey);
    return utf8.decode(bytes);
  }

  static Future<Uint8List> encryptBytes({
    required Uint8List data,
    required SecretKey capsuleKey,
  }) async {
    final nonce = Uint8List.fromList(
      List<int>.generate(12, (_) => _rng.nextInt(256)),
    );
    final box = await _aesGcm.encrypt(
      data,
      secretKey: capsuleKey,
      nonce: nonce,
    );
    return Uint8List.fromList([...box.nonce, ...box.cipherText, ...box.mac.bytes]);
  }

  static Future<Uint8List> decryptBytes({
    required Uint8List data,
    required SecretKey capsuleKey,
  }) async {
    final nonce = data.sublist(0, 12);
    final mac = data.sublist(data.length - 16);
    final cipher = data.sublist(12, data.length - 16);
    final box = SecretBox(cipher, nonce: nonce, mac: Mac(mac));
    final result = await _aesGcm.decrypt(box, secretKey: capsuleKey);
    return Uint8List.fromList(result);
  }

  static String _encodeBox(SecretBox box) {
    final map = {
      'nonce': base64Encode(box.nonce),
      'cipherText': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    };
    return base64Encode(utf8.encode(jsonEncode(map)));
  }

  static SecretBox _decodeBox(String encoded) {
    final decoded = jsonDecode(utf8.decode(base64Decode(encoded))) as Map<String, dynamic>;
    return SecretBox(
      base64Decode(decoded['cipherText'] as String),
      nonce: base64Decode(decoded['nonce'] as String),
      mac: Mac(base64Decode(decoded['mac'] as String)),
    );
  }
}