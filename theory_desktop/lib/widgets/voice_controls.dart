import 'package:flutter/material.dart';
import '../services/edge_tts_service.dart';
import '../services/voice_service.dart';
import '../theme/app_theme.dart';

class VoiceControls extends StatefulWidget {
  final VoidCallback onReadQuestion;
  final void Function(int) onVoiceAnswer;
  final bool enabled;

  const VoiceControls({
    super.key,
    required this.onReadQuestion,
    required this.onVoiceAnswer,
    required this.enabled,
  });

  @override
  State<VoiceControls> createState() => _VoiceControlsState();
}

class _VoiceControlsState extends State<VoiceControls> {
  VoiceState _state = VoiceState.idle;

  @override
  void initState() {
    super.initState();
    VoiceService.onStateChanged = (s) {
      if (mounted) setState(() => _state = s);
    };
  }

  @override
  void dispose() {
    VoiceService.onStateChanged = null;
    super.dispose();
  }

  String _ratePctLabel(int pct) => pct >= 0 ? '+$pct%' : '$pct%';

  void _openSpeedDialog() {
    int pct = EdgeTtsService.ratePct;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('מהירות הקראה', textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _ratePctLabel(pct),
                style:
                    const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              Slider(
                value: pct.toDouble(),
                min: EdgeTtsService.minRatePct.toDouble(),
                max: EdgeTtsService.maxRatePct.toDouble(),
                divisions:
                    (EdgeTtsService.maxRatePct - EdgeTtsService.minRatePct) ~/ 5,
                label: _ratePctLabel(pct),
                onChanged: (v) => setLocal(() => pct = (v / 5).round() * 5),
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Text('🐢 איטי'), Text('מהיר 🐇')],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  await EdgeTtsService.setRate(pct);
                  if (mounted) setState(() {});
                  await VoiceService.speak('זוהי מהירות ההקראה שבחרת');
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('השמע דוגמה'),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () async {
                await EdgeTtsService.setRate(pct);
                if (mounted) setState(() {});
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('שמור וסגור'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSpeaking = _state == VoiceState.speaking;
    final isListening = _state == VoiceState.listening;
    final isProcessing = _state == VoiceState.processing;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: () {
            if (isSpeaking) {
              VoiceService.stop();
            } else {
              widget.onReadQuestion();
            }
          },
          icon: Icon(isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded),
          label: Text(isSpeaking ? 'עצור הקראה' : 'הקרא שאלה'),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: _openSpeedDialog,
          icon: const Icon(Icons.speed_rounded),
          label: Text('מהירות ${_ratePctLabel(EdgeTtsService.ratePct)}'),
        ),
        const SizedBox(width: 12),
        if (isProcessing)
          const OutlinedButton(
            onPressed: null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('מעבד...'),
              ],
            ),
          )
        else
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: isListening ? AppColors.error : AppColors.success,
            ),
            onPressed: widget.enabled
                ? () async {
                    if (isListening) {
                      VoiceService.stopListening();
                      return;
                    }
                    if (!await VoiceService.micAvailable()) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'לא נמצא מיקרופון מחובר — חבר מיקרופון או אוזניות כדי לענות בקול',
                              textDirection: TextDirection.rtl,
                            ),
                          ),
                        );
                      }
                      return;
                    }
                    VoiceService.startListening(onResult: widget.onVoiceAnswer);
                  }
                : null,
            icon: Icon(isListening ? Icons.mic_rounded : Icons.mic_none_rounded),
            label: Text(isListening ? 'מקשיב... (אמור 1-4)' : 'ענה בקול'),
          ),
      ],
    );
  }
}
