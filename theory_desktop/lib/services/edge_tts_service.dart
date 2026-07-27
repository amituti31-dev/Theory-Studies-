import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Natural Hebrew TTS using Microsoft Edge neural voices (Avri/Hila).
///
/// A small Python sidecar (assets/tts_server.py, using the edge-tts package)
/// runs on 127.0.0.1:8179 for the whole session, so each synthesis is a fast
/// local HTTP call (~1s). Questions are prefetched so moving to the next
/// question plays instantly. The installed Windows voice remains the offline
/// fallback (handled by VoiceService).
class EdgeTtsService {
  static const _port = 8179;
  static String voice = 'he-IL-AvriNeural';

  /// User-adjustable speech rate as a percent (-40 slowest .. +40 fastest).
  /// Persisted so the choice survives restarts. Default -5%.
  static int ratePct = -5;
  static const int minRatePct = -40;
  static const int maxRatePct = 40;

  /// The rate formatted for edge-tts, e.g. '+0%', '-5%', '+15%'.
  static String get rate => ratePct >= 0 ? '+$ratePct%' : '$ratePct%';

  /// Loads the saved rate. Call once at launch (VoiceService.init).
  static Future<void> loadRate() async {
    final prefs = await SharedPreferences.getInstance();
    ratePct = prefs.getInt('tts_rate_pct') ?? -5;
  }

  /// Sets and persists the speech rate. Clears the prefetch cache so the
  /// next question is synthesized at the new speed (old audio was cached
  /// at the previous rate).
  static Future<void> setRate(int pct) async {
    ratePct = pct.clamp(minRatePct, maxRatePct);
    _cache.clear();
    _inflight.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('tts_rate_pct', ratePct);
  }

  static final _player = AudioPlayer();
  static bool _busy = false;
  static Process? _server;
  static bool _serverReady = false;
  static int _generation = 0;

  // Small prefetch cache: question text -> synthesized mp3
  static final Map<String, Uint8List> _cache = {};
  static final Map<String, Future<Uint8List?>> _inflight = {};

  static void Function()? onStart;
  static void Function()? onComplete;

  static bool get isBusy => _busy;
  static bool get isReady => _serverReady;

  static String get _scriptPath {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    return '$exeDir\\data\\flutter_assets\\assets\\tts_server.py';
  }

  /// Prefer the Python bundled next to the app (so voice works with no
  /// install); fall back to a system-wide `python` on PATH if not bundled.
  static String get _pythonExe {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final bundled = '$exeDir\\python\\python.exe';
    return File(bundled).existsSync() ? bundled : 'python';
  }

  /// Starts the sidecar (idempotent). Call once at app launch.
  static Future<void> ensureServer() async {
    if (_server != null || _serverReady) return;
    if (!File(_scriptPath).existsSync()) return;
    try {
      _server = await Process.start(
        _pythonExe,
        [_scriptPath],
        mode: ProcessStartMode.detached,
      );
      for (int i = 0; i < 20; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        try {
          final r = await http
              .get(Uri.parse('http://127.0.0.1:$_port/'))
              .timeout(const Duration(seconds: 2));
          if (r.statusCode == 200) {
            _serverReady = true;
            return;
          }
        } catch (_) {}
      }
    } catch (_) {
      _server = null;
    }
  }

  static void shutdown() {
    _server?.kill();
    _server = null;
    _serverReady = false;
  }

  static Future<Uint8List?> _synth(String text) {
    final cached = _cache[text];
    if (cached != null) return Future.value(cached);
    return _inflight.putIfAbsent(text, () async {
      try {
        final r = await http
            .get(Uri.parse('http://127.0.0.1:$_port/tts').replace(
                queryParameters: {'text': text, 'voice': voice, 'rate': rate}))
            .timeout(const Duration(seconds: 25));
        if (r.statusCode == 200 && r.bodyBytes.length > 1000) {
          if (_cache.length > 8) _cache.remove(_cache.keys.first);
          _cache[text] = r.bodyBytes;
          return r.bodyBytes;
        }
      } catch (_) {} finally {
        _inflight.remove(text);
      }
      return null;
    });
  }

  /// Synthesizes [text] in the background so a later [speak] plays instantly.
  static void prefetch(String text) {
    if (!_serverReady || _cache.containsKey(text)) return;
    _synth(text);
  }

  /// Synthesizes [text] and plays it. Returns true on success.
  static Future<bool> speak(String text) async {
    await stop();
    if (!_serverReady) return false;
    _busy = true;
    final myGeneration = _generation;

    try {
      final audio = await _synth(text);
      // Cancelled while synthesizing — don't play, and report success so the
      // caller doesn't fall back and speak the same text again.
      if (myGeneration != _generation) return true;
      if (audio == null) {
        _busy = false;
        return false;
      }

      onStart?.call();
      final completer = Completer<void>();
      late final StreamSubscription sub;
      sub = _player.onPlayerComplete.listen((_) {
        sub.cancel();
        if (!completer.isCompleted) completer.complete();
      });
      await _player.play(BytesSource(audio));
      await completer.future.timeout(const Duration(minutes: 3), onTimeout: () {});
      _busy = false;
      onComplete?.call();
      return true;
    } catch (_) {
      _busy = false;
      return false;
    }
  }

  static Future<void> stop() async {
    _generation++;
    try {
      await _player.stop();
    } catch (_) {}
    _busy = false;
  }
}
