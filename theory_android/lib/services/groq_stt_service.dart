import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';

class GroqSttService {
  // Provided at build time: flutter build ... --dart-define=GROQ_API_KEY=xxx
  // Never hard-code the key here — it must not be committed to source control.
  static const _apiKey  = String.fromEnvironment('GROQ_API_KEY');
  static const _url     = 'https://api.groq.com/openai/v1/audio/transcriptions';
  static const _model   = 'whisper-large-v3-turbo';

  static final _recorder = AudioRecorder();
  static bool _recording = false;

  static bool get isRecording => _recording;

  static Future<bool> get hasPermission => _recorder.hasPermission();

  static Future<void> startRecording() async {
    if (!await _recorder.hasPermission()) return;
    final path = '${Directory.systemTemp.path}/groq_in.wav';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
      path: path,
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

    try {
      final req = http.MultipartRequest('POST', Uri.parse(_url))
        ..headers['Authorization'] = 'Bearer $_apiKey'
        ..fields['model']           = _model
        ..fields['language']        = 'he'
        ..fields['response_format'] = 'text'
        ..files.add(await http.MultipartFile.fromPath('file', path));

      final streamed  = await req.send().timeout(const Duration(seconds: 15));
      final body      = await streamed.stream.bytesToString();
      if (streamed.statusCode == 200) return body.trim();
    } catch (_) {}
    return null;
  }

  /// Transcribes an already-recorded audio file (used as a fallback when the
  /// local whisper engine fails).
  static Future<String?> transcribeFile(String path) async {
    final file = File(path);
    if (!file.existsSync() || file.lengthSync() < 1000) return null;
    try {
      final req = http.MultipartRequest('POST', Uri.parse(_url))
        ..headers['Authorization'] = 'Bearer $_apiKey'
        ..fields['model'] = _model
        ..fields['language'] = 'he'
        ..fields['response_format'] = 'text'
        ..files.add(await http.MultipartFile.fromPath('file', path));
      final streamed = await req.send().timeout(const Duration(seconds: 15));
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode == 200) return body.trim();
    } catch (_) {}
    return null;
  }

  static Future<void> cancel() async {
    await _recorder.stop();
    _recording = false;
  }
}
