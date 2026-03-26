import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as appwrite_models;
import 'package:boxed_app/core/services/appwrite_service.dart';
import 'package:boxed_app/core/constants/appwrite_constants.dart';
import 'package:boxed_app/core/services/encryption_service.dart';
import 'package:uuid/uuid.dart';

class AuthResult {
  final appwrite_models.User user;
  final String salt;
  AuthResult({required this.user, required this.salt});
}

class AuthService {
  final _account = AppwriteService.account;
  final _db = AppwriteService.databases;
  final _uuid = const Uuid();

  Future<appwrite_models.User?> getCurrentUser() async {
    try {
      return await _account.get();
    } catch (_) {
      return null;
    }
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    // Clear any stale session first
    try {
      await _account.deleteSession(sessionId: 'current');
    } catch (_) {}

    await _account.createEmailPasswordSession(
      email: email,
      password: password,
    );

    final user = await _account.get();

    // Check if profile exists — if not, account was deleted
    final docs = await _db.listDocuments(
      databaseId: AppwriteConstants.databaseId,
      collectionId: AppwriteConstants.usersTable,
      queries: [Query.equal('userId', user.$id)],
    );

    if (docs.documents.isEmpty) {
      // Kill session and block login
      try {
        await _account.deleteSession(sessionId: 'current');
      } catch (_) {}
      throw Exception('account_deleted');
    }

    final salt = docs.documents.first.data['encryptionSalt'] as String;
    return AuthResult(user: user, salt: salt);
  }

  Future<AuthResult> signup({
    required String email,
    required String password,
  }) async {
    final userId = _uuid.v4();
    final salt = EncryptionService.generateSalt();

    final user = await _account.create(
      userId: userId,
      email: email,
      password: password,
    );

    // Clear any stale session before creating a new one
    try {
      await _account.deleteSession(sessionId: 'current');
    } catch (_) {}

    await _account.createEmailPasswordSession(
      email: email,
      password: password,
    );

    try {
      await _db.createDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.usersTable,
        documentId: userId,
        data: {
          'userId': userId,
          'username': '',
          'username_lowercase': '',
          'displayName': email.split('@')[0],
          'email': email.toLowerCase(),
          'bio': '',
          'photoUrl': '',
          'encryptionSalt': salt,
        },
      );
    } catch (e) {
      try {
        await _account.deleteSession(sessionId: 'current');
      } catch (_) {}
      rethrow;
    }

    return AuthResult(user: user, salt: salt);
  }

  Future<bool> hasUsername(String userId) async {
    try {
      final docs = await _db.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.usersTable,
        queries: [Query.equal('userId', userId)],
      );
      if (docs.documents.isEmpty) return false;
      final username =
          docs.documents.first.data['username'] as String? ?? '';
      return username.trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> setUsername({
    required String userId,
    required String username,
  }) async {
    final docs = await _db.listDocuments(
      databaseId: AppwriteConstants.databaseId,
      collectionId: AppwriteConstants.usersTable,
      queries: [Query.equal('userId', userId)],
    );
    if (docs.documents.isEmpty) throw Exception('User not found');
    final docId = docs.documents.first.$id;

    await _db.updateDocument(
      databaseId: AppwriteConstants.databaseId,
      collectionId: AppwriteConstants.usersTable,
      documentId: docId,
      data: {
        'username': username,
        'username_lowercase': username.toLowerCase(),
        'displayName': username,
      },
    );
  }

  Future<bool> isUsernameAvailable(String username) async {
    final docs = await _db.listDocuments(
      databaseId: AppwriteConstants.databaseId,
      collectionId: AppwriteConstants.usersTable,
      queries: [
        Query.equal('username_lowercase', username.toLowerCase()),
      ],
    );
    return docs.documents.isEmpty;
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final docs = await _db.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.usersTable,
        queries: [Query.equal('userId', userId)],
      );
      if (docs.documents.isEmpty) return null;
      return docs.documents.first.data;
    } catch (_) {
      return null;
    }
  }

  Future<void> updateProfile({
    required String userId,
    required String displayName,
    required String bio,
  }) async {
    final docs = await _db.listDocuments(
      databaseId: AppwriteConstants.databaseId,
      collectionId: AppwriteConstants.usersTable,
      queries: [Query.equal('userId', userId)],
    );
    if (docs.documents.isEmpty) throw Exception('User not found');
    final docId = docs.documents.first.$id;

    await _db.updateDocument(
      databaseId: AppwriteConstants.databaseId,
      collectionId: AppwriteConstants.usersTable,
      documentId: docId,
      data: {
        'displayName': displayName,
        'bio': bio,
      },
    );
  }

  Future<void> deleteAccount(String userId) async {
    // 1. Delete all capsules
    try {
      final capsules = await _db.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.capsulesTable,
        queries: [Query.equal('creatorId', userId)],
      );
      for (final doc in capsules.documents) {
        await _db.deleteDocument(
          databaseId: AppwriteConstants.databaseId,
          collectionId: AppwriteConstants.capsulesTable,
          documentId: doc.$id,
        );
      }
    } catch (_) {}

    // 2. Delete user profile doc
    try {
      final docs = await _db.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.usersTable,
        queries: [Query.equal('userId', userId)],
      );
      if (docs.documents.isNotEmpty) {
        await _db.deleteDocument(
          databaseId: AppwriteConstants.databaseId,
          collectionId: AppwriteConstants.usersTable,
          documentId: docs.documents.first.$id,
        );
      }
    } catch (_) {}

    // 3. Disable the Appwrite auth account so same email can't log in
    try {
      await _account.updateStatus();
    } catch (_) {}

    // 4. Kill the session
    try {
      await _account.deleteSession(sessionId: 'current');
    } catch (_) {}
  }

  Future<void> logout() async {
    await _account.deleteSession(sessionId: 'current');
  }
}