import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class WordEntry {
  final String word;
  final String definition;
  final String example;

  WordEntry({required this.word, required this.definition, required this.example});

  Map<String, dynamic> toMap() {
    return {
      'word': word,
      'definition': definition,
      'example': example,
    };
  }

  factory WordEntry.fromMap(Map<String, dynamic> map) {
    return WordEntry(
      word: map['word'] as String,
      definition: map['definition'] as String,
      example: map['example'] as String,
    );
  }
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  DatabaseHelper._privateConstructor();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'kids_dictionary.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE words (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        definition TEXT NOT NULL,
        example TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_word ON words(word)
    ''');

    // Seed from bundled JSON.
    final entries = await _loadSeedWords();
    for (final entry in entries) {
      await db.insert('words', entry.toMap());
    }
  }

  Future<List<WordEntry>> _loadSeedWords() async {
    final jsonString = await rootBundle.loadString('assets/dictionary.json');
    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((item) => WordEntry.fromMap(item as Map<String, dynamic>)).toList();
  }

  Future<List<WordEntry>> searchWords(String query) async {
    final db = await database;
    final lowerQuery = query.toLowerCase();
    final results = await db.query(
      'words',
      where: 'LOWER(word) LIKE ?',
      whereArgs: ['$lowerQuery%'],
      orderBy: 'word ASC',
    );
    return results.map((map) => WordEntry.fromMap(map)).toList();
  }

  Future<List<WordEntry>> getAllWords() async {
    final db = await database;
    final results = await db.query('words', orderBy: 'word ASC');
    return results.map((map) => WordEntry.fromMap(map)).toList();
  }
}
