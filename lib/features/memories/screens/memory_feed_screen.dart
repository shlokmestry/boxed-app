import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:boxed_app/core/state/capsule_crypto_state.dart';
import 'package:boxed_app/core/theme/app_theme.dart';
import 'package:boxed_app/features/memories/services/memory_service.dart';

class MemoryFeedScreen extends StatefulWidget {
  final String capsuleId;
  const MemoryFeedScreen({super.key, required this.capsuleId});

  @override
  State<MemoryFeedScreen> createState() => _MemoryFeedScreenState();
}

class _MemoryFeedScreenState extends State<MemoryFeedScreen> {
  final _service = MemoryService();
  bool _loading = true;
  String? _error;
  List<_DecryptedMemory> _memories = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final capsuleKey = CapsuleCryptoState.getKey(widget.capsuleId);
      final raw = await _service.fetchMemories(widget.capsuleId);
      final List<_DecryptedMemory> result = [];

      for (final m in raw) {
        final type = m['type'] as String;
        if (type == 'text') {
          try {
            final text = await _service.decryptTextMemory(
              encryptedContent: m['content'] as String,
              capsuleKey: capsuleKey,
            );
            result.add(_DecryptedMemory.text(text));
          } catch (_) {
            result.add(_DecryptedMemory.text('[Unable to decrypt]'));
          }
        } else if (type == 'photo') {
          try {
            final bytes = await _service.decryptPhotoMemory(
              fileId: m['fileId'] as String,
              capsuleKey: capsuleKey,
            );
            result.add(_DecryptedMemory.photo(bytes));
          } catch (_) {
            result.add(_DecryptedMemory.text('[Unable to decrypt photo]'));
          }
        }
      }

      setState(() { _memories = result; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
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
        title: const Text('Memories',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _error != null
              ? Center(child: Text(_error!,
                  style: const TextStyle(color: AppTheme.red)))
              : _memories.isEmpty
                  ? Center(
                      child: Text('No memories yet.',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 16)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _memories.length,
                      itemBuilder: (_, i) => _buildMemoryCard(_memories[i]),
                    ),
    );
  }

  Widget _buildMemoryCard(_DecryptedMemory memory) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.hardEdge,
        child: memory.type == _MemoryType.text
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  memory.text!,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 15, height: 1.6),
                ),
              )
            : Image.memory(
                memory.bytes!,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, __, ___) => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('[Could not display image]',
                      style: TextStyle(color: AppTheme.mutedText)),
                ),
              ),
      ),
    );
  }
}

enum _MemoryType { text, photo }

class _DecryptedMemory {
  final _MemoryType type;
  final String? text;
  final Uint8List? bytes;

  _DecryptedMemory.text(this.text)
      : type = _MemoryType.text,
        bytes = null;

  _DecryptedMemory.photo(this.bytes)
      : type = _MemoryType.photo,
        text = null;
}