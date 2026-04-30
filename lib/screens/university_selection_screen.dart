import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import '../models/university_model.dart';
import '../services/university_service.dart';
import '../services/university_service.dart';

class UniversitySelectionScreen extends StatefulWidget {
  const UniversitySelectionScreen({super.key});

  @override
  State<UniversitySelectionScreen> createState() => _UniversitySelectionScreenState();
}

class _UniversitySelectionScreenState extends State<UniversitySelectionScreen> {
  final UniversityService _universityService = UniversityService();
  final TextEditingController _searchController = TextEditingController();

  List<UniversityModel> _allUniversities = [];
  List<UniversityModel> _filteredUniversities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUniversities();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUniversities() async {
    try {
      final unis = await _universityService.fetchAllUniversities();
      if (mounted) {
        setState(() {
          _allUniversities = unis..sort((a, b) => a.name.compareTo(b.name));
          _filteredUniversities = _allUniversities;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredUniversities = _allUniversities.where((u) {
        return u.name.toLowerCase().contains(query) ||
               u.shortName.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _selectUniversity(UniversityModel uni) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    try {
      showAppLoading();
      await _universityService.setUserSelectedUniversity(user.uid, uni.id);
      
      // Supabase does not need full app clear yet
      
      if (mounted) {
        // Force full app restart by navigating to root and letting AuthGate rebuild
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (route) => false,
        );
      }
    } catch (e) {
      // Handle error
    } finally {
      hideAppLoading();
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: U.bg,
      appBar: AppBar(
        backgroundColor: U.bg,
        elevation: 0,
        title: Text(
          'Universities',
          style: GoogleFonts.outfit(
            color: U.text,
            fontWeight: FontWeight.w600,
            fontSize: 24,
          ),
        ),
        centerTitle: false,
        iconTheme: IconThemeData(color: U.text),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.outfit(color: U.text),
              decoration: InputDecoration(
                hintText: 'Search universities...',
                hintStyle: GoogleFonts.outfit(color: U.sub, fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, color: U.sub, size: 20),
                filled: true,
                fillColor: U.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: U.primary),
                  )
                : _filteredUniversities.isEmpty
                    ? Center(
                        child: Text(
                          'No results found',
                          style: GoogleFonts.outfit(
                            color: U.sub,
                            fontSize: 15,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        itemCount: _filteredUniversities.length,
                        itemBuilder: (context, index) {
                          final uni = _filteredUniversities[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: InkWell(
                              onTap: () => _selectUniversity(uni),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: U.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: U.border.withValues(alpha: 0.5)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: U.bg,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Text(
                                          uni.shortName.isNotEmpty ? uni.shortName.substring(0, 1) : 'U',
                                          style: GoogleFonts.outfit(
                                            color: U.primary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            uni.name,
                                            style: GoogleFonts.outfit(
                                              color: U.text,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (uni.shortName.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              uni.shortName,
                                              style: GoogleFonts.outfit(
                                                color: U.sub,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.chevron_right_rounded, color: U.dim, size: 20),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
