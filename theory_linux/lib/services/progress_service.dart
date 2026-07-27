import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ProgressService {
  static const _wrongKey = 'wrong_counts';
  static const _totalKey = 'total_practiced';
  static const _correctKey = 'total_correct';
  static const _lastExamKey = 'last_exam_score';
  static const _examHistoryKey = 'exam_history';

  static Future<Map<int, int>> getWrongCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_wrongKey);
    if (raw == null) return {};
    final map = json.decode(raw) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(int.parse(k), v as int));
  }

  static Future<void> recordAnswer(int questionId, bool isCorrect) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt(_totalKey, (prefs.getInt(_totalKey) ?? 0) + 1);

    final counts = await getWrongCounts();
    if (isCorrect) {
      await prefs.setInt(_correctKey, (prefs.getInt(_correctKey) ?? 0) + 1);
      if (counts.containsKey(questionId)) {
        counts[questionId] = (counts[questionId]! - 1).clamp(0, 99);
        if (counts[questionId] == 0) counts.remove(questionId);
        await _saveCounts(prefs, counts);
      }
    } else {
      counts[questionId] = (counts[questionId] ?? 0) + 1;
      await _saveCounts(prefs, counts);
    }
  }

  static Future<void> _saveCounts(SharedPreferences prefs, Map<int, int> counts) async {
    await prefs.setString(
        _wrongKey, json.encode(counts.map((k, v) => MapEntry(k.toString(), v))));
  }

  static Future<List<int>> getWeakQuestionIds({int minWrong = 1}) async {
    final counts = await getWrongCounts();
    final entries = counts.entries.where((e) => e.value >= minWrong).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => e.key).toList();
  }

  static Future<void> saveExamScore(int score) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastExamKey, score);
    final history = prefs.getStringList(_examHistoryKey) ?? [];
    history.add(score.toString());
    if (history.length > 50) history.removeAt(0);
    await prefs.setStringList(_examHistoryKey, history);
  }

  static Future<List<int>> getExamHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_examHistoryKey) ?? [])
        .map(int.parse)
        .toList();
  }

  static Future<Map<String, int>> getStats() async {
    final prefs = await SharedPreferences.getInstance();
    final counts = await getWrongCounts();
    return {
      'total': prefs.getInt(_totalKey) ?? 0,
      'correct': prefs.getInt(_correctKey) ?? 0,
      'weak': counts.length,
      'lastExam': prefs.getInt(_lastExamKey) ?? -1,
    };
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_wrongKey);
    await prefs.remove(_totalKey);
    await prefs.remove(_correctKey);
    await prefs.remove(_lastExamKey);
    await prefs.remove(_examHistoryKey);
  }
}
