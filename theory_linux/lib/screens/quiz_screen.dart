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

enum QuizMode { random, category, weak }

class QuizScreen extends StatefulWidget {
  final QuizMode mode;
  final String? category;

  const QuizScreen({super.key, required this.mode, this.category});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<Question> _questions = [];
  int _index = 0;
  int? _selected;
  bool _reveal = false;
  int _correctCount = 0;
  bool _voiceEnabled = false;
  final FocusNode _focus = FocusNode();

  Question get _cur => _questions[_index];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final license = context.read<AppProvider>().license;
    List<Question> qs;
    if (widget.mode == QuizMode.weak) {
      final weakIds = await ProgressService.getWeakQuestionIds();
      qs = await QuestionService.practiceSet(license, onlyIds: weakIds);
    } else if (widget.mode == QuizMode.random) {
      qs = await QuestionService.practiceSet(license, count: 50);
    } else {
      qs = await QuestionService.practiceSet(license, category: widget.category);
    }
    final voiceOn = await VoiceService.getVoiceEnabled();
    if (!mounted) return;
    setState(() {
      _questions = qs;
      _voiceEnabled = voiceOn;
    });
    if (_voiceEnabled && qs.isNotEmpty) _readCurrent();
  }

  @override
  void dispose() {
    VoiceService.stop();
    _focus.dispose();
    super.dispose();
  }

  void _select(int i) {
    if (_reveal || _questions.isEmpty) return;
    setState(() {
      _selected = i;
      _reveal = true;
      if (i == _cur.correct) _correctCount++;
    });
    ProgressService.recordAnswer(_cur.id, i == _cur.correct);
    if (_voiceEnabled) {
      VoiceService.speak(i == _cur.correct
          ? 'נכון!'
          : 'טעות. התשובה הנכונה היא ${_cur.correct + 1}');
    }
  }

  void _next() {
    if (!_reveal) return;
    if (_index + 1 >= _questions.length) {
      _finish();
      return;
    }
    setState(() {
      _index++;
      _selected = null;
      _reveal = false;
    });
    if (_voiceEnabled) _readCurrent();
  }

  void _readCurrent() {
    VoiceService.readQuestion(_cur).then((_) {});
    if (_index + 1 < _questions.length) {
      VoiceService.prefetchQuestion(_questions[_index + 1]);
    }
  }

  void _finish() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('סיום תרגול', textAlign: TextAlign.center),
        content: Text(
          'ענית נכון על $_correctCount מתוך ${_questions.length} שאלות',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('חזרה לתפריט'),
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
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.space) _next();
  }

  String get _title => switch (widget.mode) {
        QuizMode.random => 'תרגול חופשי',
        QuizMode.category => widget.category ?? 'תרגול לפי נושא',
        QuizMode.weak => 'שאלות חלשות',
      };

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_title)),
        body: Center(
          child: widget.mode == QuizMode.weak
              ? const Text(
                  'אין שאלות חלשות — כל הכבוד! 🎉\nתרגל עוד כדי לאתר נקודות חולשה.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17),
                )
              : const CircularProgressIndicator(),
        ),
      );
    }

    return KeyboardListener(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        appBar: AppBar(
          title: Text('$_title — ${_index + 1}/${_questions.length}'),
          actions: [
            IconButton(
              tooltip: _voiceEnabled ? 'כבה קול' : 'הפעל קול',
              icon: Icon(_voiceEnabled
                  ? Icons.record_voice_over_rounded
                  : Icons.voice_over_off_rounded),
              onPressed: () {
                setState(() => _voiceEnabled = !_voiceEnabled);
                VoiceService.setVoiceEnabled(_voiceEnabled);
                if (_voiceEnabled) {
                  _readCurrent();
                } else {
                  VoiceService.stop();
                }
              },
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: (_index + (_reveal ? 1 : 0)) / _questions.length,
                  minHeight: 4,
                ),
                Expanded(
                  child: QuestionView(
                    question: _cur,
                    selected: _selected,
                    reveal: _reveal,
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
                            enabled: !_reveal,
                          ),
                        ),
                      Row(
                        children: [
                          const Text(
                            'מקשים 1-4 לבחירה · Enter להמשך',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: _reveal ? _next : null,
                            icon: const Icon(Icons.arrow_back_rounded),
                            label: Text(_index + 1 >= _questions.length
                                ? 'סיים תרגול'
                                : 'השאלה הבאה'),
                          ),
                        ],
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
