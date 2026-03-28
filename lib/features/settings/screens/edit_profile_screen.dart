import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boxed_app/core/theme/app_theme.dart';
import 'package:boxed_app/features/auth/providers/auth_provider.dart';
import 'package:boxed_app/features/auth/services/auth_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _usernameController = TextEditingController();
  final _authService = AuthService();

  bool _loading = true;
  bool _saving = false;
  bool _checkingUsername = false;
  bool _usernameAvailable = true;
  String? _usernameError;
  String? _originalUsername;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      if (auth.user == null) return;
      final data = await _authService.getUserProfile(auth.user!.$id);
      _nameController.text = data?['displayName'] ?? '';
      _bioController.text = data?['bio'] ?? '';
      _usernameController.text = data?['username'] ?? '';
      _originalUsername = data?['username'] ?? '';
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _checkUsername(String value) async {
    final trimmed = value.trim();

    if (trimmed == _originalUsername) {
      setState(() {
        _usernameError = null;
        _usernameAvailable = true;
      });
      return;
    }

    if (trimmed.length < 3) {
      setState(() {
        _usernameError = 'At least 3 characters';
        _usernameAvailable = false;
      });
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(trimmed)) {
      setState(() {
        _usernameError = 'Letters, numbers and underscores only';
        _usernameAvailable = false;
      });
      return;
    }

    setState(() => _checkingUsername = true);
    final available = await _authService.isUsernameAvailable(trimmed);
    if (mounted) {
      setState(() {
        _checkingUsername = false;
        _usernameAvailable = available;
        _usernameError = available ? null : 'Username already taken';
      });
    }
  }

  Future<void> _save() async {
    if (!_usernameAvailable) return;

    final name = _nameController.text.trim();
    final bio = _bioController.text.trim();
    final username = _usernameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Name cannot be empty'),
            backgroundColor: AppTheme.red),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final auth = context.read<AuthProvider>();
      if (auth.user == null) return;
      final userId = auth.user!.$id;

      await _authService.updateProfile(
        userId: userId,
        displayName: name,
        bio: bio,
      );

      if (username != _originalUsername && username.isNotEmpty) {
        await _authService.setUsername(
            userId: userId, username: username);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated ✓'),
          backgroundColor: Color(0xFF1A1A1A),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppTheme.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('Edit Profile',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: (_saving || !_usernameAvailable) ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Save',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 8),

                // Display Name
                _fieldLabel('Display Name'),
                const SizedBox(height: 8),
                _inputField(
                  controller: _nameController,
                  hint: 'Your name',
                ),
                const SizedBox(height: 20),

                // Username
                _fieldLabel('Username'),
                const SizedBox(height: 8),
                _inputField(
                  controller: _usernameController,
                  hint: 'yourname',
                  prefix: Text('@',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 15)),
                  suffix: _checkingUsername
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : _usernameAvailable &&
                              _usernameController.text.trim().isNotEmpty
                          ? const Icon(Icons.check_circle,
                              color: AppTheme.green, size: 20)
                          : null,
                  onChanged: _checkUsername,
                  error: _usernameError,
                ),
                const SizedBox(height: 8),
                Text(
                  'Letters, numbers and underscores only',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.3), fontSize: 12),
                ),
                const SizedBox(height: 20),

                // Bio
                _fieldLabel('Bio'),
                const SizedBox(height: 8),
                _inputField(
                  controller: _bioController,
                  hint: 'A short bio...',
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                Text(
                  'A short description shown on your profile.',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.3), fontSize: 12),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _fieldLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: AppTheme.mutedText,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      );

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    Widget? prefix,
    Widget? suffix,
    ValueChanged<String>? onChanged,
    String? error,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: error != null
                  ? AppTheme.red.withOpacity(0.5)
                  : Colors.white.withOpacity(0.06),
            ),
          ),
          child: Row(
            crossAxisAlignment: maxLines > 1
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              if (prefix != null) ...[
                const SizedBox(width: 16),
                prefix,
                const SizedBox(width: 4),
              ],
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  maxLines: maxLines,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(color: AppTheme.mutedText2),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 15),
                  ),
                ),
              ),
              if (suffix != null) ...[
                suffix,
                const SizedBox(width: 14),
              ],
            ],
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(error,
              style: const TextStyle(color: AppTheme.red, fontSize: 12)),
        ],
      ],
    );
  }
}