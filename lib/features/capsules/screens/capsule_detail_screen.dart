import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:boxed_app/core/services/encryption_service.dart';
import 'package:boxed_app/core/state/capsule_crypto_state.dart';
import 'package:boxed_app/core/state/user_crypto_state.dart';
import 'package:boxed_app/core/theme/app_theme.dart';
import 'package:boxed_app/features/capsules/providers/capsule_provider.dart';
import 'package:boxed_app/features/capsules/services/capsule_service.dart';
import 'package:boxed_app/features/memories/screens/memory_feed_screen.dart';

class CapsuleDetailScreen extends StatefulWidget {
  final String capsuleId;
  const CapsuleDetailScreen({super.key, required this.capsuleId});

  @override
  State<CapsuleDetailScreen> createState() => _CapsuleDetailScreenState();
}

enum _Stage { loading, error, locked, unlockReady, revealed }

class _CapsuleDetailScreenState extends State<CapsuleDetailScreen> {
  _Stage _stage = _Stage.loading;
  String? _error;

  Map<String, dynamic>? _capsuleData;
  DateTime? _unlockDate;
  Duration _remaining = Duration.zero;
  Timer? _timer;

  final _capsuleService = CapsuleService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    CapsuleCryptoState.clearKey(widget.capsuleId);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _stage = _Stage.loading);
    try {
      final provider = context.read<CapsuleProvider>();
      Map<String, dynamic>? data;

      try {
        data = provider.capsules.firstWhere(
          (c) => c['capsuleId'] == widget.capsuleId,
        );
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

      final encryptedKey = data['encryptedCapsuleKey'] as String;
      final masterKey = UserCryptoState.userMasterKey;
      final capsuleKey = await EncryptionService.decryptCapsuleKey(
        encryptedKey: encryptedKey,
        userMasterKey: masterKey,
      );
      CapsuleCryptoState.setKey(widget.capsuleId, capsuleKey);

      final unlockDate = DateTime.parse(data['unlockDate'] as String).toLocal();
      _unlockDate = unlockDate;

      final now = DateTime.now();
      final isUnlocked = now.isAfter(unlockDate);

      if (!isUnlocked) {
        _remaining = unlockDate.difference(now);
        _startTimer();
        setState(() => _stage = _Stage.locked);
      } else {
        final isRevealed = data['isRevealed'] == true;
        setState(() =>
            _stage = isRevealed ? _Stage.revealed : _Stage.unlockReady);
      }
    } catch (e) {
      setState(() {
        _stage = _Stage.error;
        _error = e.toString();
      });
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
    await _capsuleService.markRevealed(widget.capsuleId);
    if (mounted) setState(() => _stage = _Stage.revealed);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardDark2,
        title: const Text('Delete capsule?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'This will permanently delete the capsule and all its memories.',
            style: TextStyle(color: AppTheme.mutedText)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
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

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _Stage.loading:
        return const Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: CircularProgressIndicator(color: Colors.white)),
        );
      case _Stage.error:
        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
              backgroundColor: Colors.black, foregroundColor: Colors.white),
          body: Center(
            child: Text(_error ?? 'Error',
                style: const TextStyle(color: AppTheme.red)),
          ),
        );
      case _Stage.locked:
        return _buildLocked();
      case _Stage.unlockReady:
        return _buildUnlockReady();
      case _Stage.revealed:
        return _buildRevealed();
    }
  }

  Widget _buildLocked() {
    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;
    final title = (_capsuleData?['name'] ?? '').toString();
    final unlockStr = _unlockDate != null
        ? DateFormat('MMM d, yyyy • h:mm a').format(_unlockDate!)
        : '';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('Capsule Status',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.lock_outline,
                      size: 44, color: AppTheme.accent),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                title.isNotEmpty ? title : 'Your Capsule',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                "This capsule is sealed. Come back when\nthe countdown hits zero.",
                style: TextStyle(
                    color: Colors.white.withOpacity(0.6), height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
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
              const SizedBox(height: 20),
              if (unlockStr.isNotEmpty)
                Text(
                  'Unlocks on $unlockStr',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.45), fontSize: 13),
                  textAlign: TextAlign.center,
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

  Widget _buildUnlockReady() {
    final title = (_capsuleData?['name'] ?? '').toString();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
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
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                    color: AppTheme.cardDark2, shape: BoxShape.circle),
                child: const Icon(Icons.card_giftcard,
                    size: 44, color: Colors.white),
              ),
              const SizedBox(height: 22),
              Text(
                title.isNotEmpty ? title : 'Your Capsule',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Your memories are ready to be revealed',
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
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
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'This is a one-time reveal. Enjoy the moment!',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4), fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRevealed() {
    final title = (_capsuleData?['name'] ?? '').toString();
    final desc = (_capsuleData?['description'] ?? '').toString();
    final unlockStr = _unlockDate != null
        ? DateFormat('MMM d, yyyy').format(_unlockDate!)
        : '';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('Your Capsule',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            children: [
              Text(
                title.isNotEmpty ? title : 'Capsule',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              if (desc.isNotEmpty)
                Text(
                  desc,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7), height: 1.4),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          MemoryFeedScreen(capsuleId: widget.capsuleId),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('View Memories',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const Spacer(),
              if (unlockStr.isNotEmpty)
                Text(
                  'Unlocked on $unlockStr',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.35), fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}