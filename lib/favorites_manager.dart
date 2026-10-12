import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesManager {
  static final FavoritesManager _instance = FavoritesManager._internal();
  factory FavoritesManager() => _instance;
  FavoritesManager._internal();

  static const String _key = 'favorite_words';
  Set<String> _favorites = {};
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      final List<dynamic> list = json.decode(jsonStr);
      _favorites = list.whereType<String>().map((e) => e.toLowerCase()).toSet();
    }
    _loaded = true;
  }

  Future<Set<String>> getFavorites() async {
    await _ensureLoaded();
    return Set<String>.from(_favorites);
  }

  Future<bool> isFavorite(String word) async {
    await _ensureLoaded();
    return _favorites.contains(word.toLowerCase());
  }

  Future<void> toggleFavorite(String word) async {
    await _ensureLoaded();
    final key = word.toLowerCase();
    if (_favorites.contains(key)) {
      _favorites.remove(key);
    } else {
      _favorites.add(key);
    }
    await _save();
  }

  Future<void> setFavorite(String word, bool favorite) async {
    await _ensureLoaded();
    final key = word.toLowerCase();
    if (favorite) {
      _favorites.add(key);
    } else {
      _favorites.remove(key);
    }
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _favorites.toList();
    await prefs.setString(_key, json.encode(list));
  }
}
