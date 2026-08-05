import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import '../services/progress_service.dart';
import '../services/question_service.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import 'quiz_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, int> _stats = {};

  @override
  void initState() {
    super.initState();
    _loadStats();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    final update = await UpdateService.checkForUpdate();
    if (update == null || !mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('עדכון זמין 🎉', textAlign: TextAlign.center),
        content: Text(
          'יצאה גרסה חדשה (${update.version}). רוצה להוריד אותה?',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('אחר כך'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final uri = Uri.parse(update.url);
              // Don't gate on canLaunchUrl — it wrongly returns false on some
              // platforms and the click would silently do nothing.
              try {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (_) {
                try {
                  await launchUrl(uri, mode: LaunchMode.platformDefault);
                } catch (_) {}
              }
            },
            child: const Text('הורד עדכון'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadStats() async {
    final s = await ProgressService.getStats();
    if (mounted) setState(() => _stats = s);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final license = provider.license;

    return Scaffold(
      appBar: AppBar(
        title: Text('Theory Studies — רישיון $license'),
        leading: IconButton(
          tooltip: 'החלף רישיון',
          icon: const Icon(Icons.swap_horiz_rounded),
          onPressed: () => Navigator.pushReplacementNamed(context, '/'),
        ),
        actions: [
          IconButton(
            tooltip: 'מצב כהה',
            icon: Icon(provider.themeMode == ThemeMode.dark
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded),
            onPressed: provider.toggleTheme,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                if (_stats.isNotEmpty) _StatsBar(stats: _stats),
                const SizedBox(height: 24),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 18,
                    crossAxisSpacing: 18,
                    childAspectRatio: 1.9,
                    children: [
                      _ModeCard(
                        title: 'תרגול חופשי',
                        subtitle: '50 שאלות מתחלפות',
                        icon: Icons.shuffle_rounded,
                        color: AppColors.primary,
                        onTap: () => _startQuiz(context, QuizMode.random),
                      ),
                      _ModeCard(
                        title: 'תרגול לפי נושא',
                        subtitle: 'בחר קטגוריה',
                        icon: Icons.category_rounded,
                        color: const Color(0xFF6A1B9A),
                        onTap: () => _pickCategory(context),
                      ),
                      _ModeCard(
                        title: 'שאלות חלשות',
                        subtitle: 'שאלות שטעית בהן',
                        icon: Icons.tips_and_updates_rounded,
                        color: AppColors.warning,
                        onTap: () => _startQuiz(context, QuizMode.weak),
                      ),
                      _ModeCard(
                        title: 'מבחן תיאוריה',
                        subtitle: '30 שאלות · 40 דקות · עובר ב-26',
                        icon: Icons.assignment_rounded,
                        color: AppColors.success,
                        onTap: () => Navigator.pushNamed(context, '/exam')
                            .then((_) => _loadStats()),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startQuiz(BuildContext context, QuizMode mode, {String? category}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(mode: mode, category: category),
      ),
    );
    _loadStats();
  }

  Future<void> _pickCategory(BuildContext context) async {
    final license = context.read<AppProvider>().license;
    final cats = QuestionService.categoriesFor(license);
    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('בחר נושא', textAlign: TextAlign.center),
        children: [
          for (final c in cats)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, c),
              child: Text(c, style: const TextStyle(fontSize: 16)),
            ),
        ],
      ),
    );
    if (chosen != null && context.mounted) {
      _startQuiz(context, QuizMode.category, category: chosen);
    }
  }
}

class _StatsBar extends StatelessWidget {
  final Map<String, int> stats;
  const _StatsBar({required this.stats});

  @override
  Widget build(BuildContext context) {
    final total = stats['total'] ?? 0;
    final correct = stats['correct'] ?? 0;
    final pct = total == 0 ? 0 : (correct * 100 ~/ total);
    final lastExam = stats['lastExam'] ?? -1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(label: 'שאלות שתורגלו', value: '$total'),
          _Stat(label: 'אחוז הצלחה', value: total == 0 ? '—' : '$pct%'),
          _Stat(label: 'שאלות חלשות', value: '${stats['weak'] ?? 0}'),
          _Stat(
            label: 'מבחן אחרון',
            value: lastExam < 0 ? '—' : '$lastExam/30',
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
