import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import '../services/chat_emoji_catalog.dart';
import '../services/chat_service.dart';
import '../services/game_champion_service.dart';
import '../services/sciwordle_service.dart';
import '../widgets/app_motion.dart';
import '../widgets/game_champion_badge.dart';
import 'chat_screen.dart';
import 'map_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final ChatService _chatService = ChatService();
  final SciwordleService _sciService = SciwordleService();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream;
  StreamSubscription<Map<String, Map<String, dynamic>>>?
  _recentChatsSubscription;
  Map<String, Map<String, dynamic>> _recentChats = const {};
  Map<String, int> _streaks = {};

  @override
  void initState() {
    super.initState();
    _usersStream = _chatService.usersStream();
    _recentChatsSubscription = _chatService.recentChatsStream().listen((value) {
      if (!mounted) return;
      setState(() => _recentChats = value);
    });
    _loadStreaks();
  }

  Future<void> _loadStreaks() async {
    final leaderboard = await _sciService.fetchLeaderboard();
    final streakMap = <String, int>{};
    for (final entry in leaderboard) {
      streakMap[entry.uid] = entry.streak;
    }
    if (mounted) setState(() => _streaks = streakMap);
  }

  @override
  void dispose() {
    _recentChatsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: U.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Friends',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: U.text,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // TODO: Implement search functionality or screen
                    },
                    icon: Icon(
                      Icons.search_rounded,
                      color: U.primary,
                      size: 20,
                    ),
                    tooltip: 'Search',
                    splashRadius: 20,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _usersStream,
                builder: (context, snapshot) {
                  final total = snapshot.data?.docs
                      .where((doc) => doc.id != currentUid)
                      .length;
                  final countText = total != null && total > 0
                      ? '  •  $total people'
                      : '';
                  return Text(
                    'Everyone using UTOPIA$countText',
                    style: GoogleFonts.outfit(fontSize: 12, color: U.sub),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MapScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: U.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: U.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.map_rounded, color: U.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Utopia Map',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w600,
                                color: U.primary,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'See where your friends are right now',
                              style: GoogleFonts.outfit(
                                color: U.primary.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: U.primary, size: 20),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Divider(color: U.border, height: 1, thickness: 0.5),
            Expanded(
              child: StreamBuilder<Map<String, int>>(
                stream: GameChampionService.topScoreRanksStream(),
                builder: (context, scoreRanksSnapshot) {
                  return StreamBuilder<Map<String, int>>(
                    stream: GameChampionService.topStreakRanksStream(),
                    builder: (context, streakRanksSnapshot) {
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _usersStream,
                        builder: (context, usersSnapshot) {
                          if (usersSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const _FriendsSkeleton();
                          }

                          if (usersSnapshot.hasError) {
                            return const _FriendsEmptyState(
                              icon: Icons.people_outline,
                              title: 'Could not load people',
                              subtitle: 'Try again in a moment.',
                            );
                          }

                          final users =
                              usersSnapshot.data?.docs
                                  .map((doc) => {'uid': doc.id, ...doc.data()})
                                  .where((user) => user['uid'] != currentUid)
                                  .toList() ??
                              <Map<String, dynamic>>[];

                          users.sort((a, b) {
                            final chatMetaA =
                                _recentChats[_chatService.chatIdFor(
                                  currentUid,
                                  a['uid'].toString(),
                                )];
                            final chatMetaB =
                                _recentChats[_chatService.chatIdFor(
                                  currentUid,
                                  b['uid'].toString(),
                                )];
                            final timeA =
                                chatMetaA?['lastMessageTime'] as Timestamp?;
                            final timeB =
                                chatMetaB?['lastMessageTime'] as Timestamp?;
                            if (timeA != null && timeB != null)
                              return timeB.compareTo(timeA);
                            if (timeA != null) return -1;
                            if (timeB != null) return 1;
                            final nameA = (a['displayName'] ?? '')
                                .toString()
                                .toLowerCase();
                            final nameB = (b['displayName'] ?? '')
                                .toString()
                                .toLowerCase();
                            return nameA.compareTo(nameB);
                          });

                          if (users.isEmpty) {
                            return const _FriendsEmptyState(
                              icon: Icons.person_search_outlined,
                              title: 'No users found',
                              subtitle:
                                  'People will appear here after they sign in.',
                            );
                          }

                          return ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: users.length,
                            separatorBuilder: (context, index) => Divider(
                              color: U.border,
                              height: 1,
                              thickness: 0.5,
                              indent: 72,
                            ),
                            itemBuilder: (context, index) {
                              final user = users[index];
                              final chatMeta =
                                  _recentChats[_chatService.chatIdFor(
                                    currentUid,
                                    user['uid'].toString(),
                                  )];
                              return _FriendRow(
                                user: user,
                                scoreRank: scoreRanksSnapshot
                                    .data?[user['uid'].toString()],
                                streakRank: streakRanksSnapshot
                                    .data?[user['uid'].toString()],
                                streak: _streaks[user['uid'].toString()] ?? 0,
                                chatMeta: chatMeta,
                                onTap: () {
                                  Navigator.of(context).push(
                                    buildForwardRoute(
                                      ChatScreen(
                                        otherUserId: user['uid'].toString(),
                                        displayName:
                                            (user['displayName'] ?? 'Friend')
                                                .toString(),
                                        email: (user['email'] ?? '').toString(),
                                        photoUrl: user['photoUrl']?.toString(),
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

class _FriendRow extends StatelessWidget {
  const _FriendRow({
    required this.user,
    this.scoreRank,
    this.streakRank,
    required this.streak,
    required this.chatMeta,
    required this.onTap,
  });

  final Map<String, dynamic> user;
  final int? scoreRank;
  final int? streakRank;
  final int streak;
  final Map<String, dynamic>? chatMeta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayName = (user['displayName'] ?? 'Friend').toString();
    final email = (user['email'] ?? '').toString();
    final photoUrl = user['photoUrl']?.toString();
    final lastSeen = user['lastSeen'];
    final lastMessageRaw = (chatMeta?['lastMessageRaw'] ?? '').toString();
    final lastMessagePreview = (chatMeta?['lastMessage'] ?? '').toString();
    final isOnline =
        lastSeen is Timestamp &&
        DateTime.now().difference(lastSeen.toDate()) <=
            const Duration(minutes: 5);

    return InkWell(
      onTap: onTap,
      splashColor: U.primary.withValues(alpha: 0.05),
      highlightColor: U.primary.withValues(alpha: 0.03),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ChampionAvatarBadge(
                  scoreRank: scoreRank,
                  streakRank: streakRank,
                  email: email,
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: U.primary.withValues(alpha: 0.16),
                    backgroundImage: photoUrl != null && photoUrl.isNotEmpty
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
                if (isOnline)
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: U.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: U.bg, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ChampionNameText(
                    name: displayName,
                    scoreRank: scoreRank,
                    streakRank: streakRank,
                    email: email,
                    style: GoogleFonts.outfit(
                      color: U.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  lastMessageRaw.isNotEmpty
                      ? ChatEmojiCatalog.buildInlinePreview(
                          lastMessageRaw,
                          fontSize: 12,
                          textColor: U.sub,
                          emojiSize: 16,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : Text(
                          lastMessagePreview.isNotEmpty
                              ? lastMessagePreview
                              : email,
                          style: GoogleFonts.outfit(color: U.sub, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (streak > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 2),
                      Text(
                        '$streak',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFF9E2AF),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 2),
                Text(
                  isOnline ? 'Online' : _lastSeenLabel(lastSeen),
                  style: GoogleFonts.outfit(
                    color: isOnline ? U.green : U.sub,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _lastSeenLabel(dynamic raw) {
    if (raw is! Timestamp) return 'Offline';
    final diff = DateTime.now().difference(raw.toDate());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _FriendsSkeleton extends StatelessWidget {
  const _FriendsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: 8,
      separatorBuilder: (context, index) =>
          Divider(color: U.border, height: 1, thickness: 0.5, indent: 72),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: const [
              SkeletonBox(height: 44, width: 44, radius: 22),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(height: 16, width: 140, radius: 8),
                    SizedBox(height: 8),
                    SkeletonBox(height: 12, width: 180, radius: 8),
                  ],
                ),
              ),
              SizedBox(width: 12),
              SkeletonBox(height: 12, width: 52, radius: 8),
            ],
          ),
        );
      },
    );
  }
}

class _FriendsEmptyState extends StatelessWidget {
  const _FriendsEmptyState({
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
                color: U.text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
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
