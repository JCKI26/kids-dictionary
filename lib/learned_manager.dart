import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LearnedManager {
  static final LearnedManager _instance = LearnedManager._internal();
  factory LearnedManager() => _instance;
  LearnedManager._internal();

  static const String _key = 'learned_words';
  Set<String> _learned = {};
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      final List<dynamic> list = json.decode(jsonStr);
      _learned = list.whereType<String>().map((e) => e.toLowerCase()).toSet();
    }
    _loaded = true;
  }

  Future<Set<String>> getLearned() async {
    await _ensureLoaded();
    return Set<String>.from(_learned);
  }

  Future<bool> isLearned(String word) async {
    await _ensureLoaded();
    return _learned.contains(word.toLowerCase());
  }

  Future<void> toggleLearned(String word) async {
    await _ensureLoaded();
    final key = word.toLowerCase();
    if (_learned.contains(key)) {
      _learned.remove(key);
    } else {
      _learned.add(key);
    }
    await _save();
  }

  Future<void> setLearned(String word, bool learned) async {
    await _ensureLoaded();
    final key = word.toLowerCase();
    if (learned) {
      _learned.add(key);
    } else {
      _learned.remove(key);
    }
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _learned.toList();
    await prefs.setString(_key, json.encode(list));
  }
}
