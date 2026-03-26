import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:boxed_app/core/router/app_router.dart';
import 'package:boxed_app/core/theme/app_theme.dart';
import 'package:boxed_app/features/auth/providers/auth_provider.dart';
import 'package:boxed_app/features/capsules/providers/capsule_provider.dart';

enum CapsuleFilter { all, upcoming, unlocked }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  CapsuleFilter _filter = CapsuleFilter.all;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _load() {
    final auth = context.read<AuthProvider>();
    if (auth.user != null) {
      context.read<CapsuleProvider>().loadCapsules(auth.user!.$id);
    }
  }

  Future<void> _refresh() async {
    _load();
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Capsules refreshed',
                style: TextStyle(color: Colors.white, fontSize: 13)),
          ],
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> all) {
    var list = all;

    if (_query.isNotEmpty) {
      list = list.where((c) {
        final name = (c['name'] ?? '').toString().toLowerCase();
        final desc = (c['description'] ?? '').toString().toLowerCase();
        return name.contains(_query) || desc.contains(_query);
      }).toList();
    }

    switch (_filter) {
      case CapsuleFilter.upcoming:
        list = list.where((c) {
          final unlock = DateTime.tryParse(c['unlockDate'] ?? '');
          return unlock != null && DateTime.now().isBefore(unlock);
        }).toList();
        break;
      case CapsuleFilter.unlocked:
        list = list.where((c) {
          final unlock = DateTime.tryParse(c['unlockDate'] ?? '');
          return unlock != null && DateTime.now().isAfter(unlock);
        }).toList();
        break;
      case CapsuleFilter.all:
        break;
    }

    return list;
  }

  // Returns the soonest upcoming capsule
  Map<String, dynamic>? _nextUnlock(List<Map<String, dynamic>> capsules) {
    final now = DateTime.now();
    final upcoming = capsules.where((c) {
      final unlock = DateTime.tryParse(c['unlockDate'] ?? '');
      return unlock != null && unlock.isAfter(now);
    }).toList();

    if (upcoming.isEmpty) return null;

    upcoming.sort((a, b) {
      final aDate = DateTime.parse(a['unlockDate']);
      final bDate = DateTime.parse(b['unlockDate']);
      return aDate.compareTo(bDate);
    });

    return upcoming.first;
  }

  String _nextUnlockLabel(DateTime unlock) {
    final diff = unlock.difference(DateTime.now());
    if (diff.inDays >= 1) return '⏳ Next unlock in ${diff.inDays} day${diff.inDays == 1 ? '' : 's'}';
    if (diff.inHours >= 1) return '⏳ Next unlock in ${diff.inHours} hour${diff.inHours == 1 ? '' : 's'}';
    return '⏳ Next unlock in ${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'}';
  }

  Future<void> _confirmDelete(
      BuildContext context, String capsuleId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete capsule?',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
          '"$name" will be permanently deleted. This cannot be undone.',
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
            child: Text('Delete', style: TextStyle(color: AppTheme.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      context.read<CapsuleProvider>().deleteCapsule(capsuleId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final capsuleProvider = context.watch<CapsuleProvider>();
    final bottomPad = MediaQuery.of(context).padding.bottom;

    // Greeting from email or username
    final rawName = auth.user?.email?.split('@').first ?? 'there';
    final greeting =
        rawName[0].toUpperCase() + rawName.substring(1).toLowerCase();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hey $greeting 👋',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRouter.profile),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.cardDark2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  (auth.user?.email ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: GestureDetector(
        onTap: () async {
          await Navigator.pushNamed(context, AppRouter.createCapsule);
          _load();
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.add, color: Colors.black, size: 28),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Column(
          children: [
            // Search bar
            Container(
              height: 46,
              decoration: BoxDecoration(
                color: AppTheme.cardDark2,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Icon(Icons.search,
                      color: AppTheme.mutedText2, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: 'Search capsules...',
                        hintStyle: TextStyle(color: AppTheme.mutedText2),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    GestureDetector(
                      onTap: () => _searchController.clear(),
                      child: const Icon(Icons.close,
                          color: AppTheme.mutedText2, size: 18),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Filter chips
            Row(
              children: CapsuleFilter.values.map((f) {
                final selected = _filter == f;
                final label = f == CapsuleFilter.all
                    ? 'All'
                    : f == CapsuleFilter.upcoming
                        ? 'Upcoming'
                        : 'Unlocked';
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _filter = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white
                            : AppTheme.cardDark2,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: selected
                              ? Colors.black
                              : AppTheme.mutedText,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Next unlock banner
            if (capsuleProvider.state == CapsuleLoadState.loaded) ...[
              Builder(builder: (_) {
                final next = _nextUnlock(capsuleProvider.capsules);
                if (next == null) return const SizedBox.shrink();
                final unlockDate = DateTime.parse(next['unlockDate']);
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.blue.withOpacity(0.25)),
                  ),
                  child: Text(
                    _nextUnlockLabel(unlockDate),
                    style: TextStyle(
                      color: AppTheme.blue.withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }),
            ],

            // List
            Expanded(
              child: _buildBody(capsuleProvider, bottomPad),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(CapsuleProvider provider, double bottomPad) {
    switch (provider.state) {
      case CapsuleLoadState.loading:
        return ListView.builder(
          padding: EdgeInsets.only(bottom: bottomPad + 80),
          itemCount: 5,
          itemBuilder: (_, __) => const _ShimmerCard(),
        );

      case CapsuleLoadState.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                provider.error ?? 'Something went wrong',
                style: const TextStyle(color: AppTheme.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _load,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        );

      case CapsuleLoadState.empty:
        return _emptyState();

      // ✅ idle now shows shimmer instead of blank flash
      case CapsuleLoadState.idle:
        return ListView.builder(
          padding: EdgeInsets.only(bottom: bottomPad + 80),
          itemCount: 5,
          itemBuilder: (_, __) => const _ShimmerCard(),
        );

      case CapsuleLoadState.loaded:
        final filtered = _filtered(provider.capsules);
        if (filtered.isEmpty) return _emptyState();
        return RefreshIndicator(
          onRefresh: _refresh,
          color: Colors.white,
          backgroundColor: AppTheme.cardDark2,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(bottom: bottomPad + 80),
            itemCount: filtered.length,
            itemBuilder: (_, i) => _CapsuleCard(
              data: filtered[i],
              onTap: () => Navigator.pushNamed(
                context,
                AppRouter.capsuleDetail,
                arguments: filtered[i]['capsuleId'] as String,
              ),
              onLongPress: () => _confirmDelete(
                context,
                filtered[i]['capsuleId'] as String,
                filtered[i]['name'] as String? ?? 'Untitled',
              ),
            ),
          ),
        );
    }
  }

  Widget _emptyState() {
    final messages = {
      CapsuleFilter.all: 'No capsules yet.\nTap + to create your first one.',
      CapsuleFilter.upcoming: 'No upcoming capsules.',
      CapsuleFilter.unlocked: 'Nothing unlocked yet.\nGive it time.',
    };
    return Center(
      child: Text(
        messages[_filter] ?? 'Nothing here.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppTheme.mutedText2, fontSize: 16),
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Shimmer.fromColors(
        baseColor: AppTheme.cardDark,
        highlightColor: AppTheme.cardDark2,
        child: Container(
          height: 90,
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _CapsuleCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _CapsuleCard({
    required this.data,
    required this.onTap,
    required this.onLongPress,
  });

  String _timeLabel(DateTime unlockDate, bool isUnlocked) {
    if (isUnlocked) {
      final diff = DateTime.now().difference(unlockDate);
      if (diff.inDays >= 1) return 'Opened ${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
      if (diff.inHours >= 1) return 'Opened ${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
      return 'Just opened';
    } else {
      final diff = unlockDate.difference(DateTime.now());
      if (diff.inDays >= 1) return 'Opens in ${diff.inDays} day${diff.inDays == 1 ? '' : 's'}';
      if (diff.inHours >= 1) return 'Opens in ${diff.inHours} hour${diff.inHours == 1 ? '' : 's'}';
      return 'Opens in ${diff.inMinutes} min';
    }
  }

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

    final timeLabel =
        unlockDate != null ? _timeLabel(unlockDate, isUnlocked) : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(16),
            // Subtle left accent border
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.cardDark2,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(emoji,
                      style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      unlockStr,
                      style: const TextStyle(
                        color: AppTheme.mutedText2,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
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
                  const SizedBox(height: 6),
                  Text(
                    timeLabel,
                    style: const TextStyle(
                      color: AppTheme.mutedText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}