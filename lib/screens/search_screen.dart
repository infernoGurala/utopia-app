import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../services/search_service.dart';
import '../widgets/app_motion.dart';
import 'note_viewer_screen.dart';

class SearchScreen extends StatefulWidget {
  final String initialQuery;
  const SearchScreen({super.key, this.initialQuery = ''});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _service = SearchService();
  final _controller = TextEditingController();
  List<SearchResult> _results = [];
  bool _searching = false;
  bool _hasSearched = false;
  Timer? _debounce;
  int _searchToken = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.trim().isNotEmpty) {
      _controller.text = widget.initialQuery;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _search(widget.initialQuery, immediate: true);
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () {
      _search(query);
    });
  }

  Future<void> _search(String query, {bool immediate = false}) async {
    if (query.trim().length < 2) {
      setState(() { _results = []; _hasSearched = false; });
      return;
    }
    if (!immediate) {
      _searchToken++;
    }
    final token = _searchToken;
    setState(() { _searching = true; _hasSearched = true; });
    final results = await _service.search(query);
    if (!mounted || token != _searchToken) {
      return;
    }
    setState(() { _results = results; _searching = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: U.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: U.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: U.border),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back_ios_new, color: U.sub, size: 18),
                    ),
                    Icon(Icons.search, color: U.sub, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: true,
                        style: GoogleFonts.outfit(color: U.text, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Search all notes...',
                          hintStyle: GoogleFonts.outfit(color: U.dim),
                          border: InputBorder.none,
                        ),
                        onChanged: _onQueryChanged,
                      ),
                    ),
                    if (_controller.text.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.close, color: U.dim, size: 18),
                        onPressed: () {
                          _controller.clear();
                          setState(() { _results = []; _hasSearched = false; });
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _searching
                  ? ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: const [
                        SkeletonBox(height: 82, margin: EdgeInsets.only(bottom: 10)),
                        SkeletonBox(height: 82, margin: EdgeInsets.only(bottom: 10)),
                        SkeletonBox(height: 82, margin: EdgeInsets.only(bottom: 10)),
                      ],
                    )
                  : !_hasSearched
                      ? Center(child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search, color: U.border, size: 48),
                            const SizedBox(height: 12),
                            Text('Search across all notes',
                              style: GoogleFonts.outfit(color: U.dim, fontSize: 14)),
                            const SizedBox(height: 4),
                            Text('Works offline too',
                              style: GoogleFonts.outfit(color: U.dim.withValues(alpha: 0.6), fontSize: 12)),
                          ],
                        ))
                      : _results.isEmpty
                          ? Center(child: Text('No results found',
                              style: GoogleFonts.outfit(color: U.sub)))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _results.length,
                              itemBuilder: (context, i) {
                                final r = _results[i];
                                return GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    buildForwardRoute(
                                      NoteViewerScreen(
                                        title: r.topic,
                                        filePath: r.topicPath,
                                        folderPath: r.folderPath,
                                        highlightQuery: _controller.text.trim(),
                                      ),
                                    ),
                                  ),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: U.card,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: U.border),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(r.topic, style: GoogleFonts.outfit(
                                          color: U.text, fontSize: 15, fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 2),
                                        Text(r.subject, style: GoogleFonts.outfit(
                                          color: U.primary, fontSize: 12)),
                                        if (r.preview.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Text(r.preview,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.outfit(color: U.sub, fontSize: 12)),
                                        ],
                                      ],
                                    ),
                                  ),
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
