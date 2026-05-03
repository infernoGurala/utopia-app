import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../services/follow_service.dart';
import '../services/game_champion_service.dart';
import '../widgets/app_motion.dart';
import '../widgets/game_champion_badge.dart';
import 'user_profile_screen.dart';

class EveryoneScreen extends StatefulWidget {
  const EveryoneScreen({super.key, this.universityId});
  final String? universityId;

  @override
  State<EveryoneScreen> createState() => _EveryoneScreenState();
}

class _EveryoneScreenState extends State<EveryoneScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  Stream<QuerySnapshot<Map<String, dynamic>>> _buildStream() {
    final uniId = widget.universityId;
    if (uniId != null && uniId.isNotEmpty) {
      return FirebaseFirestore.instance
          .collection('users')
          .where('selectedUniversityId', isEqualTo: uniId)
          .orderBy('displayName')
          .snapshots();
    }
    return FirebaseFirestore.instance
        .collection('users')
        .orderBy('displayName')
        .snapshots();
  }

  @override
  void initState() {
    super.initState();
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
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isSearching
                    ? Row(
                        key: const ValueKey('search'),
                        children: [
                          Expanded(
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: U.card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: U.border),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(width: 12),
                                  Icon(Icons.search, color: U.sub, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      autofocus: true,
                                      style: GoogleFonts.outfit(
                                          color: U.text, fontSize: 14),
                                      decoration: InputDecoration(
                                        hintText: 'Search people...',
                                        hintStyle: GoogleFonts.outfit(
                                            color: U.dim),
                                        border: InputBorder.none,
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  if (_searchController.text.isNotEmpty)
                                    IconButton(
                                      icon: Icon(Icons.close,
                                          color: U.sub, size: 16),
                                      onPressed: _searchController.clear,
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: () => setState(() {
                              _isSearching = false;
                              _searchController.clear();
                            }),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.outfit(
                                  color: U.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        key: const ValueKey('title'),
                        children: [
                          if (Navigator.canPop(context))
                            IconButton(
                              icon: Icon(Icons.arrow_back_ios_new_rounded,
                                  color: U.text, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => Navigator.pop(context),
                            ),
                          if (Navigator.canPop(context))
                            const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Everyone',
                              style: GoogleFonts.outfit(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: U.text,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                setState(() => _isSearching = true),
                            icon: Icon(Icons.search_rounded,
                                color: U.primary, size: 20),
                            tooltip: 'Search',
                            splashRadius: 20,
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
              ),
            ),

            if (!_isSearching)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Text(
                  widget.universityId != null && widget.universityId!.isNotEmpty
                      ? 'People at your university'
                      : 'Everyone on UTOPIA',
                  style: GoogleFonts.outfit(fontSize: 12, color: U.sub),
                ),
              ),

            const SizedBox(height: 8),
            Divider(color: U.border, height: 1, thickness: 0.5),

            // ── List ────────────────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<Map<String, int>>(
                stream: GameChampionService.topScoreRanksStream(),
                builder: (context, scoreRanksSnap) {
                  return StreamBuilder<Map<String, int>>(
                    stream: GameChampionService.topStreakRanksStream(),
                    builder: (context, streakRanksSnap) {
                      return StreamBuilder<
                          QuerySnapshot<Map<String, dynamic>>>(
                        stream: _buildStream(),
                        builder: (context, snap) {
                          if (snap.connectionState ==
                              ConnectionState.waiting) {
                            return const _LoadingSkeleton();
                          }
                          if (snap.hasError) {
                            debugPrint('EVERYONE SCREEN ERROR: ${snap.error}');
                            return _Empty(
                              icon: Icons.people_outline,
                              title: 'Could not load people',
                              subtitle: 'Try again in a moment.',
                            );
                          }

                          final query = _searchController.text
                              .trim()
                              .toLowerCase();
                          final users = (snap.data?.docs ?? [])
                              .map((d) => {'uid': d.id, ...d.data()})
                              .where((u) {
                            if (u['uid'] == _currentUid) return false;
                            if (query.isEmpty) return true;
                            final name = (u['displayName'] ?? '')
                                .toString()
                                .toLowerCase();
                            final email =
                                (u['email'] ?? '').toString().toLowerCase();
                            return name.contains(query) ||
                                email.contains(query);
                          }).toList();

                          if (users.isEmpty) {
                            return _Empty(
                              icon: Icons.person_search_outlined,
                              title: 'No one found',
                              subtitle: query.isNotEmpty
                                  ? 'Try a different search.'
                                  : 'People will appear here after they sign in.',
                            );
                          }

                          return ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: users.length,
                            separatorBuilder: (_, __) => Divider(
                              color: U.border,
                              height: 1,
                              thickness: 0.5,
                              indent: 72,
                            ),
                            itemBuilder: (context, index) {
                              final user = users[index];
                              final uid = user['uid'].toString();
                              return _EveryoneRow(
                                user: user,
                                currentUid: _currentUid,
                                scoreRank:
                                    scoreRanksSnap.data?[uid],
                                streakRank:
                                    streakRanksSnap.data?[uid],
                                onTap: () {
                                  Navigator.of(context).push(
                                    buildForwardRoute(
                                      UserProfileScreen(
                                        uid: uid,
                                        displayName: (user['displayName'] ??
                                                'Student')
                                            .toString(),
                                        email:
                                            (user['email'] ?? '').toString(),
                                        photoUrl: user['photoUrl']
                                            ?.toString(),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Everyone Row ─────────────────────────────────────────────────────────────

class _EveryoneRow extends StatefulWidget {
  const _EveryoneRow({
    required this.user,
    required this.currentUid,
    this.scoreRank,
    this.streakRank,
    required this.onTap,
  });

  final Map<String, dynamic> user;
  final String currentUid;
  final int? scoreRank;
  final int? streakRank;
  final VoidCallback onTap;

  @override
  State<_EveryoneRow> createState() => _EveryoneRowState();
}

class _EveryoneRowState extends State<_EveryoneRow> {
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
    final displayName =
        (widget.user['displayName'] ?? 'Student').toString();
    final email = (widget.user['email'] ?? '').toString();
    final photoUrl = widget.user['photoUrl']?.toString();
    final bio = (widget.user['bio'] ?? '').toString().trim();

    return InkWell(
      onTap: widget.onTap,
      splashColor: U.primary.withValues(alpha: 0.05),
      highlightColor: U.primary.withValues(alpha: 0.03),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // Avatar
            ChampionAvatarBadge(
              scoreRank: widget.scoreRank,
              streakRank: widget.streakRank,
              email: email,
              child: CircleAvatar(
                radius: 22,
                backgroundColor: U.primary.withValues(alpha: 0.16),
                backgroundImage:
                    photoUrl != null && photoUrl.isNotEmpty
                        ? NetworkImage(photoUrl)
                        : null,
                child: photoUrl == null || photoUrl.isEmpty
                    ? Text(
                        displayName.isEmpty
                            ? 'U'
                            : displayName[0].toUpperCase(),
                        style: GoogleFonts.outfit(
                          color: U.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 14),

            // Name + bio
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ChampionNameText(
                    name: displayName,
                    scoreRank: widget.scoreRank,
                    streakRank: widget.streakRank,
                    email: email,
                    isSuperUser: widget.user['role'] == 'superuser',
                    style: GoogleFonts.outfit(
                      color: U.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (bio.isNotEmpty)
                    Text(
                      bio,
                      style:
                          GoogleFonts.outfit(color: U.sub, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    Text(
                      email,
                      style:
                          GoogleFonts.outfit(color: U.sub, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Follow button (inline)
            StreamBuilder<FollowStatus>(
              stream:
                  _followService.followStatusStream(widget.currentUid, uid),
              builder: (context, statusSnap) {
                final status =
                    statusSnap.data ?? FollowStatus.notFollowing;
                return _InlineFollowButton(
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

class _InlineFollowButton extends StatelessWidget {
  const _InlineFollowButton({
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
        fg = U.text;
        bordered = true;
        break;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: bordered ? Border.all(color: U.border) : null,
        ),
        child: loading
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: U.primary),
              )
            : Text(
                label,
                style: GoogleFonts.outfit(
                  color: fg,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

// ─── Empty / Loading ──────────────────────────────────────────────────────────

class _Empty extends StatelessWidget {
  const _Empty({
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
            Icon(icon, size: 34, color: U.dim),
            const SizedBox(height: 14),
            Text(
              title,
              style: GoogleFonts.outfit(
                  color: U.text, fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(subtitle,
                style: GoogleFonts.outfit(color: U.sub, fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: 8,
      separatorBuilder: (_, __) =>
          Divider(color: U.border, height: 1, thickness: 0.5, indent: 72),
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: const [
            SkeletonBox(height: 44, width: 44, radius: 22),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(height: 14, width: 130, radius: 7),
                  SizedBox(height: 8),
                  SkeletonBox(height: 11, width: 180, radius: 6),
                ],
              ),
            ),
            SizedBox(width: 10),
            SkeletonBox(height: 30, width: 72, radius: 8),
          ],
        ),
      ),
    );
  }
}
