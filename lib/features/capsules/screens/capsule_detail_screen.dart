import 'dart:async';
import 'dart:typed_data';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:boxed_app/core/router/app_router.dart';
import 'package:boxed_app/core/services/encryption_service.dart';
import 'package:boxed_app/core/state/capsule_crypto_state.dart';
import 'package:boxed_app/core/state/user_crypto_state.dart';
import 'package:boxed_app/core/theme/app_theme.dart';
import 'package:boxed_app/features/auth/services/auth_service.dart';
import 'package:boxed_app/features/capsules/providers/capsule_provider.dart';
import 'package:boxed_app/features/capsules/services/capsule_service.dart';
import 'package:boxed_app/features/capsules/services/invite_service.dart';
import 'package:boxed_app/features/memories/services/memory_service.dart';

class CapsuleDetailScreen extends StatefulWidget {
  final String capsuleId;
  const CapsuleDetailScreen({super.key, required this.capsuleId});

  @override
  State<CapsuleDetailScreen> createState() => _CapsuleDetailScreenState();
}

enum _Stage { loading, error, pending, locked, unlockReady, revealed }

class _CapsuleDetailScreenState extends State<CapsuleDetailScreen> {
  _Stage _stage = _Stage.loading;
  String? _error;

  Map<String, dynamic>? _capsuleData;
  DateTime? _unlockDate;
  DateTime? _createdAt;
  Duration _remaining = Duration.zero;
  Timer? _timer;

  List<_Memory> _memories = [];
  bool _memoriesLoading = false;

  List<String> _collaboratorUsernames = [];
  List<Map<String, dynamic>> _inviteStatuses = [];

  late ConfettiController _confettiController;
  final _capsuleService = CapsuleService();
  final _memoryService = MemoryService();
  final _inviteService = InviteService();

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _confettiController.dispose();
    CapsuleCryptoState.clearKey(widget.capsuleId);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _stage = _Stage.loading);
    try {
      final provider = context.read<CapsuleProvider>();
      Map<String, dynamic>? data;

      try {
        data = provider.capsules
            .firstWhere((c) => c['capsuleId'] == widget.capsuleId);
      } catch (_) {
        data = null;
      }

      data ??= await _capsuleService.fetchCapsuleById(widget.capsuleId);

      if (data == null) {
        setState(() {
          _stage = _Stage.error;
          _error = 'Capsule not found.';
        });
        return;
      }

      _capsuleData = data;

      final masterKey = UserCryptoState.userMasterKey;
      final currentUserId = UserCryptoState.currentUserId;
      final creatorId = data['creatorId'] as String? ?? '';
      final collaboratorIds =
          List<String>.from(data['collaboratorIds'] as List? ?? []);
      final collaboratorKeys =
          List<String>.from(data['collaboratorKeys'] as List? ?? []);
      final status = data['status'] as String? ?? 'locked';
      final isCreator = currentUserId == creatorId;

      if (status == 'pending' && isCreator) {
        await _loadInviteStatuses();
        setState(() => _stage = _Stage.pending);
        return;
      }

      final isCollaborator = currentUserId != null &&
          currentUserId != creatorId &&
          collaboratorIds.contains(currentUserId);

      String encryptedKeyToUse;
      if (isCollaborator) {
        final colIndex = collaboratorIds.indexOf(currentUserId!);
        if (colIndex < 0 || colIndex >= collaboratorKeys.length) {
          setState(() {
            _stage = _Stage.error;
            _error = 'Your access key is not ready yet.';
          });
          return;
        }
        encryptedKeyToUse = collaboratorKeys[colIndex];
      } else {
        encryptedKeyToUse = data['encryptedCapsuleKey'] as String;
      }

      final capsuleKey = await EncryptionService.decryptCapsuleKey(
        encryptedKey: encryptedKeyToUse,
        userMasterKey: masterKey,
      );
      CapsuleCryptoState.setKey(widget.capsuleId, capsuleKey);

      final authService = AuthService();
      final List<String> usernames = [];
      if (isCollaborator) {
        final profile = await authService.getUserProfile(creatorId);
        final username = profile?['username'] as String? ?? '';
        if (username.isNotEmpty) usernames.add('@$username');
      } else {
        for (final id in collaboratorIds) {
          if (id == currentUserId) continue;
          final profile = await authService.getUserProfile(id);
          final username = profile?['username'] as String? ?? '';
          if (username.isNotEmpty) usernames.add('@$username');
        }
      }
      _collaboratorUsernames = usernames;

      final unlockDate =
          DateTime.parse(data['unlockDate'] as String).toLocal();
      _unlockDate = unlockDate;

      // ✅ Fix: Appwrite stores creation time as '$createdAt' in raw data map
      final rawCreatedAt = data['\$createdAt'] ?? data['createdAt'];
      if (rawCreatedAt != null) {
        _createdAt =
            DateTime.tryParse(rawCreatedAt.toString())?.toLocal();
      }

      final now = DateTime.now();
      if (now.isBefore(unlockDate)) {
        _remaining = unlockDate.difference(now);
        _startTimer();
        setState(() => _stage = _Stage.locked);
      } else {
        final isRevealed = data['isRevealed'] == true;
        if (isRevealed) {
          setState(() => _stage = _Stage.revealed);
          _loadMemories();
        } else {
          setState(() => _stage = _Stage.unlockReady);
        }
      }
    } catch (e) {
      setState(() {
        _stage = _Stage.error;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadInviteStatuses() async {
    try {
      final invites =
          await _inviteService.fetchCapsuleInvites(widget.capsuleId);
      final authService = AuthService();
      final List<Map<String, dynamic>> statuses = [];

      for (final invite in invites) {
        final toUserId = invite['toUserId'] as String? ?? '';
        final profile = await authService.getUserProfile(toUserId);
        final username = profile?['username'] as String? ?? toUserId;
        statuses.add({
          'username': username,
          'status': invite['status'] as String? ?? 'pending',
        });
      }

      if (mounted) setState(() => _inviteStatuses = statuses);
    } catch (_) {}
  }

  String _buildMembersLabel() {
    final currentUserId = UserCryptoState.currentUserId;
    final creatorId = _capsuleData?['creatorId'] as String? ?? '';
    final isCreator = currentUserId == creatorId;

    if (_collaboratorUsernames.isEmpty) {
      return isCreator ? 'Just you' : 'Shared capsule';
    }

    final others = _collaboratorUsernames.join(', ');
    return isCreator ? 'You + $others' : 'With $others';
  }

  Future<void> _loadMemories() async {
    setState(() => _memoriesLoading = true);
    try {
      final capsuleKey = CapsuleCryptoState.getKey(widget.capsuleId);
      final raw = await _memoryService.fetchMemories(widget.capsuleId);
      final List<_Memory> result = [];

      for (final m in raw) {
        final type = m['type'] as String;
        if (type == 'text') {
          try {
            final text = await _memoryService.decryptTextMemory(
              encryptedContent: m['content'] as String,
              capsuleKey: capsuleKey,
            );
            result.add(_Memory.text(text));
          } catch (_) {
            result.add(_Memory.text('[Unable to decrypt]'));
          }
        } else if (type == 'photo') {
          try {
            final bytes = await _memoryService.decryptPhotoMemory(
              fileId: m['fileId'] as String,
              capsuleKey: capsuleKey,
            );
            result.add(_Memory.photo(bytes));
          } catch (_) {
            result.add(_Memory.text('[Unable to decrypt photo]'));
          }
        }
      }

      if (mounted) setState(() => _memories = result);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _memoriesLoading = false);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_unlockDate == null) return;
      final now = DateTime.now();
      if (now.isAfter(_unlockDate!)) {
        _timer?.cancel();
        if (mounted) {
          setState(() {
            _stage = _Stage.unlockReady;
            _remaining = Duration.zero;
          });
        }
      } else {
        if (mounted) {
          setState(() => _remaining = _unlockDate!.difference(now));
        }
      }
    });
  }

  Future<void> _reveal() async {
    HapticFeedback.heavyImpact();
    await _capsuleService.markRevealed(widget.capsuleId);
    _confettiController.play();
    if (mounted) {
      setState(() => _stage = _Stage.revealed);
      _loadMemories();
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete capsule?',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          'This will permanently delete the capsule and all its memories.',
          style: TextStyle(color: Colors.white.withOpacity(0.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<CapsuleProvider>().deleteCapsule(widget.capsuleId);
    if (mounted) Navigator.pop(context);
  }

  void _share() {
    final title = (_capsuleData?['name'] ?? 'My Capsule').toString();
    final unlockStr = _unlockDate != null
        ? DateFormat('MMM d, yyyy').format(_unlockDate!)
        : '';
    final box = context.findRenderObject() as RenderBox?;
    Share.share(
      '📦 I just opened my Boxed capsule — "$title" — sealed on $unlockStr. Check out Boxed!',
      sharePositionOrigin: box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : Rect.zero,
    );
  }

  void _openPhoto(Uint8List bytes) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.memory(bytes),
            ),
          ),
        ),
      ),
    );
  }

  double _lockProgress() {
    if (_createdAt == null || _unlockDate == null) return 0.0;
    final total = _unlockDate!.difference(_createdAt!).inSeconds;
    if (total <= 0) return 1.0;
    final elapsed = DateTime.now().difference(_createdAt!).inSeconds;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  String _timeWaited() {
    if (_createdAt == null || _unlockDate == null) return '';
    final days = _unlockDate!.difference(_createdAt!).inDays;
    if (days < 1) return 'Less than a day';
    if (days == 1) return '1 day';
    if (days < 30) return '$days days';
    if (days < 365) {
      final months = (days / 30).round();
      return '$months month${months > 1 ? 's' : ''}';
    }
    final years = (days / 365 * 10).round() / 10;
    return '$years year${years != 1.0 ? 's' : ''}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  int get _photoCount =>
      _memories.where((m) => m.type == _MemoryType.photo).length;
  int get _textCount =>
      _memories.where((m) => m.type == _MemoryType.text).length;

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _Stage.loading:
        return const Scaffold(
          backgroundColor: Colors.black,
          body: Center(
              child: CircularProgressIndicator(color: Colors.white)),
        );
      case _Stage.error:
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error ?? 'Something went wrong',
                      style: const TextStyle(color: AppTheme.red),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: _load,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        );
      case _Stage.pending:
        return _buildPending();
      case _Stage.locked:
        return _buildLocked();
      case _Stage.unlockReady:
        return _buildUnlockReady();
      case _Stage.revealed:
        return _buildRevealed();
    }
  }

  // ── Pending ───────────────────────────────────────────────────────────────

  Widget _buildPending() {
    final title = (_capsuleData?['name'] ?? 'Your Capsule').toString();
    final emoji = (_capsuleData?['emoji'] ?? '📦').toString();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: _delete,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _load,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(),
              Text(emoji, style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(
                'Waiting for everyone to respond before sealing.',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5), height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (_inviteStatuses.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Collaborators',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.8,
                          )),
                      const SizedBox(height: 12),
                      ..._inviteStatuses.map((s) {
                        final status = s['status'] as String;
                        final username = s['username'] as String;
                        final icon = status == 'accepted'
                            ? '✅'
                            : status == 'declined'
                                ? '❌'
                                : '⏳';
                        final color = status == 'accepted'
                            ? AppTheme.green
                            : status == 'declined'
                                ? AppTheme.red
                                : Colors.orange;
                        final label = status == 'accepted'
                            ? 'Joined'
                            : status == 'declined'
                                ? 'Declined'
                                : 'Pending';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Text(icon,
                                  style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text('@$username',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(label,
                                    style: TextStyle(
                                      color: color,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    )),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                '⏰ Capsule auto-deletes if no response in 24 hours.',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.2), fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Locked ────────────────────────────────────────────────────────────────

  Widget _buildLocked() {
    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;
    final title = (_capsuleData?['name'] ?? 'Your Capsule').toString();
    final emoji = (_capsuleData?['emoji'] ?? '📦').toString();
    final unlockStr = _unlockDate != null
        ? DateFormat('MMM d, yyyy • h:mm a').format(_unlockDate!)
        : '';
    final progress = _lockProgress();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: _delete,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(),
              Text(emoji, style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(
                'Your memories are sealed inside. Almost time.',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.6), height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _timeTile(_pad(days), 'Days'),
                  const SizedBox(width: 10),
                  _timeTile(_pad(hours), 'Hours'),
                  const SizedBox(width: 10),
                  _timeTile(_pad(minutes), 'Min'),
                  const SizedBox(width: 10),
                  _timeTile(_pad(seconds), 'Sec'),
                ],
              ),
              const SizedBox(height: 28),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Wait progress',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 12)),
                      Text(
                          '${(progress * 100).toStringAsFixed(0)}% done',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.white.withOpacity(0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.blue.withOpacity(0.8)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (unlockStr.isNotEmpty)
                Text('Unlocks on $unlockStr',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 13),
                    textAlign: TextAlign.center),
              const SizedBox(height: 12),

              // Members pill
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('👥', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 6),
                    Text(
                      _buildMembersLabel(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Text('🔒 All memories are end-to-end encrypted.',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.2), fontSize: 12),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),

              // ✅ Add memory button — available to ALL members
              // (creator + collaborators) while capsule is locked
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final added = await Navigator.pushNamed(
                      context,
                      AppRouter.addMemory,
                      arguments: widget.capsuleId,
                    );
                    if (added == true && mounted) _load();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                        color: Colors.white.withOpacity(0.2)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(Icons.add_photo_alternate_outlined,
                      size: 18,
                      color: Colors.white.withOpacity(0.6)),
                  label: Text('Add a memory',
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.6))),
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeTile(String value, String label) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ── Unlock Ready ──────────────────────────────────────────────────────────

  Widget _buildUnlockReady() {
    final title = (_capsuleData?['name'] ?? 'Your Capsule').toString();
    final emoji = (_capsuleData?['emoji'] ?? '📦').toString();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
          child: Column(
            children: [
              const Spacer(),
              Text(emoji, style: const TextStyle(fontSize: 72)),
              const SizedBox(height: 22),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(
                'Your memories are ready to be revealed.',
                style:
                    TextStyle(color: Colors.white.withOpacity(0.7)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _reveal,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Reveal Memories',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Revealed ──────────────────────────────────────────────────────────────

  Widget _buildRevealed() {
    final title = (_capsuleData?['name'] ?? 'Your Capsule').toString();
    final emoji = (_capsuleData?['emoji'] ?? '📦').toString();
    final desc = (_capsuleData?['description'] ?? '').toString();

    final sealedStr = _createdAt != null
        ? DateFormat('MMM d, yyyy').format(_createdAt!)
        : '';
    final openedStr = _unlockDate != null
        ? DateFormat('MMM d, yyyy').format(_unlockDate!)
        : '';
    final timeWaited = _timeWaited();

    String memorySummary = '';
    if (!_memoriesLoading && _memories.isNotEmpty) {
      final parts = <String>[];
      if (_photoCount > 0)
        parts.add('$_photoCount photo${_photoCount > 1 ? 's' : ''}');
      if (_textCount > 0)
        parts.add('$_textCount note${_textCount > 1 ? 's' : ''}');
      memorySummary = parts.join(' · ');
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: _share,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1a1a2e), Colors.black],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 36),
                  child: Column(
                    children: [
                      Text(emoji,
                          style: const TextStyle(fontSize: 80)),
                      const SizedBox(height: 20),
                      Text(title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      if (sealedStr.isNotEmpty)
                        Text('Created on $sealedStr',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      if (openedStr.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppTheme.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color:
                                    AppTheme.green.withOpacity(0.3)),
                          ),
                          child: Text('🔓  Opened on $openedStr',
                              style: TextStyle(
                                color: AppTheme.green.withOpacity(0.9),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              )),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (timeWaited.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111111),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color:
                                    Colors.white.withOpacity(0.06)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color:
                                      Colors.white.withOpacity(0.06),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Text('⏳',
                                      style:
                                          TextStyle(fontSize: 22)),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text('You waited $timeWaited',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      )),
                                  const SizedBox(height: 3),
                                  Text('Worth every second.',
                                      style: TextStyle(
                                        color: Colors.white
                                            .withOpacity(0.4),
                                        fontSize: 12,
                                      )),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (desc.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111111),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color:
                                    Colors.white.withOpacity(0.06)),
                          ),
                          child: Text(desc,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 15,
                                height: 1.7,
                              )),
                        ),
                      ],
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                              child: Divider(
                                  color:
                                      Colors.white.withOpacity(0.08),
                                  height: 1)),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14),
                            child: Text('your memories',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.3),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 1.2,
                                )),
                          ),
                          Expanded(
                              child: Divider(
                                  color:
                                      Colors.white.withOpacity(0.08),
                                  height: 1)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (memorySummary.isNotEmpty)
                        Center(
                          child: Text(memorySummary,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                                fontSize: 12,
                              )),
                        ),
                      const SizedBox(height: 20),
                      if (_memoriesLoading && _memories.isEmpty)
                        Column(
                          children: List.generate(
                              2, (i) => _SkeletonCard(index: i)),
                        )
                      else if (_memories.isEmpty && !_memoriesLoading)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 32),
                            child: Column(
                              children: [
                                const Text('📭',
                                    style: TextStyle(fontSize: 36)),
                                const SizedBox(height: 12),
                                Text(
                                  'No memories were added\nto this capsule.',
                                  style: TextStyle(
                                    color:
                                        Colors.white.withOpacity(0.35),
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Column(
                          children: _memories
                              .asMap()
                              .entries
                              .map((entry) {
                            final i = entry.key;
                            final memory = entry.value;
                            return _FadeInMemory(
                              index: i,
                              child: memory.type == _MemoryType.text
                                  ? _TextMemoryCard(
                                      text: memory.text!)
                                  : _PhotoMemoryCard(
                                      bytes: memory.bytes!,
                                      onTap: () =>
                                          _openPhoto(memory.bytes!),
                                    ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 24),
                      Center(
                        child: Text('🔒  End-to-end encrypted',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.15),
                              fontSize: 12,
                            )),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 30,
              gravity: 0.3,
              colors: const [
                Colors.white,
                Colors.blue,
                Colors.green,
                Colors.yellow,
                Colors.pink,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Staggered fade-in wrapper ─────────────────────────────────────────────────

class _FadeInMemory extends StatefulWidget {
  final int index;
  final Widget child;
  const _FadeInMemory({required this.index, required this.child});

  @override
  State<_FadeInMemory> createState() => _FadeInMemoryState();
}

class _FadeInMemoryState extends State<_FadeInMemory>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fade =
        CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: 80 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// ── Text memory card ──────────────────────────────────────────────────────────

class _TextMemoryCard extends StatelessWidget {
  final String text;
  const _TextMemoryCard({required this.text});

  @override
  Widget build(BuildContext context) {
    final isShort = text.length < 120;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(isShort ? 24 : 20),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isShort)
            Text('"',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.15),
                  fontSize: 48,
                  height: 0.8,
                  fontWeight: FontWeight.w700,
                )),
          Text(text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: isShort ? 18 : 15,
                height: isShort ? 1.6 : 1.7,
                fontWeight: isShort
                    ? FontWeight.w500
                    : FontWeight.w400,
              )),
        ],
      ),
    );
  }
}

// ── Photo memory card ─────────────────────────────────────────────────────────

class _PhotoMemoryCard extends StatelessWidget {
  final Uint8List bytes;
  final VoidCallback onTap;
  const _PhotoMemoryCard({required this.bytes, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: AppTheme.cardDark,
        ),
        clipBehavior: Clip.hardEdge,
        child: Image.memory(bytes,
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('[Could not display image]',
                      style:
                          TextStyle(color: AppTheme.mutedText)),
                )),
      ),
    );
  }
}

// ── Skeleton loading card ─────────────────────────────────────────────────────

class _SkeletonCard extends StatefulWidget {
  final int index;
  const _SkeletonCard({required this.index});

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);
    _anim =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: double.infinity,
        height: widget.index == 0 ? 100 : 200,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Color.lerp(const Color(0xFF111111),
              const Color(0xFF1A1A1A), _anim.value),
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}

// ── Memory model ──────────────────────────────────────────────────────────────

enum _MemoryType { text, photo }

class _Memory {
  final _MemoryType type;
  final String? text;
  final Uint8List? bytes;

  _Memory.text(this.text)
      : type = _MemoryType.text,
        bytes = null;

  _Memory.photo(this.bytes)
      : type = _MemoryType.photo,
        text = null;
}