import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/question.dart';
import '../providers/app_provider.dart';
import '../services/progress_service.dart';
import '../services/question_service.dart';
import '../services/voice_service.dart';
import '../theme/app_theme.dart';
import '../widgets/question_view.dart';
import '../widgets/voice_controls.dart';
import 'results_screen.dart';

class ExamScreen extends StatefulWidget {
  const ExamScreen({super.key});

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  static const examDuration = Duration(minutes: 40);

  List<Question> _questions = [];
  final Map<int, int> _answers = {}; // question index -> chosen option
  int _index = 0;
  late DateTime _deadline;
  Timer? _timer;
  Duration _remaining = examDuration;
  bool _voiceEnabled = false;
  final FocusNode _focus = FocusNode();

  Question get _cur => _questions[_index];

  @override
  void initState() {
    super.initState();
    final license = context.read<AppProvider>().license;
    _questions = QuestionService.examSet(license);
    VoiceService.getVoiceEnabled().then((v) {
      if (!mounted || !v) return;
      setState(() => _voiceEnabled = true);
      // Reading is manual only — tap "הקרא" to hear the question.
    });
    _deadline = DateTime.now().add(examDuration);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = _deadline.difference(DateTime.now());
      if (left.isNegative) {
        _submit(timeUp: true);
      } else {
        setState(() => _remaining = left);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    VoiceService.stop();
    _focus.dispose();
    super.dispose();
  }

  void _select(int i) {
    setState(() => _answers[_index] = i);
  }

  void _go(int newIndex) {
    if (newIndex < 0 || newIndex >= _questions.length || newIndex == _index) return;
    setState(() => _index = newIndex);
  }

  void _readCurrent() {
    VoiceService.readQuestion(_cur).then((_) {});
    if (_index + 1 < _questions.length) {
      VoiceService.prefetchQuestion(_questions[_index + 1]);
    }
  }

  Future<void> _submit({bool timeUp = false}) async {
    _timer?.cancel();
    int score = 0;
    for (int i = 0; i < _questions.length; i++) {
      final chosen = _answers[i];
      final correct = chosen == _questions[i].correct;
      if (correct) score++;
      await ProgressService.recordAnswer(_questions[i].id, correct);
    }
    await ProgressService.saveExamScore(score);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultsScreen(
          questions: _questions,
          answers: _answers,
          score: score,
          timeUp: timeUp,
        ),
      ),
    );
  }

  void _confirmSubmit() {
    final unanswered = _questions.length - _answers.length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('הגשת מבחן', textAlign: TextAlign.center),
        content: Text(
          unanswered > 0
              ? 'נותרו $unanswered שאלות ללא מענה. להגיש בכל זאת?'
              : 'להגיש את המבחן?',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ביטול')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _submit();
            },
            child: const Text('הגש'),
          ),
        ],
      ),
    );
  }

  void _onKey(KeyEvent e) {
    if (e is! KeyDownEvent) return;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.digit1 || k == LogicalKeyboardKey.numpad1) _select(0);
    if (k == LogicalKeyboardKey.digit2 || k == LogicalKeyboardKey.numpad2) _select(1);
    if (k == LogicalKeyboardKey.digit3 || k == LogicalKeyboardKey.numpad3) _select(2);
    if (k == LogicalKeyboardKey.digit4 || k == LogicalKeyboardKey.numpad4) _select(3);
    if (k == LogicalKeyboardKey.arrowLeft) _go(_index + 1);
    if (k == LogicalKeyboardKey.arrowRight) _go(_index - 1);
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final lowTime = _remaining.inMinutes < 5;

    return KeyboardListener(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        appBar: AppBar(
          title: Text('מבחן תיאוריה — שאלה ${_index + 1}/30'),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'צא מהמבחן',
            onPressed: () => Navigator.maybePop(context),
          ),
          actions: [
            IconButton(
              tooltip: _voiceEnabled ? 'כבה קול' : 'הפעל קול',
              icon: Icon(_voiceEnabled
                  ? Icons.record_voice_over_rounded
                  : Icons.voice_over_off_rounded),
              onPressed: () {
                setState(() => _voiceEnabled = !_voiceEnabled);
                VoiceService.setVoiceEnabled(_voiceEnabled);
                if (!_voiceEnabled) VoiceService.stop();
              },
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  _fmt(_remaining),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: lowTime ? AppColors.error : null,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question navigator sidebar
                SizedBox(
                  width: 132,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                    child: Column(
                      children: [
                        Expanded(
                          child: GridView.count(
                            crossAxisCount: 4,
                            mainAxisSpacing: 6,
                            crossAxisSpacing: 6,
                            children: [
                              for (int i = 0; i < _questions.length; i++)
                                InkWell(
                                  onTap: () => _go(i),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      color: i == _index
                                          ? AppColors.primary
                                          : _answers.containsKey(i)
                                              ? AppColors.primary.withValues(alpha: 0.15)
                                              : Colors.transparent,
                                      border: Border.all(
                                        color: i == _index
                                            ? AppColors.primary
                                            : Theme.of(context)
                                                .colorScheme
                                                .outlineVariant,
                                      ),
                                    ),
                                    child: Text(
                                      '${i + 1}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: i == _index ? Colors.white : null,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                                backgroundColor: AppColors.success),
                            onPressed: _confirmSubmit,
                            child: const Text('הגש מבחן'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                // Question area
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: QuestionView(
                          question: _cur,
                          selected: _answers[_index],
                          reveal: false,
                          onSelect: _select,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                        child: Column(
                          children: [
                            if (_voiceEnabled)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: VoiceControls(
                                  onReadQuestion: _readCurrent,
                                  onVoiceAnswer: _select,
                                  enabled: true,
                                ),
                              ),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _index > 0 ? () => _go(_index - 1) : null,
                                  icon: const Icon(Icons.arrow_forward_rounded),
                                  label: const Text('הקודמת'),
                                ),
                                const Spacer(),
                                const Text(
                                  '1-4 לבחירה · חצים לניווט',
                                  style: TextStyle(
                                      fontSize: 12, color: AppColors.textSecondary),
                                ),
                                const Spacer(),
                                FilledButton.icon(
                                  onPressed: _index < _questions.length - 1
                                      ? () => _go(_index + 1)
                                      : _confirmSubmit,
                                  icon: const Icon(Icons.arrow_back_rounded),
                                  label: Text(_index < _questions.length - 1
                                      ? 'הבאה'
                                      : 'הגש מבחן'),
                                ),
                              ],
                            ),
                          ],
                        ),
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
}
