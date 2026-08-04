import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final isSpeaking = _state == VoiceState.speaking;
    final isListening = _state == VoiceState.listening;
    final isProcessing = _state == VoiceState.processing;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 10,
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
