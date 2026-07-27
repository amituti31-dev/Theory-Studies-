import 'dart:math';
import 'package:flutter/material.dart';

/// Short celebratory phrases shown when the user answers correctly.
const celebrationPhrases = <String>[
  'GREAT SUCCESS!',
  'VERY NICE!',
  'VERY NICE, I LIKE!',
  'TODAY WE HAVE GREAT SUCCESS!',
];

String randomCelebration() =>
    celebrationPhrases[Random().nextInt(celebrationPhrases.length)];

/// Pops a big animated banner with [text] in the center, auto-dismissing.
void showCelebration(BuildContext context, String text) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _CelebrationOverlay(text: text, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _CelebrationOverlay extends StatefulWidget {
  final String text;
  final VoidCallback onDone;
  const _CelebrationOverlay({required this.text, required this.onDone});

  @override
  State<_CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<_CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..forward()
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = Tween(begin: 0.5, end: 1.0).animate(CurvedAnimation(
        parent: _c, curve: const Interval(0.0, 0.3, curve: Curves.elasticOut)));
    final fade = Tween(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _c, curve: const Interval(0.8, 1.0)));
    return IgnorePointer(
      child: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => Opacity(
            opacity: fade.value,
            child: Transform.scale(
              scale: scale.value,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 8)),
                  ],
                ),
                child: Text(
                  widget.text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
