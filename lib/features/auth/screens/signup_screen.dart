import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boxed_app/features/auth/providers/auth_provider.dart';
import 'package:boxed_app/core/router/app_router.dart';
import 'package:boxed_app/core/theme/app_theme.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    if (email.isEmpty) {
      setState(() => _emailError = 'Please enter your email');
      return;
    }
    if (!email.contains('@')) {
      setState(() => _emailError = 'Please enter a valid email');
      return;
    }
    if (password.length < 8) {
      setState(() => _passwordError = 'Password must be at least 8 characters');
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.signup(email: email, password: password);

    if (!mounted) return;

    if (success) {
      Navigator.pushReplacementNamed(context, AppRouter.chooseUsername);
    } else {
      setState(() => _emailError = auth.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isLoading = auth.status == AuthStatus.loading;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text('📦', style: TextStyle(fontSize: 48)),
                ),
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'Create your account',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Start sealing memories.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                _buildField(
                  controller: _emailController,
                  hint: 'Email',
                  error: _emailError,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => setState(() => _emailError = null),
                ),
                const SizedBox(height: 12),
                _buildField(
                  controller: _passwordController,
                  hint: 'Password (min. 8 characters)',
                  error: _passwordError,
                  obscure: _obscurePassword,
                  onChanged: (_) => setState(() => _passwordError = null),
                  suffix: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: AppTheme.mutedText2,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: isLoading ? null : _signup,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Sign Up',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: TextStyle(color: Colors.white.withOpacity(0.6)),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacementNamed(
                          context, AppRouter.login),
                      child: const Text(
                        'Log in',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    String? error,
    bool obscure = false,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.mutedText2),
        errorText: error,
        filled: true,
        fillColor: AppTheme.cardDark2,
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.red),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}