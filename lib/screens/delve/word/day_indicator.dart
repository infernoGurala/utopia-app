import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/delve_theme_provider.dart';

class DayIndicator extends StatelessWidget {
  final int day;
  final int totalCards;
  final int completedCards;

  const DayIndicator({
    super.key,
    required this.day,
    required this.totalCards,
    required this.completedCards,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<DelveThemeProvider>().currentTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          (day == 13 ? 'Test Day' : 'Day $day of 13').toUpperCase(),
          style: TextStyle(
            color: theme.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(totalCards, (index) {
            final isCompleted = index < completedCards;
            return Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? theme.accent : theme.divider,
              ),
            );
          }),
        ),
      ],
    );
  }
}
