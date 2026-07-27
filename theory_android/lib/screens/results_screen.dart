import 'package:flutter/material.dart';
import '../models/question.dart';
import '../theme/app_theme.dart';
import '../widgets/question_view.dart';

class ResultsScreen extends StatelessWidget {
  final List<Question> questions;
  final Map<int, int> answers;
  final int score;
  final bool timeUp;

  const ResultsScreen({
    super.key,
    required this.questions,
    required this.answers,
    required this.score,
    this.timeUp = false,
  });

  bool get passed => score >= 26;

  @override
  Widget build(BuildContext context) {
    final color = passed ? AppColors.success : AppColors.error;

    return Scaffold(
      appBar: AppBar(title: const Text('תוצאות המבחן')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Column(
                  children: [
                    Icon(
                      passed ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      size: 64,
                      color: color,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      passed ? 'עברת את המבחן! 🎉' : 'לא עברת הפעם',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    if (timeUp) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'הזמן נגמר והמבחן הוגש אוטומטית',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      '$score / 30',
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'ציון עובר: 26 תשובות נכונות',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.home_rounded),
                      label: const Text('חזרה לתפריט'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              if (_wrongIndexes.isNotEmpty) ...[
                const Text(
                  'שאלות שטעית בהן',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                for (final i in _wrongIndexes) _WrongQuestion(q: questions[i], chosen: answers[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<int> get _wrongIndexes => [
        for (int i = 0; i < questions.length; i++)
          if (answers[i] != questions[i].correct) i
      ];
}

class _WrongQuestion extends StatelessWidget {
  final Question q;
  final int? chosen;

  const _WrongQuestion({required this.q, required this.chosen});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(q.text, style: const TextStyle(fontSize: 15)),
          subtitle: Text(
            chosen == null ? 'לא נענתה' : 'התשובה שלך: ${chosen! + 1}',
            style: const TextStyle(fontSize: 12, color: AppColors.error),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                height: 420,
                child: QuestionView(
                  question: q,
                  selected: chosen,
                  reveal: true,
                  onSelect: (_) {},
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
