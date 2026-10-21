import 'package:flutter/material.dart';
import 'package:lingua_screen/pages/flash_card_page.dart';
import 'package:lingua_screen/pages/quiz_page.dart';

/// Picks a way to practice the current course's saved vocabs.
class PracticePage extends StatelessWidget {
  const PracticePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        _ModeCard(
          icon: Icons.quiz_outlined,
          title: 'Quiz',
          subtitle: 'Pick the meaning, the reading, or the missing word',
          page: () => const QuizPage(),
        ),
        const SizedBox(height: 12),
        _ModeCard(
          icon: Icons.style_outlined,
          title: 'Flashcards',
          subtitle: 'Recall each word, then turn the card over to check',
          page: () => const FlashCardPage(),
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.page,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget Function() page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => page())),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 12, 20),
          child: Row(
            children: [
              Icon(icon, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
