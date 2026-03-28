import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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

  // Edit profile controllers
  final _displayNameController = TextEditingController();
  final _bioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthProvider>();
      if (auth.user == null) return;

      // Reload capsules so stats are fresh
      await context
          .read<CapsuleProvider>()
          .loadCapsules(auth.user!.$id);

      final data = await _authService.getUserProfile(auth.user!.$id);
      if (mounted) {
        setState(() {
          _profileData = data;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showEditProfile() {
    final displayName = _profileData?['displayName'] as String? ?? '';
    final bio = _profileData?['bio'] as String? ?? '';
    _displayNameController.text = displayName;
    _bioController.text = bio;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24, 20, 24,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Edit Profile',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),

            // Display name
            Text('Display Name',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5), fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _displayNameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Your name',
                hintStyle: const TextStyle(color: AppTheme.mutedText2),
                filled: true,
                fillColor: AppTheme.cardDark2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 16),

            // Bio
            Text('Bio',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5), fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: _bioController,
              maxLines: 3,
              maxLength: 120,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'A little about you...',
                hintStyle: const TextStyle(color: AppTheme.mutedText2),
                filled: true,
                fillColor: AppTheme.cardDark2,
                counterStyle:
                    const TextStyle(color: AppTheme.mutedText2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () async {
                  final auth = context.read<AuthProvider>();
                  try {
                    await _authService.updateUserProfile(
                      userId: auth.user!.$id,
                      displayName: _displayNameController.text.trim(),
                      bio: _bioController.text.trim(),
                    );
                    if (!mounted) return;
                    Navigator.pop(ctx);
                    _load();
                  } catch (_) {
                    if (!mounted) return;
                    Navigator.pop(ctx);
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save Changes',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _memberSince() {
    final user = context.read<AuthProvider>().user;
    if (user == null) return '';
    try {
      final reg = DateTime.parse(user.registration.toString());
      return 'Member since ${DateFormat('MMMM yyyy').format(reg)}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final capsuleProvider = context.watch<CapsuleProvider>();
    final capsules = capsuleProvider.capsules;

    final username = _profileData?['username'] as String? ?? '';
    final displayName = _profileData?['displayName'] as String? ?? '';
    final bio = _profileData?['bio'] as String? ?? '';
    final email = auth.user?.email ?? '';
    final memberSince = _memberSince();

    final initials = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : email.isNotEmpty
            ? email[0].toUpperCase()
            : 'U';

    // Most recent capsule
    Map<String, dynamic>? recentCapsule;
    if (capsules.isNotEmpty) {
      final sorted = [...capsules];
      sorted.sort((a, b) {
        final aDate = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime(0);
        final bDate = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime(0);
        return bDate.compareTo(aDate);
      });
      recentCapsule = sorted.first;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: _loading ? 280 : (bio.isNotEmpty ? 310 : 280),
            pinned: true,
            backgroundColor: const Color(0xFF0A0A0A),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              // Edit profile pencil
              if (!_loading)
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      color: Colors.white, size: 20),
                  onPressed: _showEditProfile,
                ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: const Icon(Icons.settings_outlined,
                      color: Colors.white, size: 20),
                  onPressed: () async {
                    await Navigator.pushNamed(context, AppRouter.settings);
                    _load();
                  },
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Subtle dark gradient — matches app black theme
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF1C1C1C),
                          Color(0xFF0A0A0A),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),

                  // Subtle decorative circles
                  Positioned(
                    top: -40, right: -40,
                    child: Container(
                      width: 200, height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.02),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -20, left: -20,
                    child: Container(
                      width: 150, height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.02),
                      ),
                    ),
                  ),

                  // Avatar + name
                  Positioned(
                    bottom: 32, left: 0, right: 0,
                    child: _loading
                        ? _headerSkeleton()
                        : Column(
                            children: [
                              // White avatar
                              Container(
                                width: 84, height: 84,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                                child: Center(
                                  child: Text(
                                    initials,
                                    style: const TextStyle(
                                      color: Colors.black,
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
                                username.isNotEmpty ? '@$username' : email,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.55),
                                  fontSize: 14,
                                ),
                              ),
                              if (memberSince.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  memberSince,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.3),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
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

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: _loading
                  ? _bodySkeleton()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // Stats row — no border
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 20, horizontal: 24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111111),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _statItem(
                                  value: capsules.length.toString(),
                                  label: 'Capsules',
                                  icon: '📦',
                                ),
                              ),
                              Container(
                                width: 1, height: 40,
                                color: Colors.white.withOpacity(0.08),
                              ),
                              Expanded(
                                child: _statItem(
                                  value: capsules.where((c) {
                                    final u = DateTime.tryParse(
                                        c['unlockDate'] ?? '');
                                    return u != null &&
                                        DateTime.now().isAfter(u);
                                  }).length.toString(),
                                  label: 'Unlocked',
                                  icon: '🔓',
                                ),
                              ),
                              Container(
                                width: 1, height: 40,
                                color: Colors.white.withOpacity(0.08),
                              ),
                              Expanded(
                                child: _statItem(
                                  value: capsules.where((c) {
                                    final u = DateTime.tryParse(
                                        c['unlockDate'] ?? '');
                                    return u != null &&
                                        DateTime.now().isBefore(u);
                                  }).length.toString(),
                                  label: 'Locked',
                                  icon: '🔒',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Most recent capsule
                        if (recentCapsule != null) ...[
                          Text(
                            'Most Recent',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.45),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _RecentCapsuleCard(data: recentCapsule),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // Skeleton for the header while loading
  Widget _headerSkeleton() {
    return Column(
      children: [
        Container(
          width: 84, height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.08),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: 140, height: 18,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 90, height: 12,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ],
    );
  }

  // Skeleton for stats while loading
  Widget _bodySkeleton() {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
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
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 12,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _RecentCapsuleCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _RecentCapsuleCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final name = (data['name'] ?? 'Untitled').toString();
    final emoji = (data['emoji'] ?? '📦').toString();
    final unlockDate = DateTime.tryParse(data['unlockDate'] ?? '');
    final isUnlocked =
        unlockDate != null && DateTime.now().isAfter(unlockDate);
    final unlockStr = unlockDate != null
        ? DateFormat('MMM d, yyyy').format(unlockDate.toLocal())
        : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(
            color: isUnlocked
                ? AppTheme.green.withOpacity(0.6)
                : AppTheme.blue.withOpacity(0.6),
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppTheme.cardDark2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(emoji,
                  style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(unlockStr,
                    style: const TextStyle(
                        color: AppTheme.mutedText2, fontSize: 13)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isUnlocked
                  ? AppTheme.green.withOpacity(0.15)
                  : AppTheme.blue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isUnlocked ? 'Unlocked' : 'Locked',
              style: TextStyle(
                color: isUnlocked ? AppTheme.green : AppTheme.blue,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}