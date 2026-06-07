import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/delve_word_model.dart';
import '../../../providers/delve_theme_provider.dart';
import 'package:provider/provider.dart';

class WordListTile extends StatelessWidget {
  final Word word;
  final VoidCallback onEdit;

  const WordListTile({
    super.key,
    required this.word,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DelveThemeProvider>().currentTheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.divider),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: theme.textSecondary,
          collapsedIconColor: theme.textSecondary,
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                word.word,
                style: GoogleFonts.marcellus(
                  color: theme.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (word.partOfSpeech != null) ...[
                const SizedBox(width: 8),
                Text(
                  word.partOfSpeech!,
                  style: GoogleFonts.inter(
                    color: theme.accent.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(
            word.meaning,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: theme.textSecondary),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    word.meaning,
                    style: TextStyle(color: theme.text, fontSize: 16),
                  ),
                  if (word.aiMeaning != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'AI Suggestion',
                      style: TextStyle(
                        color: theme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      word.aiMeaning!,
                      style: TextStyle(color: theme.textSecondary, fontSize: 14),
                    ),
                  ],
                  if (word.note != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Note',
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      word.note!,
                      style: TextStyle(color: theme.textSecondary, fontSize: 14),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Edit'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
