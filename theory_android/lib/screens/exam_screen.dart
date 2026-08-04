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
import '../widgets/settings_drawer.dart';
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
  final ScrollController _scroll = ScrollController();
  final Map<LogicalKeyboardKey, Timer> _holdTimers = {};

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
    for (final t in _holdTimers.values) {
      t.cancel();
    }
    _scroll.dispose();
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
        _holdTimers[k]?.cancel();
        _holdTimers[k] = Timer(const Duration(milliseconds: 350), () {
          _holdTimers.remove(k);
          _readAnswer(digit);
        });
        return;
      }
      if (k == LogicalKeyboardKey.arrowLeft) {
        _go(_index + 1);
      } else if (k == LogicalKeyboardKey.arrowRight) {
        _go(_index - 1);
      } else if (k == LogicalKeyboardKey.arrowUp) {
        _scrollBy(-140);
      } else if (k == LogicalKeyboardKey.arrowDown) {
        _scrollBy(140);
      }
    } else if (e is KeyUpEvent && digit != null) {
      final t = _holdTimers.remove(k);
      if (t != null && t.isActive) {
        t.cancel();
        _select(digit);
      }
    }
  }

  String _fmt(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  Widget _sidebar() {
    return SizedBox(
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
                                : Theme.of(context).colorScheme.outlineVariant,
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
                style:
                    FilledButton.styleFrom(backgroundColor: AppColors.success),
                onPressed: _confirmSubmit,
                child: const Text('הגש מבחן'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _questionArea(bool narrow) {
    return Column(
      children: [
        Expanded(
          child: QuestionView(
            question: _cur,
            selected: _answers[_index],
            reveal: false,
            onSelect: _select,
            onLongPress: _readAnswer,
            scrollController: _scroll,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
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
                  if (!narrow) ...[
                    const Text(
                      '1-4 · חצים לניווט · לחיצה ארוכה להקראה',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const Spacer(),
                  ],
                  FilledButton.icon(
                    onPressed: _index < _questions.length - 1
                        ? () => _go(_index + 1)
                        : _confirmSubmit,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: Text(_index < _questions.length - 1 ? 'הבאה' : 'הגש'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final lowTime = _remaining.inMinutes < 5;

    final narrow = MediaQuery.of(context).size.width < 640;

    return KeyboardListener(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        endDrawer: SettingsDrawer(
          voiceEnabled: _voiceEnabled,
          onVoiceChanged: (v) {
            setState(() => _voiceEnabled = v);
            VoiceService.setVoiceEnabled(v);
            if (!v) VoiceService.stop();
          },
        ),
        appBar: AppBar(
          title: Text('מבחן — ${_index + 1}/30'),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'צא מהמבחן',
            onPressed: () => Navigator.maybePop(context),
          ),
          actions: [
            if (narrow)
              IconButton(
                tooltip: 'הגש מבחן',
                icon: const Icon(Icons.check_circle_rounded),
                color: AppColors.success,
                onPressed: _confirmSubmit,
              ),
            Builder(
              builder: (ctx) => IconButton(
                tooltip: 'הגדרות',
                icon: const Icon(Icons.settings_rounded),
                onPressed: () => Scaffold.of(ctx).openEndDrawer(),
              ),
            ),
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
            constraints: BoxConstraints(maxWidth: narrow ? 620 : 980),
            child: narrow
                ? _questionArea(true)
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sidebar(),
                      const VerticalDivider(width: 1),
                      Expanded(child: _questionArea(false)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
