import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:boxed_app/core/router/app_router.dart';
import 'package:boxed_app/core/theme/app_theme.dart';
import 'package:boxed_app/features/auth/providers/auth_provider.dart';
import 'package:boxed_app/features/auth/services/auth_service.dart';
import 'package:boxed_app/features/capsules/providers/capsule_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profileData;
  bool _loading = true;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      if (auth.user == null) return;
      final data = await _authService.getUserProfile(auth.user!.$id);
      if (mounted) setState(() { _profileData = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final capsuleProvider = context.watch<CapsuleProvider>();
    final capsuleCount = capsuleProvider.capsules.length;

    final username = _profileData?['username'] as String? ?? '';
    final displayName = _profileData?['displayName'] as String? ?? '';
    final bio = _profileData?['bio'] as String? ?? '';
    final email = auth.user?.email ?? '';

    final initials = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : email.isNotEmpty
            ? email[0].toUpperCase()
            : 'U';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white))
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 280,
                  pinned: true,
                  backgroundColor: const Color(0xFF0A0A0A),
                  leading: IconButton(
                    icon: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 18),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: IconButton(
                        icon: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.settings_outlined,
                              color: Colors.white, size: 18),
                        ),
                        onPressed: () async {
                          await Navigator.pushNamed(
                              context, AppRouter.settings);
                          _load();
                        },
                      ),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF1a1a2e),
                                Color(0xFF16213e),
                                Color(0xFF0f3460),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                        Positioned(
                          top: -40,
                          right: -40,
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.03),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -20,
                          left: -20,
                          child: Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.03),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 32,
                          left: 0,
                          right: 0,
                          child: Column(
                            children: [
                              Container(
                                width: 84,
                                height: 84,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF667eea),
                                      Color(0xFF764ba2),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF667eea)
                                          .withOpacity(0.4),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    initials,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                displayName.isNotEmpty
                                    ? displayName
                                    : 'Boxed User',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                username.isNotEmpty
                                    ? '@$username'
                                    : email,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.55),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              if (bio.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 40),
                                  child: Text(
                                    bio,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Body content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                    child: Column(
                      children: [
                        // Stats row
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 20, horizontal: 24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111111),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.06),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _statItem(
                                  value: capsuleCount.toString(),
                                  label: 'Capsules',
                                  icon: '📦',
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.white.withOpacity(0.08),
                              ),
                              Expanded(
                                child: _statItem(
                                  value: capsuleProvider.capsules
                                      .where((c) {
                                        final unlock = DateTime.tryParse(
                                            c['unlockDate'] ?? '');
                                        return unlock != null &&
                                            DateTime.now().isAfter(unlock);
                                      })
                                      .length
                                      .toString(),
                                  label: 'Unlocked',
                                  icon: '🔓',
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.white.withOpacity(0.08),
                              ),
                              Expanded(
                                child: _statItem(
                                  value: capsuleProvider.capsules
                                      .where((c) {
                                        final unlock = DateTime.tryParse(
                                            c['unlockDate'] ?? '');
                                        return unlock != null &&
                                            DateTime.now().isBefore(unlock);
                                      })
                                      .length
                                      .toString(),
                                  label: 'Locked',
                                  icon: '🔒',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Hint
                        Center(
                          child: Text(
                            'Manage your account in Settings ⚙️',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.25),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _statItem({
    required String value,
    required String label,
    required String icon,
  }) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.45),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}