import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/question_service.dart';
import '../theme/app_theme.dart';

class LicenseScreen extends StatelessWidget {
  const LicenseScreen({super.key});

  static const _licenses = [
    ('B', 'רישיון B', 'רכב פרטי', Icons.directions_car_rounded, Color(0xFF1565C0)),
    ('A', 'רישיון A', 'אופנוע', Icons.two_wheeler_rounded, Color(0xFF6A1B9A)),
    ('C1', 'רישיון C1', 'משאית קלה', Icons.local_shipping_rounded, Color(0xFF2E7D32)),
    ('D', 'רישיון D', 'אוטובוס', Icons.directions_bus_rounded, Color(0xFFE65100)),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDark = provider.themeMode == ThemeMode.dark;
    return Scaffold(
      body: Stack(children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Theory Studies',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'בחר סוג רישיון',
                style: TextStyle(fontSize: 17, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 36),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final l in _licenses)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _LicenseCard(
                        code: l.$1,
                        title: l.$2,
                        subtitle: l.$3,
                        icon: l.$4,
                        color: l.$5,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      Positioned(
        top: 20,
        left: 20,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.light_mode_rounded,
                size: 20,
                color: isDark ? AppColors.textSecondary : Colors.amber),
            Switch(
              value: isDark,
              onChanged: (_) => provider.toggleTheme(),
            ),
            Icon(Icons.dark_mode_rounded,
                size: 20,
                color: isDark ? Colors.indigo.shade200 : AppColors.textSecondary),
          ],
        ),
      ),
      ]),
    );
  }
}

class _LicenseCard extends StatelessWidget {
  final String code, title, subtitle;
  final IconData icon;
  final Color color;

  const _LicenseCard({
    required this.code,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final count = QuestionService.forLicense(code).length;
    return InkWell(
      onTap: () {
        context.read<AppProvider>().setLicense(code);
        Navigator.pushReplacementNamed(context, '/home');
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 156,
        padding: const EdgeInsets.symmetric(vertical: 26),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.14),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, size: 34, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              '$count שאלות',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
