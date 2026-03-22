import 'dart:io';
import 'dart:typed_data';
import 'package:appwrite/appwrite.dart';
import 'package:boxed_app/core/constants/appwrite_constants.dart';
import 'package:boxed_app/core/services/appwrite_service.dart';
import 'package:boxed_app/core/services/encryption_service.dart';
import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

class MemoryService {
  final _db = AppwriteService.databases;
  final _storage = AppwriteService.storage;
  final _uuid = const Uuid();

  Future<List<Map<String, dynamic>>> fetchMemories(String capsuleId) async {
    final result = await _db.listDocuments(
      databaseId: AppwriteConstants.databaseId,
      collectionId: AppwriteConstants.memoriesTable,
      queries: [
        Query.equal('capsuleId', capsuleId),
        Query.orderAsc('\$createdAt'),
      ],
    );
    return result.documents.map((d) => d.data).toList();
  }

  Future<void> addTextMemory({
    required String capsuleId,
    required String userId,
    required String text,
    required SecretKey capsuleKey,
  }) async {
    final memoryId = _uuid.v4();
    final encrypted = await EncryptionService.encryptText(
      plainText: text,
      capsuleKey: capsuleKey,
    );

    await _db.createDocument(
      databaseId: AppwriteConstants.databaseId,
      collectionId: AppwriteConstants.memoriesTable,
      documentId: memoryId,
      data: {
        'memoryId': memoryId,
        'capsuleId': capsuleId,
        'creatorId': userId,
        'type': 'text',
        'content': encrypted,
        'fileId': '',
        'isEncrypted': true,
      },
    );
  }

  Future<void> addPhotoMemory({
    required String capsuleId,
    required String userId,
    required File imageFile,
    required SecretKey capsuleKey,
  }) async {
    final memoryId = _uuid.v4();

    // Read + encrypt image bytes
    final bytes = await imageFile.readAsBytes();
    final encryptedBytes = await EncryptionService.encryptBytes(
      data: bytes,
      capsuleKey: capsuleKey,
    );

    // Upload encrypted file to Appwrite Storage
    await _storage.createFile(
      bucketId: AppwriteConstants.memoriesBucket,
      fileId: memoryId,
      file: InputFile.fromBytes(
        bytes: encryptedBytes,
        filename: '$memoryId.enc',
      ),
    );

    // Save memory doc
    await _db.createDocument(
      databaseId: AppwriteConstants.databaseId,
      collectionId: AppwriteConstants.memoriesTable,
      documentId: memoryId,
      data: {
        'memoryId': memoryId,
        'capsuleId': capsuleId,
        'creatorId': userId,
        'type': 'photo',
        'content': '',
        'fileId': memoryId,
        'isEncrypted': true,
      },
    );
  }

  Future<String> decryptTextMemory({
    required String encryptedContent,
    required SecretKey capsuleKey,
  }) async {
    return EncryptionService.decryptText(
      encryptedText: encryptedContent,
      capsuleKey: capsuleKey,
    );
  }

  Future<Uint8List> decryptPhotoMemory({
    required String fileId,
    required SecretKey capsuleKey,
  }) async {
    final bytes = await _storage.getFileDownload(
      bucketId: AppwriteConstants.memoriesBucket,
      fileId: fileId,
    );
    return EncryptionService.decryptBytes(
      data: Uint8List.fromList(bytes),
      capsuleKey: capsuleKey,
    );
  }

  Future<void> deleteMemory({
    required String memoryId,
    required String? fileId,
  }) async {
    await _db.deleteDocument(
      databaseId: AppwriteConstants.databaseId,
      collectionId: AppwriteConstants.memoriesTable,
      documentId: memoryId,
    );
    if (fileId != null && fileId.isNotEmpty) {
      try {
        await _storage.deleteFile(
          bucketId: AppwriteConstants.memoriesBucket,
          fileId: fileId,
        );
      } catch (_) {}
    }
  }
}