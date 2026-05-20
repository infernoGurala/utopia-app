import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import '../main.dart';

class LegalPoliciesScreen extends StatefulWidget {
  const LegalPoliciesScreen({super.key});

  @override
  State<LegalPoliciesScreen> createState() => _LegalPoliciesScreenState();
}

class _LegalPoliciesScreenState extends State<LegalPoliciesScreen> {
  int _activeCategoryIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, dynamic>> _legalDocuments = [
    {
      'id': 'terms',
      'title': 'Terms of Service',
      'icon': Icons.description_outlined,
      'color': Colors.blueAccent,
      'summary': 'General guidelines, user responsibilities, and terms for utilizing the UTOPIA platform.',
      'sections': [
        {
          'title': '1. Acceptance of Terms',
          'content': 'By accessing or using UTOPIA, a student-focused productivity application, you agree to comply with and be bound by these Terms of Service. If you do not agree, you must not use or download this application. UTOPIA is created as a purely non-profit, student utility for enhancing academic workflow.',
        },
        {
          'title': '2. Scope of Service',
          'content': 'UTOPIA consolidates academic planning, timetable tools, notes sharing (via Markdown/LaTeX), real-time peer-to-peer chats, attendance monitoring, and the SciWordle academic word game. The services are provided "as is" and are subject to modifications or suspension at any time without prior notice as the developers maintain the app on a voluntary basis.',
        },
        {
          'title': '3. Account & Identity',
          'content': 'To use certain interactive features like campus maps, chat, and leaderboards, you must sign in via your verified Google Account. You are solely responsible for maintaining the privacy and security of your account and for all actions taken under your account profile.',
        },
        {
          'title': '4. Prohibited Student Conduct',
          'content': 'You agree not to use the application for any unlawful purposes or academic misconduct. Prohibited actions include: posting abusive, harassing, or defamatory chat messages; spamming public forums; uploading copyright-infringing study materials; hacking or attempting to reverse-engineer the API keys, database rules, or services; and abusing location sharing systems.',
        },
        {
          'title': '5. Non-Affiliation and Limitations',
          'content': 'UTOPIA is an independent community project created by students. It is NOT officially affiliated with, authorized, maintained, or endorsed by Aditya University, its management, or its portal systems (aec.edu.in). Any reliance on scheduling and academic data presented inside UTOPIA is done at your own academic risk.',
        },
      ]
    },
    {
      'id': 'privacy',
      'title': 'Privacy Policy',
      'icon': Icons.security_outlined,
      'color': Colors.greenAccent,
      'summary': 'How we handle your academic data, encrypted credentials, location info, and messages.',
      'sections': [
        {
          'title': '1. Overview of Data Privacy',
          'content': 'We value your privacy tremendously. UTOPIA is completely cost-free and runs entirely on free-tier cloud infrastructure. We do not sell, rent, or lease your personal data to any third parties. There are absolutely no tracking pixels, advertising frameworks, or telemetry packages embedded in this app.',
        },
        {
          'title': '2. Attendance Portal Credentials',
          'content': 'When logging in to track your college attendance, UTOPIA scrapes details directly from the info.aec.edu.in portal. Your credentials (username and password) are NEVER transmitted to our servers or any intermediate backend. Instead, they are encrypted locally on your device using a strong AES-128-CBC algorithm and stored securely via Android Secure Storage (flutter_secure_storage). They are sent directly to the official portal only during direct scraping operations.',
        },
        {
          'title': '3. Location Sharing (Campus Map)',
          'content': 'The campus mapping feature utilizes GPS coordinates to help you locate classmates on the Aditya University campus. To respect your privacy, location sharing is strictly restricted to campus boundaries and is active ONLY between the hours of 8:00 AM and 10:00 PM IST. Coordinates are shared in real-time via peer-to-peer Firebase Realtime Database. No historical movement logs or location footprints are saved or compiled.',
        },
        {
          'title': '4. Chat & Peer Messages',
          'content': 'Direct one-on-one messages, kawaii-style emojis, and typing states are stored and transmitted securely via Google Cloud Firestore. While messages are stored on cloud servers to enable real-time synchronization and offline support, they are restricted to participants of the conversation. You can edit, reply to, or unsend your messages at any time.',
        },
        {
          'title': '5. Luna AI Assistant',
          'content': 'Luna (the Intelligent Academic Assistant) processes your academic queries. Luna is powered by multi-provider AI frameworks (Groq, Google Gemini, OpenAI). When you interact with Luna, only your current conversation history (last 20 messages) and immediate context (such as your academic subjects, schedule, and study notes) are passed to the AI APIs anonymously. No personal indicators, passwords, or location details are ever shared with the AI providers.',
        },
      ]
    },
    {
      'id': 'disclaimer',
      'title': 'Academic Disclaimer',
      'icon': Icons.gavel_outlined,
      'color': Colors.amberAccent,
      'summary': 'Important information about academic tracking, attendance statistics, and official university status.',
      'sections': [
        {
          'title': '1. Accuracy of Attendance and Schedules',
          'content': 'UTOPIA acts as a convenience dashboard for monitoring academic progress. While the app uses direct web-scraping to fetch subject attendance from your college portal, the official portal (info.aec.edu.in) remains the sole authoritative source of academic records. UTOPIA is not responsible for any sync delays, discrepancies, or incorrect scheduling calculations.',
        },
        {
          'title': '2. Timetable & Schedule Updates',
          'content': 'Timetable coordinates, exam schedules, and holiday announcements are manually updated by designated class representatives (Writers). We cannot guarantee that all timetable entries are completely error-free or updated instantly. Always cross-reference crucial exams and classes with official university notices.',
        },
        {
          'title': '3. Skip Class Calculations ("Can I Skip Class?")',
          'content': 'Luna\'s attendance calculator is intended as a logical model based on the 75% attendance threshold. It serves as a general guide, not an endorsement of truancy or skipping. Students are advised to use their personal discretion. Missing classes may impact your academic standings, grades, or semester evaluations.',
        },
      ]
    },
    {
      'id': 'integrity',
      'title': 'Academic Integrity',
      'icon': Icons.school_outlined,
      'color': Colors.purpleAccent,
      'summary': 'Principles of fair use, collaborative study notes, and intellectual honesty.',
      'sections': [
        {
          'title': '1. Collaborative Notes Sharing',
          'content': 'Study notes, slides, and educational files in the UTOPIA Library are contributed by students and writers for collaborative learning. Users must respect original authors and give proper credit where due. Notes should be used to supplement—not replace—active study, textbooks, and lectures.',
        },
        {
          'title': '2. Copying and Fair Use',
          'content': 'All library attachments (such as PDF guides, reference files, and lecture slides) are cached for offline availability. These files are provided strictly for educational, research, and self-study purposes under standard Fair Use doctrines. Unauthorized commercial redistribution or mass duplication of these study materials is strictly forbidden.',
        },
        {
          'title': '3. Game Integrity (SciWordle)',
          'content': 'SciWordle is our daily science-themed word puzzle. To maintain a healthy and friendly community leaderboard, any attempts to cheat, manipulate memory states, intercept API payloads, or bypass the daily game lock will result in immediate disqualification and removal of user score stats.',
        },
      ]
    },
    {
      'id': 'opensource',
      'title': 'Open Source & Licenses',
      'icon': Icons.code_rounded,
      'color': Colors.tealAccent,
      'summary': 'FOSS licensing terms, package attributions, and cost-free infrastructure.',
      'sections': [
        {
          'title': '1. Open-Source Philosophy',
          'content': 'UTOPIA is a proud free and open-source software (FOSS) project. The app is designed to run efficiently within free tier thresholds on platforms like Firebase, GitHub Actions, and SQLite, demonstrating that robust student productivity solutions can be built with zero operational costs.',
        },
        {
          'title': '2. MIT License Agreement',
          'content': 'The source code of UTOPIA is licensed under the MIT License. You may modify, copy, and distribute the code, provided that proper copyright notices and attribution to the original author (John Moses Gurala) are included. The software is provided "as is", without warranty of any kind.',
        },
        {
          'title': '3. Package Attributions',
          'content': 'We are highly grateful to the Flutter and Dart communities for the open-source libraries that make UTOPIA possible, including:\n• flutter_animate (UI animations)\n• google_fonts (Outfit & Inter typography)\n• sqflite (offline SQL caching)\n• cached_network_image (asset buffering)\n• share_plus (social note segments sharing)\n• flutter_markdown & flutter_math_fork (LaTeX formatting)',
        },
      ]
    }
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _shareDocument(Map<String, dynamic> doc) {
    final String title = doc['title'] as String;
    final List<Map<String, String>> sections = doc['sections'] as List<Map<String, String>>;
    
    String shareText = 'UTOPIA Academic Platform - $title\n\n';
    for (var sec in sections) {
      shareText += '${sec['title']}\n${sec['content']}\n\n';
    }
    shareText += 'Learn more at https://inferalis.space';
    
    Share.share(shareText, subject: 'UTOPIA - $title');
  }

  @override
  Widget build(BuildContext context) {
    final activeDoc = _legalDocuments[_activeCategoryIndex];
    final isDark = appThemeNotifier.value.isDark;

    // Filtered list based on search query
    List<Map<String, String>> filteredSections = [];
    final List<Map<String, String>> allSections = activeDoc['sections'] as List<Map<String, String>>;

    if (_searchQuery.isEmpty) {
      filteredSections = allSections;
    } else {
      filteredSections = allSections.where((section) {
        final titleMatch = section['title']!.toLowerCase().contains(_searchQuery.toLowerCase());
        final contentMatch = section['content']!.toLowerCase().contains(_searchQuery.toLowerCase());
        return titleMatch || contentMatch;
      }).toList();
    }

    return Scaffold(
      backgroundColor: U.bg,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: U.surface,
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Area ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: U.card,
                          shape: BoxShape.circle,
                          border: Border.all(color: U.border),
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: U.text,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Legal & Policies',
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: U.text,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            'Terms, academic guidelines & privacy safety',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: U.sub,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _shareDocument(activeDoc),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: U.card,
                          shape: BoxShape.circle,
                          border: Border.all(color: U.border),
                        ),
                        child: Icon(
                          Icons.share_outlined,
                          color: U.primary,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Categories Tabs ──
              SizedBox(
                height: 48,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _legalDocuments.length,
                  itemBuilder: (context, index) {
                    final doc = _legalDocuments[index];
                    final bool isActive = index == _activeCategoryIndex;
                    final Color accentColor = doc['color'] as Color;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _activeCategoryIndex = index;
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isActive ? accentColor.withValues(alpha: 0.15) : U.card.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isActive ? accentColor.withValues(alpha: 0.4) : U.border,
                              width: isActive ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                doc['icon'] as IconData,
                                size: 16,
                                color: isActive ? accentColor : U.sub,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                doc['title'] as String,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                  color: isActive ? U.text : U.sub,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // ── Search & Filter bar ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: U.card.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: U.border),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                    style: GoogleFonts.outfit(
                      color: U.text,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search within this document...',
                      hintStyle: GoogleFonts.outfit(
                        color: U.dim,
                        fontSize: 13,
                      ),
                      prefixIcon: Icon(Icons.search_rounded, color: U.dim, size: 18),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                });
                              },
                              child: Icon(Icons.close_rounded, color: U.sub, size: 16),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // ── Active Document Info Panel ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: (activeDoc['color'] as Color).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: (activeDoc['color'] as Color).withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (activeDoc['color'] as Color).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          activeDoc['icon'] as IconData,
                          color: activeDoc['color'] as Color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activeDoc['title'] as String,
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: U.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              activeDoc['summary'] as String,
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                color: U.sub,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ── Sections Listing ──
              Expanded(
                child: filteredSections.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.find_in_page_outlined,
                                size: 48,
                                color: U.dim,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No matching sections found',
                                style: GoogleFonts.outfit(
                                  color: U.text,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Try matching alternate keywords or clear search.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  color: U.sub,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 60),
                        itemCount: filteredSections.length,
                        itemBuilder: (context, index) {
                          final section = filteredSections[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: U.card.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: U.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          color: activeDoc['color'] as Color,
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          section['title']!,
                                          style: GoogleFonts.outfit(
                                            color: U.text,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    section['content']!,
                                    style: GoogleFonts.outfit(
                                      color: U.text.withValues(alpha: 0.9),
                                      fontSize: 13.5,
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                              .animate()
                              .fadeIn(duration: 300.ms, delay: (index * 60).ms)
                              .slideY(begin: 0.08, end: 0, duration: 300.ms);
                        },
                      ),
              ),

              // ── Bottom Brand Tag ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: U.surface,
                  border: Border(top: BorderSide(color: U.border)),
                ),
                child: Center(
                  child: Text(
                    'UTOPIA Academic Platform • Trust & Compliance',
                    style: GoogleFonts.outfit(
                      color: U.dim,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
