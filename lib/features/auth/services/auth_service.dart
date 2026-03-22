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
    await _account.createEmailPasswordSession(
      email: email,
      password: password,
    );
    final user = await _account.get();

    // Fetch salt from DB
    final docs = await _db.listDocuments(
      databaseId: AppwriteConstants.databaseId,
      collectionId: AppwriteConstants.usersTable,
      queries: [Query.equal('userId', user.$id)],
    );

    if (docs.documents.isEmpty) throw Exception('User profile not found.');
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

    await _account.createEmailPasswordSession(
      email: email,
      password: password,
    );

    // Create user document in DB
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
      final username = docs.documents.first.data['username'] as String? ?? '';
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
      queries: [Query.equal('username_lowercase', username.toLowerCase())],
    );
    return docs.documents.isEmpty;
  }

  Future<void> logout() async {
    await _account.deleteSession(sessionId: 'current');
  }
}