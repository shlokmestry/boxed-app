import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final capsuleProvider = context.watch<CapsuleProvider>();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Your Capsules',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
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
                  const Icon(Icons.search, color: AppTheme.mutedText2, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 15),
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
                        color: selected ? Colors.white : AppTheme.cardDark2,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: selected ? Colors.black : AppTheme.mutedText,
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

            // List
            Expanded(child: _buildBody(capsuleProvider)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(CapsuleProvider provider) {
    switch (provider.state) {
      case CapsuleLoadState.loading:
        return const Center(
            child: CircularProgressIndicator(color: Colors.white));

      case CapsuleLoadState.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(provider.error ?? 'Something went wrong',
                  style: const TextStyle(color: AppTheme.red),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _load,
                style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white)),
                child: const Text('Retry'),
              ),
            ],
          ),
        );

      case CapsuleLoadState.empty:
        return _emptyState();

      case CapsuleLoadState.loaded:
        final filtered = _filtered(provider.capsules);
        if (filtered.isEmpty) return _emptyState();
        return RefreshIndicator(
          onRefresh: () async => _load(),
          color: Colors.white,
          backgroundColor: AppTheme.cardDark2,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: filtered.length,
            itemBuilder: (_, i) => _CapsuleCard(
              data: filtered[i],
              onTap: () => Navigator.pushNamed(
                context,
                AppRouter.capsuleDetail,
                arguments: filtered[i]['capsuleId'] as String,
              ),
            ),
          ),
        );

      case CapsuleLoadState.idle:
        return const SizedBox.shrink();
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

class _CapsuleCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _CapsuleCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = (data['name'] ?? 'Untitled').toString();
    final emoji = (data['emoji'] ?? '📦').toString();
    final unlockDate = DateTime.tryParse(data['unlockDate'] ?? '');
    final isUnlocked = unlockDate != null && DateTime.now().isAfter(unlockDate);

    String timeLabel = '';
    if (unlockDate != null) {
      if (isUnlocked) {
        final diff = DateTime.now().difference(unlockDate);
        if (diff.inDays >= 1) {
          timeLabel = '${diff.inDays}d ago';
        } else if (diff.inHours >= 1) {
          timeLabel = '${diff.inHours}h ago';
        } else {
          timeLabel = 'Just now';
        }
      } else {
        final diff = unlockDate.difference(DateTime.now());
        if (diff.inDays >= 1) {
          timeLabel = 'in ${diff.inDays}d';
        } else if (diff.inHours >= 1) {
          timeLabel = 'in ${diff.inHours}h';
        } else {
          timeLabel = 'in ${diff.inMinutes}m';
        }
      }
    }

    final unlockStr = unlockDate != null
        ? DateFormat('MMM d, yyyy').format(unlockDate.toLocal())
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(16),
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
                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
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