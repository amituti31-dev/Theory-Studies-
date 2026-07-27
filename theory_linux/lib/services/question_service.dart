import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/question.dart';

class QuestionService {
  static List<Question> _all = [];

  static List<Question> get all => _all;

  static Future<void> load() async {
    if (_all.isNotEmpty) return;
    final raw = await rootBundle.loadString('assets/questions.json');
    final list = json.decode(raw) as List;
    _all = list.map((e) => Question.fromJson(e as Map<String, dynamic>)).toList();
  }

  static List<Question> forLicense(String license) =>
      _all.where((q) => q.licenses.contains(license)).toList();

  static List<String> categoriesFor(String license) {
    final cats = forLicense(license).map((q) => q.category).toSet().toList();
    cats.sort();
    return cats;
  }

  static Future<List<Question>> practiceSet(
    String license, {
    String? category,
    List<int>? onlyIds,
    int count = 20,
  }) async {
    var pool = forLicense(license);
    if (category != null) pool = pool.where((q) => q.category == category).toList();
    if (onlyIds != null) {
      final idSet = onlyIds.toSet();
      pool = pool.where((q) => idSet.contains(q.id)).toList();
    }

    // Rotation: prefer questions not seen in recent sessions, so repeated
    // practice cycles through the whole pool instead of repeating.
    final prefs = await SharedPreferences.getInstance();
    final recentKey = 'recent_qids_$license';
    final recent = (prefs.getStringList(recentKey) ?? []).map(int.parse).toSet();

    final rnd = Random();
    final fresh = pool.where((q) => !recent.contains(q.id)).toList()..shuffle(rnd);
    final seen = pool.where((q) => recent.contains(q.id)).toList()..shuffle(rnd);
    final chosen = [...fresh, ...seen].take(count).toList()..shuffle(rnd);

    // Remember what was served; reset the cycle when most of the pool is used
    final updated = {...recent, ...chosen.map((q) => q.id)};
    if (updated.length >= pool.length * 0.9) {
      await prefs.setStringList(recentKey, chosen.map((q) => q.id.toString()).toList());
    } else {
      await prefs.setStringList(recentKey, updated.map((e) => e.toString()).toList());
    }

    return chosen;
  }

  static List<Question> examSet(String license) {
    final pool = forLicense(license)..shuffle(Random());
    return pool.take(30).toList();
  }
}
