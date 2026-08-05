import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';

/// Local Hebrew transcription using whisper.cpp + the ivrit-ai model
/// (the same engine behind the "Mila" tool). Fully offline and private.
///
/// A whisper-server process is started once at app launch so the 1.5GB model
/// stays loaded in memory (GPU when available); each transcription is then a
/// fast local HTTP call.
class LocalSttService {
  static const _port = 8178;
  static final _recorder = AudioRecorder();
  static bool _recording = false;
  static Process? _server;
  static bool _serverReady = false;

  static String get _baseDir =>
      '${Platform.environment['LOCALAPPDATA']}\\TheoryApp\\whisper';
  static String get _modelPath => '$_baseDir\\ggml-ivrit-turbo.bin';

  /// Prefer the CUDA build (GPU); fall back to the CPU build.
  static String? get _serverExe {
    for (final dir in ['$_baseDir\\cuda\\Release', '$_baseDir\\Release']) {
      final exe = '$dir\\whisper-server.exe';
      if (File(exe).existsSync()) return exe;
    }
    return null;
  }

  static bool get isAvailable =>
      _serverExe != null && File(_modelPath).existsSync();

  static bool get isRecording => _recording;

  static Future<bool> get hasPermission => _recorder.hasPermission();

  /// Start the transcription server (idempotent). Call once at app launch.
  static Future<void> ensureServer() async {
    if (!isAvailable || _server != null) return;
    try {
      // Clear any orphaned server from a previous run
      await Process.run('taskkill', ['/F', '/IM', 'whisper-server.exe']);
    } catch (_) {}
    try {
      _server = await Process.start(
        _serverExe!,
        ['-m', _modelPath, '--port', '$_port', '--host', '127.0.0.1'],
        // Fully detached: no stdio pipes (an undrained pipe would fill up
        // and block the server during model-load logging)
        mode: ProcessStartMode.detached,
      );
      // Poll until the server answers (model load takes ~10s)
      for (int i = 0; i < 60; i++) {
        await Future.delayed(const Duration(seconds: 1));
        try {
          await http.get(Uri.parse('http://127.0.0.1:$_port/')).timeout(
                const Duration(seconds: 2),
              );
          _serverReady = true;
          return;
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

  /// The last recording's file path — reused for a Groq fallback if the local
  /// engine fails to transcribe.
  static String get lastRecordingPath =>
      '${Directory.systemTemp.path}\\local_stt_in.wav';

  static Future<void> startRecording() async {
    if (!await _recorder.hasPermission()) return;
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
      path: lastRecordingPath,
    );
    _recording = true;
  }

  static Future<String?> stopAndTranscribe() async {
    if (!_recording) return null;
    final path = await _recorder.stop();
    _recording = false;
    if (path == null) return null;

    final file = File(path);
    if (!file.existsSync() || file.lengthSync() < 1000) return null;
    if (!_serverReady) return null;

    try {
      final req = http.MultipartRequest(
          'POST', Uri.parse('http://127.0.0.1:$_port/inference'))
        ..fields['language'] = 'he'
        ..fields['response_format'] = 'text'
        ..files.add(await http.MultipartFile.fromPath('file', path));

      final streamed = await req.send().timeout(const Duration(seconds: 30));
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode == 200) {
        final text = body.trim();
        if (text.isNotEmpty) return text;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> cancel() async {
    await _recorder.stop();
    _recording = false;
  }
}
