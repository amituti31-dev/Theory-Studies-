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
import '../widgets/celebration.dart';
import '../widgets/question_view.dart';
import '../widgets/settings_drawer.dart';
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
  final ScrollController _scroll = ScrollController();
  final Map<LogicalKeyboardKey, Timer> _holdTimers = {};

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
    // Reading is manual only — the question is read when the user taps "הקרא".
  }

  @override
  void dispose() {
    VoiceService.stop();
    for (final t in _holdTimers.values) {
      t.cancel();
    }
    _scroll.dispose();
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
    if (i == _cur.correct) {
      final phrase = randomCelebration();
      showCelebration(context, phrase);
      if (_voiceEnabled) VoiceService.speak(phrase);
    } else if (_voiceEnabled) {
      VoiceService.speak('טעות. התשובה הנכונה היא ${_cur.correct + 1}');
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

  int? _digitIndex(LogicalKeyboardKey k) {
    if (k == LogicalKeyboardKey.digit1 || k == LogicalKeyboardKey.numpad1) return 0;
    if (k == LogicalKeyboardKey.digit2 || k == LogicalKeyboardKey.numpad2) return 1;
    if (k == LogicalKeyboardKey.digit3 || k == LogicalKeyboardKey.numpad3) return 2;
    if (k == LogicalKeyboardKey.digit4 || k == LogicalKeyboardKey.numpad4) return 3;
    return null;
  }

  void _scrollBy(double delta) {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      (_scroll.offset + delta).clamp(0.0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
    );
  }

  void _readAnswer(int i) {
    if (i >= 0 && i < _cur.options.length) VoiceService.speak(_cur.options[i]);
  }

  void _onKey(KeyEvent e) {
    final k = e.logicalKey;
    final digit = _digitIndex(k);

    if (e is KeyDownEvent) {
      if (digit != null) {
        // Tap = select, long-press (hold) = read the answer aloud.
        _holdTimers[k]?.cancel();
        _holdTimers[k] = Timer(const Duration(milliseconds: 350), () {
          _holdTimers.remove(k);
          _readAnswer(digit);
        });
        return;
      }
      if (k == LogicalKeyboardKey.arrowLeft ||
          k == LogicalKeyboardKey.enter ||
          k == LogicalKeyboardKey.space) {
        _next();
      } else if (k == LogicalKeyboardKey.arrowUp) {
        _scrollBy(-140);
      } else if (k == LogicalKeyboardKey.arrowDown) {
        _scrollBy(140);
      }
    } else if (e is KeyUpEvent && digit != null) {
      final t = _holdTimers.remove(k);
      if (t != null && t.isActive) {
        t.cancel(); // released quickly = a tap
        _select(digit);
      }
    }
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

    final narrow = MediaQuery.of(context).size.width < 600;
    return KeyboardListener(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        drawer: SettingsDrawer(
          voiceEnabled: _voiceEnabled,
          onVoiceChanged: (v) {
            setState(() => _voiceEnabled = v);
            VoiceService.setVoiceEnabled(v);
            if (!v) VoiceService.stop();
          },
        ),
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
                if (!_voiceEnabled) VoiceService.stop();
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
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
                    onLongPress: _readAnswer,
                    scrollController: _scroll,
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
                      narrow
                          ? SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _reveal ? _next : null,
                                icon: const Icon(Icons.arrow_back_rounded),
                                label: Text(_index + 1 >= _questions.length
                                    ? 'סיים תרגול'
                                    : 'השאלה הבאה'),
                              ),
                            )
                          : Row(
                              children: [
                                const Text(
                                  'מקשים 1-4 · ← לשאלה הבאה · חצים לגלילה · לחיצה ארוכה להקראה',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary),
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
      ),
    );
  }
}
