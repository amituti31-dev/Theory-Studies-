import 'package:flutter/material.dart';
import '../models/question.dart';
import '../theme/app_theme.dart';

/// Question text, optional image, and the four answer buttons.
/// [selected] highlights the chosen answer; when [reveal] is true the correct
/// answer is shown in green and a wrong selection in red.
class QuestionView extends StatelessWidget {
  final Question question;
  final int? selected;
  final bool reveal;
  final void Function(int) onSelect;

  const QuestionView({
    super.key,
    required this.question,
    required this.selected,
    required this.reveal,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              children: [
                Text(
                  question.text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                if (question.img != null) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    // Bundled image first; falls back to the gov.il URL if missing
                    child: Image.asset(
                      'assets/images/${question.id}.jpg',
                      height: 220,
                      fit: BoxFit.contain,
                      errorBuilder: (_, e, s) => Image.network(
                        question.img!,
                        height: 220,
                        fit: BoxFit.contain,
                        errorBuilder: (_, e2, s2) => const SizedBox.shrink(),
                        loadingBuilder: (ctx, child, progress) => progress == null
                            ? child
                            : const SizedBox(
                                height: 220,
                                child: Center(child: CircularProgressIndicator()),
                              ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          for (int i = 0; i < question.options.length; i++) ...[
            _OptionButton(
              index: i,
              text: question.options[i],
              state: _stateFor(i),
              onTap: reveal ? null : () => onSelect(i),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  _OptionState _stateFor(int i) {
    if (!reveal) {
      return selected == i ? _OptionState.selected : _OptionState.none;
    }
    if (i == question.correct) return _OptionState.correct;
    if (i == selected) return _OptionState.wrong;
    return _OptionState.none;
  }
}

enum _OptionState { none, selected, correct, wrong }

class _OptionButton extends StatelessWidget {
  final int index;
  final String text;
  final _OptionState state;
  final VoidCallback? onTap;

  const _OptionButton({
    required this.index,
    required this.text,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color border = scheme.outlineVariant;
    Color? fill = scheme.surface;
    Color? textColor;

    switch (state) {
      case _OptionState.selected:
        border = AppColors.primary;
        fill = AppColors.primary.withValues(alpha: 0.08);
        break;
      case _OptionState.correct:
        border = AppColors.success;
        fill = AppColors.success.withValues(alpha: 0.12);
        textColor = AppColors.success;
        break;
      case _OptionState.wrong:
        border = AppColors.error;
        fill = AppColors.error.withValues(alpha: 0.10);
        textColor = AppColors.error;
        break;
      case _OptionState.none:
        break;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: border.withValues(alpha: 0.15),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: textColor ?? scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  color: textColor,
                  fontWeight:
                      state == _OptionState.correct ? FontWeight.w600 : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
