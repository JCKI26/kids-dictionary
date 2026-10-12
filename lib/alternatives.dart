import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

final Map<String, String> alternativesMap = {};

Future<void> loadAlternatives() async {
  final jsonString = await rootBundle.loadString('assets/alternatives.json');
  final data = jsonDecode(jsonString) as Map<String, dynamic>;
  alternativesMap.clear();
  for (final entry in data.entries) {
    alternativesMap[entry.key] = entry.value as String;
  }
}
