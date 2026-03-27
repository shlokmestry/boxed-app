import 'package:flutter/material.dart';
import 'package:boxed_app/core/theme/app_theme.dart';
import 'package:boxed_app/core/services/appwrite_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  String? _currentError;
  String? _newError;
  String? _confirmError;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool _validate() {
    String? currentErr;
    String? newErr;
    String? confirmErr;

    if (_currentController.text.isEmpty) {
      currentErr = 'Enter your current password';
    }

    final newPass = _newController.text;
    if (newPass.isEmpty) {
      newErr = 'Enter a new password';
    } else if (newPass.length < 8) {
      newErr = 'At least 8 characters';
    } else if (newPass == _currentController.text) {
      newErr = 'New password must be different';
    }

    if (_confirmController.text.isEmpty) {
      confirmErr = 'Please confirm your new password';
    } else if (_confirmController.text != newPass) {
      confirmErr = 'Passwords don\'t match';
    }

    setState(() {
      _currentError = currentErr;
      _newError = newErr;
      _confirmError = confirmErr;
    });

    return currentErr == null && newErr == null && confirmErr == null;
  }

  Future<void> _save() async {
    if (!_validate()) return;

    setState(() => _isLoading = true);

    try {
      await AppwriteService.account.updatePassword(
        password: _newController.text,
        oldPassword: _currentController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline,
                  color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('Password updated successfully',
                  style: TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
          backgroundColor: const Color(0xFF1A1A1A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      setState(() {
        if (msg.contains('invalid') || msg.contains('incorrect') ||
            msg.contains('password')) {
          _currentError = 'Current password is incorrect';
        } else {
          _currentError = 'Something went wrong. Try again.';
        }
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        title: const Text('Change Password',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 12),

            // Header
            const Text(
              '🔑',
              style: TextStyle(fontSize: 48),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Update your password',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Enter your current password\nthen choose a new one.',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 14,
                  height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // Current password
            _label('Current Password'),
            const SizedBox(height: 8),
            _inputField(
              controller: _currentController,
              hint: 'Your current password',
              obscure: _obscureCurrent,
              error: _currentError,
              onChanged: (_) => setState(() => _currentError = null),
              toggleObscure: () =>
                  setState(() => _obscureCurrent = !_obscureCurrent),
            ),
            const SizedBox(height: 20),

            // New password
            _label('New Password'),
            const SizedBox(height: 8),
            _inputField(
              controller: _newController,
              hint: 'Min. 8 characters',
              obscure: _obscureNew,
              error: _newError,
              onChanged: (_) => setState(() => _newError = null),
              toggleObscure: () =>
                  setState(() => _obscureNew = !_obscureNew),
            ),
            const SizedBox(height: 20),

            // Confirm new password
            _label('Confirm New Password'),
            const SizedBox(height: 8),
            _inputField(
              controller: _confirmController,
              hint: 'Repeat new password',
              obscure: _obscureConfirm,
              error: _confirmError,
              onChanged: (_) => setState(() => _confirmError = null),
              toggleObscure: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            const SizedBox(height: 36),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: _isLoading ? null : _save,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Update Password',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '🔒 Your password is never stored in plain text.',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.25), fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          color: AppTheme.mutedText,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      );

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback toggleObscure,
    String? error,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardDark2,
            borderRadius: BorderRadius.circular(12),
            border: error != null
                ? Border.all(color: AppTheme.red.withOpacity(0.6))
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscure,
                  onChanged: onChanged,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle:
                        const TextStyle(color: AppTheme.mutedText2),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 15),
                  ),
                ),
              ),
              GestureDetector(
                onTap: toggleObscure,
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Icon(
                    obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: Colors.white38,
                    size: 20,
                  ),
                ),
              ),
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