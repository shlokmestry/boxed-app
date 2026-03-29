import 'package:appwrite/appwrite.dart';
import 'package:boxed_app/core/constants/appwrite_constants.dart';
import 'package:boxed_app/core/services/appwrite_service.dart';
import 'package:uuid/uuid.dart';

class CapsuleService {
  final _db = AppwriteService.databases;
  final _uuid = const Uuid();

  // ── Fetch capsules created by user ────────────────────────────────────────

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

  // ── Fetch capsules where user is a collaborator ───────────────────────────

  Future<List<Map<String, dynamic>>> fetchCollaboratorCapsules(
      String userId) async {
    try {
      final result = await _db.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.capsulesTable,
        queries: [
          Query.contains('collaboratorIds', userId),
          Query.orderDesc('\$createdAt'),
        ],
      );
      return result.documents.map((d) => d.data).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Fetch pending capsules created by user (waiting for invitees) ─────────

  Future<List<Map<String, dynamic>>> fetchPendingCapsules(
      String userId) async {
    try {
      final result = await _db.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.capsulesTable,
        queries: [
          Query.equal('creatorId', userId),
          Query.equal('status', 'pending'),
          Query.orderDesc('\$createdAt'),
        ],
      );
      return result.documents.map((d) => d.data).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Create capsule ────────────────────────────────────────────────────────
  // status: 'locked' for solo capsules, 'pending' when invites are being sent

  Future<Map<String, dynamic>> createCapsuleWithKey({
    required String userId,
    required String name,
    required String description,
    required DateTime unlockDate,
    required String encryptedCapsuleKey,
    String emoji = '📦',
    bool hasPendingInvites = false,
    int pendingInviteCount = 0,
  }) async {
    final capsuleId = _uuid.v4();
    final status = hasPendingInvites ? 'pending' : 'locked';

    final data = {
      'capsuleId': capsuleId,
      'name': name.trim(),
      'description': description.trim(),
      'creatorId': userId,
      'unlockDate': unlockDate.toUtc().toIso8601String(),
      'encryptedCapsuleKey': encryptedCapsuleKey,
      'emoji': emoji,
      'isRevealed': false,
      'collaboratorIds': <String>[],
      'collaboratorKeys': <String>[],
      'status': status,
      'pendingInviteCount': pendingInviteCount,
    };

    await _db.createDocument(
      databaseId: AppwriteConstants.databaseId,
      collectionId: AppwriteConstants.capsulesTable,
      documentId: capsuleId,
      data: data,
    );

    return data;
  }

  // ── Lock a pending capsule (all invitees responded) ───────────────────────

  Future<void> lockCapsule(String capsuleId) async {
    await _db.updateDocument(
      databaseId: AppwriteConstants.databaseId,
      collectionId: AppwriteConstants.capsulesTable,
      documentId: capsuleId,
      data: {
        'status': 'locked',
        'pendingInviteCount': 0,
      },
    );
  }

  // ── Decrement pending invite count ────────────────────────────────────────
  // Returns the new count. If 0, capsule should be locked.

  Future<int> decrementPendingInviteCount(String capsuleId) async {
    final doc = await _db.getDocument(
      databaseId: AppwriteConstants.databaseId,
      collectionId: AppwriteConstants.capsulesTable,
      documentId: capsuleId,
    );

    final current =
        (doc.data['pendingInviteCount'] as num?)?.toInt() ?? 0;
    final newCount = (current - 1).clamp(0, 999);

    await _db.updateDocument(
      databaseId: AppwriteConstants.databaseId,
      collectionId: AppwriteConstants.capsulesTable,
      documentId: capsuleId,
      data: {'pendingInviteCount': newCount},
    );

    return newCount;
  }

  // ── Add a collaborator's encrypted key to a capsule ───────────────────────

  Future<void> addCollaboratorKey({
    required String capsuleId,
    required String collaboratorUserId,
    required String encryptedKeyForCollaborator,
  }) async {
    final doc = await _db.getDocument(
      databaseId: AppwriteConstants.databaseId,
      collectionId: AppwriteConstants.capsulesTable,
      documentId: capsuleId,
    );

    final currentIds =
        List<String>.from(doc.data['collaboratorIds'] as List? ?? []);
    final currentKeys =
        List<String>.from(doc.data['collaboratorKeys'] as List? ?? []);

    if (!currentIds.contains(collaboratorUserId)) {
      currentIds.add(collaboratorUserId);
      currentKeys.add(encryptedKeyForCollaborator);

      await _db.updateDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.capsulesTable,
        documentId: capsuleId,
        data: {
          'collaboratorIds': currentIds,
          'collaboratorKeys': currentKeys,
        },
      );
    }
  }

  // ── Get encrypted capsule key for a specific collaborator ─────────────────

  String? getCollaboratorKey({
    required Map<String, dynamic> capsuleData,
    required String userId,
  }) {
    final ids =
        List<String>.from(capsuleData['collaboratorIds'] as List? ?? []);
    final keys =
        List<String>.from(capsuleData['collaboratorKeys'] as List? ?? []);
    final index = ids.indexOf(userId);
    if (index == -1 || index >= keys.length) return null;
    return keys[index];
  }

  // ── Fetch single capsule ──────────────────────────────────────────────────

  Future<Map<String, dynamic>?> fetchCapsuleById(String capsuleId) async {
    try {
      final doc = await _db.getDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.capsulesTable,
        documentId: capsuleId,
      );
      return doc.data;
    } catch (_) {
      return null;
    }
  }

  // ── Delete capsule + its memories ─────────────────────────────────────────

  Future<void> deleteCapsule(String capsuleId) async {
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

  // ── Mark revealed ─────────────────────────────────────────────────────────

  Future<void> markRevealed(String capsuleId) async {
    await _db.updateDocument(
      databaseId: AppwriteConstants.databaseId,
      collectionId: AppwriteConstants.capsulesTable,
      documentId: capsuleId,
      data: {'isRevealed': true},
    );
  }
}