import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import 'package:boxed_app/core/constants/appwrite_constants.dart';
import 'package:boxed_app/core/services/appwrite_service.dart';
import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

class InviteService {
  final _db = AppwriteService.databases;
  final _uuid = const Uuid();
  static final _aesGcm = AesGcm.with256bits();

  // ── Derive a SecretKey from a plain string (inviteId) ─────────────────────

  static Future<SecretKey> _keyFromString(String source) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 10000,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(source)),
      nonce: utf8.encode('boxed-invite-nonce'),
    );
  }

  // ── Encrypt capsule key with inviteId as shared secret ───────────────────

  static Future<String> encryptCapsuleKeyForInvite({
    required SecretKey capsuleKey,
    required String inviteId,
  }) async {
    final derivedKey = await _keyFromString(inviteId);
    final capsuleKeyBytes = await capsuleKey.extractBytes();
    final secretBox =
        await _aesGcm.encrypt(capsuleKeyBytes, secretKey: derivedKey);

    final map = {
      'nonce': base64Encode(secretBox.nonce),
      'cipherText': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes),
    };
    return base64Encode(utf8.encode(jsonEncode(map)));
  }

  // ── Decrypt capsule key from invite using inviteId ────────────────────────

  static Future<SecretKey> decryptCapsuleKeyFromInvite({
    required String tempEncryptedKey,
    required String inviteId,
  }) async {
    final derivedKey = await _keyFromString(inviteId);
    final decoded = jsonDecode(
            utf8.decode(base64Decode(tempEncryptedKey))) as Map<String, dynamic>;
    final secretBox = SecretBox(
      base64Decode(decoded['cipherText'] as String),
      nonce: base64Decode(decoded['nonce'] as String),
      mac: Mac(base64Decode(decoded['mac'] as String)),
    );
    final bytes = await _aesGcm.decrypt(secretBox, secretKey: derivedKey);
    return SecretKey(bytes);
  }

  // ── Search user by username ───────────────────────────────────────────────

  Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    try {
      final docs = await _db.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.usersTable,
        queries: [
          Query.equal('username_lowercase', username.toLowerCase()),
        ],
      );
      if (docs.documents.isEmpty) return null;
      return docs.documents.first.data;
    } catch (_) {
      return null;
    }
  }

  // ── Create invite with tempEncryptedKey already set ──────────────────────
  // Flow: generate inviteId locally → encrypt capsule key with it →
  // create doc with that inviteId and the encrypted key in one shot.

  Future<String> createInvite({
    required String capsuleId,
    required String fromUserId,
    required String toUserId,
    required SecretKey capsuleKey,
  }) async {
    final inviteId = _uuid.v4();

    // Encrypt capsule key using inviteId as shared secret
    final tempEncryptedKey = await encryptCapsuleKeyForInvite(
      capsuleKey: capsuleKey,
      inviteId: inviteId,
    );

    await _db.createDocument(
      databaseId: AppwriteConstants.databaseId,
      collectionId: AppwriteConstants.invitesTable,
      documentId: inviteId,
      data: {
        'inviteId': inviteId,
        'capsuleId': capsuleId,
        'fromUserId': fromUserId,
        'toUserId': toUserId,
        'status': 'pending',
        'tempEncryptedKey': tempEncryptedKey,
      },
    );

    return inviteId;
  }

  // ── Fetch pending invites for a user ──────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchPendingInvites(String userId) async {
    try {
      final docs = await _db.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.invitesTable,
        queries: [
          Query.equal('toUserId', userId),
          Query.equal('status', 'pending'),
          Query.orderDesc('\$createdAt'),
        ],
      );
      return docs.documents.map((d) => d.data).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Accept invite ─────────────────────────────────────────────────────────

  Future<void> acceptInvite(String inviteId) async {
    try {
      final docs = await _db.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.invitesTable,
        queries: [Query.equal('inviteId', inviteId)],
      );
      if (docs.documents.isEmpty) return;
      await _db.updateDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.invitesTable,
        documentId: docs.documents.first.$id,
        data: {'status': 'accepted'},
      );
    } catch (_) {}
  }

  // ── Decline invite ────────────────────────────────────────────────────────

  Future<void> declineInvite(String inviteId) async {
    try {
      final docs = await _db.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.invitesTable,
        queries: [Query.equal('inviteId', inviteId)],
      );
      if (docs.documents.isEmpty) return;
      await _db.updateDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.invitesTable,
        documentId: docs.documents.first.$id,
        data: {'status': 'declined'},
      );
    } catch (_) {}
  }

  // ── Check duplicate ───────────────────────────────────────────────────────

  Future<bool> inviteExists({
    required String capsuleId,
    required String toUserId,
  }) async {
    try {
      final docs = await _db.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.invitesTable,
        queries: [
          Query.equal('capsuleId', capsuleId),
          Query.equal('toUserId', toUserId),
          Query.equal('status', 'pending'),
        ],
      );
      return docs.documents.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}