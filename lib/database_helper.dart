import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pinyin/pinyin.dart';
import 'alternatives.dart';

class Meaning {
  final String partOfSpeech;
  final String partOfSpeechCn;
  final String definition;
  final String definitionCn;
  final List<String> definitionPinyin;
  final String example;
  final String exampleCn;
  final List<String> examplePinyin;
  final String? image;
  final String? plural;
  final String? presentTense;
  final String? presentContinuous;
  final String? pastTense;
  final String? pastParticiple;
  final String? adverb;
  final String? nounForm;
  final String? comparative;
  final String? superlative;
  final List<String> synonyms;
  final List<String> antonyms;

  Meaning({
    required this.partOfSpeech,
    required this.partOfSpeechCn,
    required this.definition,
    required this.definitionCn,
    required this.definitionPinyin,
    required this.example,
    required this.exampleCn,
    required this.examplePinyin,
    this.image,
    this.plural,
    this.presentTense,
    this.presentContinuous,
    this.pastTense,
    this.pastParticiple,
    this.adverb,
    this.nounForm,
    this.comparative,
    this.superlative,
    this.synonyms = const [],
    this.antonyms = const [],
  });

  factory Meaning.fromMap(Map<String, dynamic> map) {
    final definitionCn = map['definition_cn'] as String? ?? '';
    final exampleCn = map['example_cn'] as String? ?? '';
    return Meaning(
      partOfSpeech: map['part_of_speech'] as String? ?? '',
      partOfSpeechCn: map['part_of_speech_cn'] as String? ?? '',
      definition: map['definition'] as String? ?? '',
      definitionCn: definitionCn,
      definitionPinyin: WordEntry._toPinyinList(definitionCn),
      example: map['example'] as String? ?? '',
      exampleCn: exampleCn,
      examplePinyin: WordEntry._toPinyinList(exampleCn),
      image: map['image'] as String?,
      plural: map['plural'] as String?,
      presentTense: map['present_tense'] as String?,
      presentContinuous: map['present_continuous'] as String?,
      pastTense: map['past_tense'] as String?,
      pastParticiple: map['past_participle'] as String?,
      adverb: map['adverb'] as String?,
      nounForm: map['noun_form'] as String?,
      comparative: map['comparative'] as String?,
      superlative: map['superlative'] as String?,
      synonyms: WordEntry._toStringList(map['synonyms']),
      antonyms: WordEntry._toStringList(map['antonyms']),
    );
  }
}

class WordEntry {
  final String word;
  final String wordCn;
  final String image;
  final List<String> wordPinyin;
  final List<Meaning> meanings;

  WordEntry({
    required this.word,
    required this.wordCn,
    required this.image,
    required this.wordPinyin,
    required this.meanings,
  });

  factory WordEntry.fromMap(Map<String, dynamic> map) {
    final wordCn = map['word_cn'] as String? ?? '';
    final meaningsJson = map['meanings'] as List<dynamic>? ?? [];
    return WordEntry(
      word: map['word'] as String,
      wordCn: wordCn,
      image: map['image'] as String? ?? '',
      wordPinyin: _toPinyinList(wordCn),
      meanings: meaningsJson
          .map((m) => Meaning.fromMap(m as Map<String, dynamic>))
          .toList(),
    );
  }

  static List<String> _toStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.whereType<String>().toList();
    }
    return [];
  }

  static bool _isChinese(String char) {
    if (char.isEmpty) return false;
    final rune = char.codeUnitAt(0);
    return (rune >= 0x4E00 && rune <= 0x9FFF) ||
        (rune >= 0x3400 && rune <= 0x4DBF) ||
        (rune >= 0xF900 && rune <= 0xFAFF);
  }

  static List<String> _toPinyinList(String text) {
    final result = <String>[];
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (_isChinese(char)) {
        final py = PinyinHelper.getPinyinE(
          char,
          format: PinyinFormat.WITH_TONE_MARK,
          separator: ' ',
        );
        result.add(py.trim());
      }
    }
    return result;
  }
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  DatabaseHelper._privateConstructor();

  static bool _containsChinese(String text) {
    return text.runes.any((r) {
      return (r >= 0x4E00 && r <= 0x9FFF) ||
          (r >= 0x3400 && r <= 0x4DBF) ||
          (r >= 0xF900 && r <= 0xFAFF);
    });
  }

  Future<List<WordEntry>> searchWords(String query) async {
    final lowerQuery = query.toLowerCase().trim();
    final all = await _loadWords();
    final isChineseQuery = _containsChinese(lowerQuery);

    final baseWord = alternativesMap[lowerQuery];
    if (baseWord != null) {
      final baseEntry = all.where((e) => e.word.toLowerCase() == baseWord).toList();
      if (baseEntry.isNotEmpty) return baseEntry;
    }

    if (isChineseQuery) {
      return all.where((entry) {
        if (entry.wordCn.toLowerCase().contains(lowerQuery)) return true;
        return entry.meanings.any((m) {
          if (m.definitionCn.toLowerCase().contains(lowerQuery)) return true;
          if (m.exampleCn.toLowerCase().contains(lowerQuery)) return true;
          return false;
        });
      }).toList()
        ..sort((a, b) => a.word.compareTo(b.word));
    }

    return all
        .where((entry) => entry.word.toLowerCase().startsWith(lowerQuery))
        .toList()
      ..sort((a, b) => a.word.compareTo(b.word));
  }

  Future<List<WordEntry>> getAllWords() async {
    final all = await _loadWords();
    return List<WordEntry>.from(all);
  }

  Future<List<WordEntry>> _loadWords() async {
    final jsonString = await rootBundle.loadString('assets/dictionary.json');
    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList
        .map((item) => WordEntry.fromMap(item as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()));
  }
}
