import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/edge_tts_service.dart';
import '../theme/app_theme.dart';

/// Side menu with voice + speech-rate + theme controls.
class SettingsDrawer extends StatefulWidget {
  final bool voiceEnabled;
  final ValueChanged<bool> onVoiceChanged;
  const SettingsDrawer({
    super.key,
    required this.voiceEnabled,
    required this.onVoiceChanged,
  });

  @override
  State<SettingsDrawer> createState() => _SettingsDrawerState();
}

class _SettingsDrawerState extends State<SettingsDrawer> {
  int _rate = EdgeTtsService.ratePct;

  String _ratePctLabel(int pct) => pct >= 0 ? '+$pct%' : '$pct%';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final isDark = provider.themeMode == ThemeMode.dark;
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text('הגדרות',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary)),
            ),
            const Divider(height: 1),
            SwitchListTile(
              secondary: const Icon(Icons.record_voice_over_rounded),
              title: const Text('הקראה קולית'),
              value: widget.voiceEnabled,
              onChanged: widget.onVoiceChanged,
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  const Icon(Icons.speed_rounded, size: 22),
                  const SizedBox(width: 12),
                  const Text('מהירות הקראה', style: TextStyle(fontSize: 16)),
                  const Spacer(),
                  Text(_ratePctLabel(_rate),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: AppColors.primary)),
                ],
              ),
            ),
            Row(
              children: [
                const SizedBox(width: 16),
                const Text('🐢'),
                Expanded(
                  child: Slider(
                    value: _rate.toDouble(),
                    min: EdgeTtsService.minRatePct.toDouble(),
                    max: EdgeTtsService.maxRatePct.toDouble(),
                    divisions: (EdgeTtsService.maxRatePct -
                            EdgeTtsService.minRatePct) ~/
                        5,
                    label: _ratePctLabel(_rate),
                    onChanged: (v) => setState(() => _rate = (v / 5).round() * 5),
                    onChangeEnd: (v) => EdgeTtsService.setRate(_rate),
                  ),
                ),
                const Text('🐇'),
                const SizedBox(width: 16),
              ],
            ),
            const Divider(height: 1),
            SwitchListTile(
              secondary: Icon(isDark
                  ? Icons.dark_mode_rounded
                  : Icons.light_mode_rounded),
              title: const Text('מצב כהה'),
              value: isDark,
              onChanged: (_) => provider.toggleTheme(),
            ),
          ],
        ),
      ),
    );
  }
}
