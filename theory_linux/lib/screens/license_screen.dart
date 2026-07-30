import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/question_service.dart';
import '../services/update_service.dart';
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
        LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final cols = w >= 640 ? 4 : 2;
            const gap = 18.0;
            final pad = w * 0.04;
            final cardW = ((w - pad * 2) - gap * (cols - 1)) / cols;
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(pad, 56, pad, 44),
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
                        style:
                            TextStyle(fontSize: 17, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 32),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (final l in _licenses)
                            _LicenseCard(
                              width: cardW,
                              code: l.$1,
                              title: l.$2,
                              subtitle: l.$3,
                              icon: l.$4,
                              color: l.$5,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
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
                  color:
                      isDark ? Colors.indigo.shade200 : AppColors.textSecondary),
            ],
          ),
        ),
        Positioned(
          bottom: 12,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              'v${UpdateService.currentVersion}',
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        ),
      ]),
    );
  }
}

class _LicenseCard extends StatelessWidget {
  final double width;
  final String code, title, subtitle;
  final IconData icon;
  final Color color;

  const _LicenseCard({
    required this.width,
    required this.code,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final count = QuestionService.forLicense(code).length;
    final iconBox = (width * 0.42).clamp(58.0, 130.0);
    final titleSize = (width * 0.13).clamp(17.0, 30.0);
    final subSize = (width * 0.075).clamp(13.0, 19.0);
    final countSize = (width * 0.06).clamp(12.0, 16.0);
    return InkWell(
      onTap: () {
        context.read<AppProvider>().setLicense(code);
        Navigator.pushReplacementNamed(context, '/home');
      },
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: width,
        padding: EdgeInsets.symmetric(vertical: (width * 0.15).clamp(22.0, 48.0)),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.14),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: iconBox,
              height: iconBox,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(iconBox * 0.28),
              ),
              child: Icon(icon, size: iconBox * 0.55, color: color),
            ),
            SizedBox(height: iconBox * 0.22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.bold,
                  color: color),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: subSize, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              '$count שאלות',
              style:
                  TextStyle(fontSize: countSize, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
