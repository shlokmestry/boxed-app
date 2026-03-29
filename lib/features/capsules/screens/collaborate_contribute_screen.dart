import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:boxed_app/core/services/encryption_service.dart';
import 'package:boxed_app/core/state/user_crypto_state.dart';
import 'package:boxed_app/core/theme/app_theme.dart';
import 'package:boxed_app/features/auth/providers/auth_provider.dart';
import 'package:boxed_app/features/capsules/services/capsule_service.dart';
import 'package:boxed_app/features/capsules/services/invite_service.dart';
import 'package:boxed_app/features/memories/services/memory_service.dart';
import 'package:boxed_app/core/state/capsule_crypto_state.dart';

class CollaborateContributeScreen extends StatefulWidget {
  final Map<String, dynamic> invite; // the invite map with tempEncryptedKey
  final Map<String, dynamic> capsuleData; // basic capsule info

  const CollaborateContributeScreen({
    super.key,
    required this.invite,
    required this.capsuleData,
  });

  @override
  State<CollaborateContributeScreen> createState() =>
      _CollaborateContributeScreenState();
}

class _CollaborateContributeScreenState
    extends State<CollaborateContributeScreen> {
  final _messageController = TextEditingController();
  final _picker = ImagePicker();
  final _capsuleService = CapsuleService();
  final _inviteService = InviteService();
  final _memoryService = MemoryService();

  final List<File> _selectedImages = [];
  bool _isSubmitting = false;

  String get _capsuleId => widget.capsuleData['capsuleId'] as String;
  String get _inviteId => widget.invite['inviteId'] as String;
  String get _capsuleName =>
      (widget.capsuleData['name'] ?? 'Capsule').toString();
  String get _capsuleEmoji =>
      (widget.capsuleData['emoji'] ?? '📦').toString();
  String get _fromUsername =>
      (widget.invite['fromUsername'] ?? 'Someone').toString();

  @override
  void dispose() {
    _messageController.dispose();
    CapsuleCryptoState.clearKey(_capsuleId);
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 80);
    if (picked.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(picked.map((x) => File(x.path)));
      });
    }
  }

  // ── Accept and optionally contribute ────────────────────────────────────

  Future<void> _submit({bool skip = false}) async {
    setState(() => _isSubmitting = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final auth = context.read<AuthProvider>();
      final userId = auth.user!.$id;
      final userMasterKey = UserCryptoState.userMasterKey;
      final tempEncryptedKey =
          widget.invite['tempEncryptedKey'] as String? ?? '';

      // 1. Decrypt capsule key using inviteId as shared secret
      final capsuleKey = await InviteService.decryptCapsuleKeyFromInvite(
        tempEncryptedKey: tempEncryptedKey,
        inviteId: _inviteId,
      );

      // 2. Re-encrypt with collaborator's own master key
      final reEncryptedKey = await EncryptionService.encryptCapsuleKey(
        capsuleKey: capsuleKey,
        userMasterKey: userMasterKey,
      );

      // 3. Store collaborator key in capsule
      await _capsuleService.addCollaboratorKey(
        capsuleId: _capsuleId,
        collaboratorUserId: userId,
        encryptedKeyForCollaborator: reEncryptedKey,
      );

      // 4. Add memories if not skipping
      if (!skip) {
        CapsuleCryptoState.setKey(_capsuleId, capsuleKey);

        final message = _messageController.text.trim();
        if (message.isNotEmpty) {
          await _memoryService.addTextMemory(
            capsuleId: _capsuleId,
            userId: userId,
            text: message,
            capsuleKey: capsuleKey,
          );
        }

        for (final image in _selectedImages) {
          await _memoryService.addPhotoMemory(
            capsuleId: _capsuleId,
            userId: userId,
            imageFile: image,
            capsuleKey: capsuleKey,
          );
        }
      }

      // 5. Mark invite accepted with respondedAt
      await _inviteService.acceptInvite(_inviteId);

      // 6. Decrement pending count — if 0, lock the capsule
      final remaining =
          await _capsuleService.decrementPendingInviteCount(_capsuleId);
      if (remaining == 0) {
        await _capsuleService.lockCapsule(_capsuleId);
      }

      HapticFeedback.mediumImpact();

      messenger.showSnackBar(SnackBar(
        content: Text(skip
            ? 'You\'re in! The capsule will seal once everyone responds.'
            : 'Memories added! The capsule will seal once everyone responds.'),
        backgroundColor: AppTheme.cardDark2,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ));

      navigator.pop(true); // true = accepted
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed: $e'),
          backgroundColor: AppTheme.cardDark2,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('Add to Capsule',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Capsule info header ─────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111111),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Row(
                      children: [
                        Text(_capsuleEmoji,
                            style: const TextStyle(fontSize: 40)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_capsuleName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  )),
                              const SizedBox(height: 4),
                              Text(
                                '@$_fromUsername invited you',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.45),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  Text(
                    'Add your memories',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Optional — you can skip and just be part of the capsule.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Note ───────────────────────────────────────
                  Text('Write a note (optional)',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark2,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: TextField(
                      controller: _messageController,
                      maxLines: 4,
                      minLines: 3,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15, height: 1.5),
                      decoration: const InputDecoration(
                        hintText: 'A note for this capsule...',
                        hintStyle: TextStyle(color: AppTheme.mutedText2),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Photos ─────────────────────────────────────
                  Row(
                    children: [
                      Text('Photos (optional)',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                      const Spacer(),
                      GestureDetector(
                        onTap: _pickImages,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.cardDark2,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.add_photo_alternate_outlined,
                                  color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text('Add',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_selectedImages.isEmpty)
                    GestureDetector(
                      onTap: _pickImages,
                      child: Container(
                        height: 90,
                        decoration: BoxDecoration(
                          color: AppTheme.cardDark2,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                color: Colors.white.withOpacity(0.2),
                                size: 28),
                            const SizedBox(height: 6),
                            Text('Tap to add photos',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.25),
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _selectedImages.length,
                      itemBuilder: (_, i) => Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(_selectedImages[i],
                                fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 4, right: 4,
                            child: GestureDetector(
                              onTap: () => setState(
                                  () => _selectedImages.removeAt(i)),
                              child: Container(
                                width: 22, height: 22,
                                decoration: const BoxDecoration(
                                    color: Colors.black,
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 16),
                  Text(
                    '🔒 Your memories will be encrypted and sealed with the capsule.',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom buttons ─────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(
                24, 0, 24, 20 + MediaQuery.of(context).padding.bottom),
            child: Column(
              children: [
                // Add memories button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : () => _submit(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black))
                        : const Text('Add & Join',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 10),
                // Skip button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed:
                        _isSubmitting ? null : () => _submit(skip: true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side:
                          BorderSide(color: Colors.white.withOpacity(0.2)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Just join, no contribution',
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.6))),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}