import 'package:flutter/material.dart';

/// The end of a practice session: a ring filled to [correct]/[total] that
/// counts up once, with the next step pinned to the bottom.
class ScoreView extends StatelessWidget {
  const ScoreView({
    super.key,
    required this.title,
    required this.correct,
    required this.total,
    required this.caption,
    required this.action,
    required this.onAction,
  });

  final String title;
  final int correct;
  final int total;

  /// What [correct] counts, e.g. "on the first try".
  final String caption;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ratio = total == 0 ? 0.0 : correct / total;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, _) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 32),
                      SizedBox.square(
                        dimension: 200,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CircularProgressIndicator(
                              value: ratio * t,
                              strokeWidth: 14,
                              strokeCap: StrokeCap.round,
                              backgroundColor: scheme.outlineVariant,
                            ),
                            Center(
                              child: Text.rich(
                                TextSpan(
                                  text: '${(correct * t).round()}',
                                  style: theme.textTheme.displayLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: scheme.primary,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: '/$total',
                                      style: theme.textTheme.headlineSmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                                style: const TextStyle(
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        caption,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                onPressed: onAction,
                child: Text(action),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(padding: const EdgeInsets.all(16)),
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to practice'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
