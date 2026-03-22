import 'package:appwrite/appwrite.dart';
import 'package:boxed_app/core/constants/appwrite_constants.dart';
import 'package:boxed_app/core/services/appwrite_service.dart';
import 'package:boxed_app/core/services/encryption_service.dart';
import 'package:boxed_app/core/state/user_crypto_state.dart';
import 'package:uuid/uuid.dart';

class CapsuleService {
  final _db = AppwriteService.databases;
  final _uuid = const Uuid();

  Future<List<Map<String, dynamic>>> fetchCapsules(String userId) async {
    final result = await _db.listDocuments(
      databaseId: AppwriteConstants.databaseId,
      collectionId: AppwriteConstants.capsulesTable,
      queries: [
        Query.equal('creatorId', userId),
        Query.orderDesc('\$createdAt'),
      ],
    );
    return result.documents.map((d) => d.data).toList();
  }

  Future<Map<String, dynamic>> createCapsule({
    required String userId,
    required String name,
    required String description,
    required DateTime unlockDate,
    String emoji = '📦',
  }) async {
    final capsuleId = _uuid.v4();
    final userMasterKey = UserCryptoState.userMasterKey;

    // Generate + encrypt capsule key
    final capsuleKey = await EncryptionService.generateCapsuleKey();
    final encryptedKey = await EncryptionService.encryptCapsuleKey(
      capsuleKey: capsuleKey,
      userMasterKey: userMasterKey,
    );

    final data = {
      'capsuleId': capsuleId,
      'name': name.trim(),
      'description': description.trim(),
      'creatorId': userId,
      'unlockDate': unlockDate.toUtc().toIso8601String(),
      'encryptedCapsuleKey': encryptedKey,
      'emoji': emoji,
      'isRevealed': false,
    };

    await _db.createDocument(
      databaseId: AppwriteConstants.databaseId,
      collectionId: AppwriteConstants.capsulesTable,
      documentId: capsuleId,
      data: data,
    );

    return data;
  }

  Future<void> deleteCapsule(String capsuleId) async {
    // Delete all memories first
    try {
      bool hasMore = true;
      while (hasMore) {
        final memories = await _db.listDocuments(
          databaseId: AppwriteConstants.databaseId,
          collectionId: AppwriteConstants.memoriesTable,
          queries: [Query.equal('capsuleId', capsuleId), Query.limit(100)],
        );
        if (memories.documents.isEmpty) {
          hasMore = false;
          break;
        }
        for (final doc in memories.documents) {
          await _db.deleteDocument(
            databaseId: AppwriteConstants.databaseId,
            collectionId: AppwriteConstants.memoriesTable,
            documentId: doc.$id,
          );
        }
        if (memories.documents.length < 100) hasMore = false;
      }
    } catch (_) {}

    await _db.deleteDocument(
      databaseId: AppwriteConstants.databaseId,
      collectionId: AppwriteConstants.capsulesTable,
      documentId: capsuleId,
    );
  }

  Future<void> markRevealed(String capsuleId) async {
    await _db.updateDocument(
      databaseId: AppwriteConstants.databaseId,
      collectionId: AppwriteConstants.capsulesTable,
      documentId: capsuleId,
      data: {'isRevealed': true},
    );
  }
}