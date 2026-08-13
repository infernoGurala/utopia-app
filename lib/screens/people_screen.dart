import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../services/follow_service.dart';
import '../widgets/app_motion.dart';
import '../widgets/instagram_badge.dart';
import '../widgets/utopia_loader.dart';
import 'user_profile_screen.dart';

const List<String> kBTechBranches = [
  'Agri Engg',
  'CSE (AI & ML)',
  'CSE (AI & ML - Microsoft)',
  'CSE (AI & ML - Google)',
  'Civil Engg',
  'CSE',
  'CSE (Data Science)',
  'CSE (Data Science - Google)',
  'CSE (Google Cloud)',
  'CSE (SAP)',
  'EEE',
  'ECE',
  'Mechanical Engg',
  'Mining Engg',
  'Petroleum Tech',
];

class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key});

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String _selectedFilter = 'All';
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream;

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _usersStream = FirebaseFirestore.instance
        .collection('users')
        .orderBy('displayName')
        .snapshots();
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: U.bg,
      appBar: AppBar(
        backgroundColor: U.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: U.text, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'People',
          style: GoogleFonts.outfit(
            color: U.text,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) _searchController.clear();
            }),
            icon: Icon(
              _isSearching ? Icons.close_rounded : Icons.search_rounded,
              color: U.text,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _usersStream,
          builder: (context, snap) {
            final rawDocs = snap.data?.docs ?? [];
            final totalCount = rawDocs.length;

            final superuserCount = rawDocs
                .where((d) => (d.data()['role'] ?? '').toString().toLowerCase() == 'superuser')
                .length;

            final branchCounts = <String, int>{};
            for (final d in rawDocs) {
              final branch = (d.data()['branch'] ?? '').toString().trim();
              if (branch.isNotEmpty) {
                branchCounts[branch] = (branchCounts[branch] ?? 0) + 1;
              }
            }

            final query = _searchController.text.trim().toLowerCase();
            final users = rawDocs
                .map((d) => {'uid': d.id, ...d.data()})
                .where((u) {
              final role = (u['role'] ?? '').toString().toLowerCase();
              if (_selectedFilter == 'Superusers' && role != 'superuser') {
                return false;
              }

              if (_selectedFilter != 'All' && _selectedFilter != 'Superusers') {
                final userBranch = (u['branch'] ?? '').toString().trim();
                if (userBranch != _selectedFilter) {
                  return false;
                }
              }

              if (query.isEmpty) return true;
              final name = (u['displayName'] ?? '').toString().toLowerCase();
              final email = (u['email'] ?? '').toString().toLowerCase();
              final branch = (u['branch'] ?? '').toString().toLowerCase();
              final instagram = (u['instagramId'] ?? '').toString().toLowerCase();
              return name.contains(query) ||
                  email.contains(query) ||
                  branch.contains(query) ||
                  instagram.contains(query);
            }).toList()
              ..sort((a, b) {
                final nameA = (a['displayName'] ?? '').toString().toLowerCase();
                final nameB = (b['displayName'] ?? '').toString().toLowerCase();
                return nameA.compareTo(nameB);
              });

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isSearching)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: U.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: U.border),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 14),
                          Icon(Icons.search_rounded, color: U.sub, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              autofocus: true,
                              style: GoogleFonts.outfit(color: U.text, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Search people...',
                                hintStyle: GoogleFonts.outfit(color: U.sub, fontSize: 14),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: Icon(Icons.close_rounded, color: U.sub, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
                  child: SizedBox(
                    height: 32,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        _buildFilterTab('All', snap.hasData ? totalCount : null),
                        const SizedBox(width: 8),
                        ...kBTechBranches.map((branch) {
                          final count = branchCounts[branch] ?? 0;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _buildFilterTab(branch, snap.hasData ? count : null),
                          );
                        }),
                        _buildFilterTab('Superusers', snap.hasData ? superuserCount : null),
                      ],
                    ),
                  ),
                ),
                if (snap.hasData)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(
                      _selectedFilter == 'All' && query.isEmpty
                          ? 'TOTAL PEOPLE (${users.length})'
                          : 'FILTERED RESULTS (${users.length} OF $totalCount)',
                      style: GoogleFonts.outfit(
                        color: U.sub,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                Divider(height: 1, color: U.border, thickness: 0.5),
                Expanded(
                  child: snap.connectionState == ConnectionState.waiting
                      ? const _MinimalPeopleSkeleton()
                      : snap.hasError
                          ? _EmptyState(
                              icon: Icons.error_outline_rounded,
                              title: 'Could not load people',
                              subtitle: 'Please check your connection and try again.',
                            )
                          : users.isEmpty
                              ? _EmptyState(
                                  icon: Icons.person_search_rounded,
                                  title: 'No results found',
                                  subtitle: query.isNotEmpty
                                      ? 'Try searching with another name.'
                                      : 'Campus community members will appear here.',
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  itemCount: users.length,
                                  separatorBuilder: (context, index) => Padding(
                                    padding: const EdgeInsets.only(left: 72),
                                    child: Divider(
                                      height: 1,
                                      thickness: 0.5,
                                      color: U.border.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  itemBuilder: (context, index) {
                                    final user = users[index];
                                    final uid = user['uid'].toString();
                                    return _MinimalPeopleRow(
                                      user: user,
                                      currentUid: _currentUid,
                                      onTap: () {
                                        Navigator.of(context).push(
                                          buildForwardRoute(
                                            UserProfileScreen(
                                              uid: uid,
                                              displayName:
                                                  (user['displayName'] ?? 'Student').toString().trim(),
                                              email: (user['email'] ?? '').toString(),
                                              photoUrl: user['photoUrl']?.toString(),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterTab(String label, [int? count]) {
    final isSelected = _selectedFilter == label;
    final displayLabel = count != null ? '$label ($count)' : label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? U.primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? U.primary.withValues(alpha: 0.3) : U.border,
            width: 0.8,
          ),
        ),
        child: Text(
          displayLabel,
          style: GoogleFonts.outfit(
            color: isSelected ? U.primary : U.sub,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _MinimalPeopleRow extends StatefulWidget {
  const _MinimalPeopleRow({
    required this.user,
    required this.currentUid,
    required this.onTap,
  });

  final Map<String, dynamic> user;
  final String currentUid;
  final VoidCallback onTap;

  @override
  State<_MinimalPeopleRow> createState() => _MinimalPeopleRowState();
}

class _MinimalPeopleRowState extends State<_MinimalPeopleRow> {
  final FollowService _followService = FollowService();
  bool _loading = false;

  Future<void> _toggleFollow(FollowStatus status) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await _followService.toggleFollow(widget.user['uid'].toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.user['uid'].toString();
    final displayName = (widget.user['displayName'] ?? 'Student').toString().trim();
    final photoUrl = widget.user['photoUrl']?.toString();
    final bio = (widget.user['bio'] ?? '').toString().trim();
    final branch = (widget.user['branch'] ?? '').toString().trim();
    final instagramId = (widget.user['instagramId'] ?? '').toString().trim();
    final isSuperuser = widget.user['role'] == 'superuser';

    return InkWell(
      onTap: widget.onTap,
      splashColor: U.primary.withValues(alpha: 0.04),
      highlightColor: U.primary.withValues(alpha: 0.02),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: U.primary.withValues(alpha: 0.12),
              backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                  ? CachedNetworkImageProvider(photoUrl)
                  : null,
              child: photoUrl == null || photoUrl.isEmpty
                  ? Text(
                      displayName.isEmpty ? 'U' : displayName[0].toUpperCase(),
                      style: GoogleFonts.outfit(
                        color: U.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: U.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isSuperuser) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified_rounded,
                          color: Color(0xFF1D9BF0),
                          size: 14,
                        ),
                      ],
                      if (instagramId.isNotEmpty) ...[
                        const SizedBox(width: 5),
                        InstagramBadge(
                          handle: instagramId,
                          iconSize: 13,
                          showHandle: false,
                        ),
                      ],
                      if (branch.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: U.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            branch,
                            style: GoogleFonts.outfit(
                              color: U.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (bio.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      bio,
                      style: GoogleFonts.outfit(
                        color: U.sub,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (uid != widget.currentUid)
              StreamBuilder<FollowStatus>(
                stream: _followService.followStatusStream(
                  widget.currentUid,
                  uid,
                ),
                builder: (context, statusSnap) {
                  final status = statusSnap.data ?? FollowStatus.notFollowing;
                  return _MinimalFollowButton(
                    status: status,
                    loading: _loading,
                    onTap: () => _toggleFollow(status),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _MinimalFollowButton extends StatelessWidget {
  const _MinimalFollowButton({
    required this.status,
    required this.loading,
    required this.onTap,
  });

  final FollowStatus status;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    String label;
    Color bg;
    Color fg;
    bool bordered;

    switch (status) {
      case FollowStatus.notFollowing:
        label = 'Follow';
        bg = U.primary;
        fg = U.bg;
        bordered = false;
        break;
      case FollowStatus.requested:
        label = 'Requested';
        bg = Colors.transparent;
        fg = U.sub;
        bordered = true;
        break;
      case FollowStatus.following:
        label = 'Following';
        bg = Colors.transparent;
        fg = U.sub;
        bordered = true;
        break;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: bordered ? Border.all(color: U.border, width: 0.8) : null,
        ),
        child: loading
            ? const UtopiaLoader(scale: 0.3)
            : Text(
                label,
                style: GoogleFonts.outfit(
                  color: fg,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

class _MinimalPeopleSkeleton extends StatelessWidget {
  const _MinimalPeopleSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 8,
      separatorBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(left: 72),
        child: Divider(height: 1, thickness: 0.5, color: U.border.withValues(alpha: 0.5)),
      ),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              const SkeletonBox(height: 44, width: 44, radius: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBox(height: 14, width: 130, radius: 7),
                    SizedBox(height: 6),
                    SkeletonBox(height: 11, width: 170, radius: 6),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const SkeletonBox(height: 28, width: 68, radius: 14),
            ],
          ),
        ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(
              begin: 0.3,
              end: 0.8,
              duration: 800.ms,
              delay: (index * 100).ms,
            );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: U.sub.withValues(alpha: 0.6)),
            const SizedBox(height: 14),
            Text(
              title,
              style: GoogleFonts.outfit(
                color: U.text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.outfit(color: U.sub, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
