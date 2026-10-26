import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:math';
import 'database_helper.dart';
import 'alternatives.dart';
import 'favorites_manager.dart';
import 'learned_manager.dart';

final FlutterTts _tts = FlutterTts();
String? _selectedEnVoice;
String? _selectedZhVoice;

String? findBaseWord(String query, Set<String> words) {
  final q = query.toLowerCase().trim();
  // Longer suffixes first to avoid over-stripping (e.g., wonderful -> wonder)
  final suffixes = [
    'fulness', 'fully',
    'ness', 'less',
    'ful', 'ly',
    'ing',
    'iest', 'ier', // happiest -> happy, happier -> happy
    'ies', 'ied',
    'es',
    's',
    'ed',
    'er', 'est',
  ];

  for (final suffix in suffixes) {
    if (q.endsWith(suffix) && q.length > suffix.length + 1) {
      final base = q.substring(0, q.length - suffix.length);
      if (words.contains(base)) return base;

      // Handle y -> ie transformations
      if ((suffix == 'ies' || suffix == 'ied' || suffix == 'ier' || suffix == 'iest') &&
          words.contains('${base}y')) {
        return '${base}y';
      }
    }
  }
  return null;
}

Future<void> _initBestVoices() async {
  final voices = await _tts.getVoices;
  if (voices == null) return;

  String? pickVoice(String localePrefix, List<String> preferredNames) {
    for (final name in preferredNames) {
      if (voices.any((v) => v is Map && v['name'].toString() == name)) {
        return name;
      }
    }
    for (final voice in voices) {
      if (voice is Map) {
        final locale = voice['locale']?.toString().toLowerCase() ?? '';
        if (locale.startsWith(localePrefix.toLowerCase())) {
          return voice['name']?.toString();
        }
      }
    }
    return null;
  }

  _selectedEnVoice = pickVoice('en-US', [
    'com.apple.voice.enhanced.en-US.Samantha',
    'com.apple.voice.compact.en-US.Samantha',
    'com.apple.voice.premium.en-US.Allison',
    'com.apple.eloquence.en-US.Shelley',
    'en-US-language',
  ]);

  _selectedZhVoice = pickVoice('zh-CN', [
    'com.apple.voice.enhanced.zh-CN.TingTing',
    'com.apple.voice.compact.zh-CN.TingTing',
    'com.apple.voice.premium.zh-CN.TingTing',
    'zh-CN-language',
  ]);
}

/// Global application settings.

class AppSettings extends ChangeNotifier {
  bool _showChinese = true;
  double _textScale = 1.0;
  bool _darkMode = false;
  bool _onlyImageWords = false;

  bool get showChinese => _showChinese;
  double get textScale => _textScale;
  bool get darkMode => _darkMode;
  bool get onlyImageWords => _onlyImageWords;

  void toggleChinese() {
    _showChinese = !_showChinese;
    notifyListeners();
  }

  void setTextScale(double value) {
    if (_textScale != value) {
      _textScale = value.clamp(0.7, 1.5);
      notifyListeners();
    }
  }

  void toggleDarkMode() {
    _darkMode = !_darkMode;
    notifyListeners();
  }

  void toggleOnlyImageWords() {
    _onlyImageWords = !_onlyImageWords;
    notifyListeners();
  }
}

late final AppSettings appSettings;

List<WordEntry> _withImages(List<WordEntry> entries) {
  return appSettings.onlyImageWords
      ? entries.where((e) {
          return e.meanings.any((m) => m.image?.isNotEmpty == true);
        }).toList()
      : entries;
}

const Set<String> _linkSkipWords = {
  // Articles
  'a', 'an', 'the',
  // Conjunctions
  'and', 'but', 'or', 'nor', 'so', 'yet', 'because', 'although', 'though',
  'while', 'whereas', 'if', 'unless', 'since', 'than', 'whether', 'either', 'neither',
  // Prepositions
  'about', 'above', 'across', 'after', 'against', 'along', 'amid', 'among',
  'around', 'at', 'before', 'behind', 'below', 'beneath', 'beside', 'besides',
  'between', 'beyond', 'by', 'down', 'during',
  'for', 'from', 'in', 'inside', 'into', 'like', 'near', 'of', 'off',
  'on', 'onto', 'opposite', 'out', 'outside', 'over', 'past',
  'round', 'through', 'throughout', 'till', 'to', 'toward', 'towards',
  'under', 'underneath', 'until', 'up', 'upon', 'with', 'within', 'without',
  // Auxiliary / common function words
  'is', 'as', 'can', 'being', 'one', 'having', 'such', 'does', 'do', 'are',
  'cannot', 'doing', 'any', 'who', 'what', 'where', 'that', 'why', 'has',
  'have', 'be', 'will', 'could', 'might', 'should', 'need',
  // Common adverbs / pronouns / polite words / quantifiers
  'other', 'very', 'please', 'now', 'how', 'another', 'thing', 'things', 'all',
  'whole', 'some', 'every', 'there', 'when', 'someone', 'next',
  // CSV pronouns / determiners / adverbs / nouns
  'it', 'i', 'his', 'they', 'this', 'not', 'we', 'your', 'she', 'their', 'them',
  'her', 'him', 'more', 'my', 'its', 'me', 'most', 'our', 'us', 'few',
  'something', 'america', 'you', 'he', 'which', 'whose', 'no',
};

String? _lookupLinkWord(String word, List<WordEntry> entries) {
  final lower = word.toLowerCase();
  if (entries.any((e) => e.word.toLowerCase() == lower)) return lower;
  final base = alternativesMap[lower];
  if (base != null && entries.any((e) => e.word.toLowerCase() == base)) return base;
  _ensureInflectionMap(entries);
  return _inflectionCache?[lower];
}

Map<String, String>? _inflectionCache;

void _ensureInflectionMap(List<WordEntry> entries) {
  if (_inflectionCache != null) return;
  final map = <String, String>{};
  for (final entry in entries) {
    final base = entry.word.toLowerCase();
    for (final meaning in entry.meanings) {
      for (final form in [
        meaning.presentTense,
        meaning.presentContinuous,
        meaning.pastTense,
        meaning.pastParticiple,
        meaning.plural,
        meaning.adverb,
        meaning.nounForm,
        meaning.comparative,
        meaning.superlative,
      ]) {
        if (form != null && form.isNotEmpty) {
          final lower = form.toLowerCase();
          if (lower != base && !_linkSkipWords.contains(lower)) {
            map[lower] = base;
          }
        }
      }
    }
  }
  _inflectionCache = map;
}

Widget _buildRelationChips(
  BuildContext context,
  String label,
  List<String> words,
  List<WordEntry> entries,
  String currentWord,
  double scale,
) {
  if (words.isEmpty) return const SizedBox.shrink();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 16.0 * scale,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
      const SizedBox(height: 6.0),
      Wrap(
        spacing: 8.0,
        runSpacing: 6.0,
        children: words.map((word) {
          final target = _lookupLinkWord(word, entries);
          final isLink = target != null && target != currentWord.toLowerCase();
          final chip = Container(
            padding: EdgeInsets.symmetric(
              horizontal: 12.0 * scale,
              vertical: 6.0 * scale,
            ),
              decoration: BoxDecoration(
              color: label.startsWith('Antonyms')
                  ? (Theme.of(context).brightness == Brightness.dark
                      ? Colors.blue.shade400
                      : Colors.blue.shade300)
                  : (Theme.of(context).brightness == Brightness.dark
                      ? Colors.orange.shade300
                      : Colors.orange.shade100),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Text(
              word,
              style: TextStyle(
                fontSize: 16.0 * scale,
                decoration: isLink ? TextDecoration.underline : null,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          );
          if (!isLink) return chip;
          return InkWell(
            onTap: () {
              final targetIndex = entries.indexWhere(
                (e) => e.word.toLowerCase() == target,
              );
              if (targetIndex != -1) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => WordDetailPage(
                      entry: entries[targetIndex],
                      entries: entries,
                      index: targetIndex,
                    ),
                  ),
                );
              }
            },
            borderRadius: BorderRadius.circular(8.0),
            child: chip,
          );
        }).toList(),
      ),
      const SizedBox(height: 12.0),
    ],
  );
}

Color _posColor(String pos) {
  switch (pos.toLowerCase()) {
    case 'noun':
      return Colors.blue;
    case 'verb':
      return Colors.green;
    case 'adjective':
      return Colors.orange;
    case 'adverb':
      return Colors.purple;
    case 'preposition':
      return Colors.teal;
    case 'conjunction':
      return Colors.pink;
    case 'pronoun':
      return Colors.indigo;
    case 'determiner':
      return Colors.brown;
    default:
      return Colors.grey;
  }
}

/// Build an IconButton whose tooltip shows English in the default app font
/// (Roboto) and optionally appends Chinese in Noto Sans SC when
/// `appSettings.showChinese` is true. Tooltip text is centered and inherits
/// the tooltip theme font size so theme changes take effect.
Widget _buildIconButtonWithMixedTooltip({
  required BuildContext context,
  required String english,
  String? chinese,
  required Widget icon,
  required VoidCallback onPressed,
}) {
  final tooltipStyle = TooltipTheme.of(context).textStyle ?? DefaultTextStyle.of(context).style;
  final List<InlineSpan> spans = [
    TextSpan(
      text: english,
      style: const TextStyle(fontFamily: 'Roboto'),
    ),
  ];
  if (chinese != null && chinese.isNotEmpty && appSettings.showChinese) {
    spans.add(const TextSpan(text: '\n'));
    spans.add(
      TextSpan(
        text: chinese,
        style: GoogleFonts.notoSansSc(),
      ),
    );
  }
  return Tooltip(
    richMessage: WidgetSpan(
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: tooltipStyle,
          children: spans,
        ),
      ),
    ),
    child: IconButton(
      icon: icon,
      onPressed: onPressed,
      tooltip: null,
    ),
  );
}

Widget _buildFormLine(BuildContext context, String label, String value, double scale, {Color? labelColor}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 4.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 16.0 * scale,
            fontWeight: FontWeight.bold,
            color: labelColor ?? Colors.black,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 16.0 * scale),
          ),
        ),
      ],
    ),
  );
}

Widget _buildTenseBubbles(BuildContext context, Meaning meaning, double scale) {
  final tenseEntries = [
    (meaning.presentTense ?? '', const Color(0xFF99CC00)),      // darker lime
    (meaning.presentContinuous ?? '', const Color(0xFF6BC06B)), // darker light green
    (meaning.pastTense ?? '', const Color(0xFF228B22)),          // dark green
    (meaning.pastParticiple ?? '', const Color(0xFF006400)),     // very dark green
  ].where((entry) => entry.$1.isNotEmpty).toList();

  return Wrap(
    spacing: 8.0,
    runSpacing: 8.0,
    children: tenseEntries.map((entry) {
      final form = entry.$1;
      final color = entry.$2;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16.0),
        ),
        child: Text(
          form,
          style: TextStyle(
            fontSize: 16.0 * scale,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }).toList(),
  );
}

TextSpan _buildDefinitionSpan(
  BuildContext context,
  String text,
  List<WordEntry> entries,
  String currentWord, {
  TextStyle? baseStyle,
  double scale = 1.0,
}) {
  final defaultStyle = TextStyle(fontSize: 20.0 * scale, height: 1.4);
  final effectiveStyle = defaultStyle.merge(baseStyle);
  final children = <TextSpan>[];
  final pattern = RegExp(r'([a-zA-Z]+|[^a-zA-Z]+)');
  for (final match in pattern.allMatches(text)) {
    final token = match.group(0)!;
    if (RegExp(r'^[a-zA-Z]+$').hasMatch(token)) {
      final target = _lookupLinkWord(token, entries);
      if (target != null &&
          target != currentWord.toLowerCase() &&
          !_linkSkipWords.contains(target)) {
        children.add(
          TextSpan(
            text: token,
            style: effectiveStyle.copyWith(
              color: Colors.blue,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                final targetIndex = entries.indexWhere(
                  (e) => e.word.toLowerCase() == target,
                );
                if (targetIndex != -1) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => WordDetailPage(
                        entry: entries[targetIndex],
                        entries: entries,
                        index: targetIndex,
                      ),
                    ),
                  );
                }
              },
          ),
        );
      } else {
        children.add(TextSpan(text: token));
      }
    } else {
      children.add(TextSpan(text: token));
    }
  }
  return TextSpan(
    style: effectiveStyle,
    children: children,
  );
}

Future<void> _speak(String text, String language) async {
  if (text.isEmpty) return;
  try {
    final voiceName = language.toLowerCase().startsWith('zh') ? _selectedZhVoice : _selectedEnVoice;
    if (voiceName != null && voiceName.isNotEmpty) {
      await _tts.setVoice({'name': voiceName, 'locale': language});
    }
    await _tts.setLanguage(language);
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.speak(text);
  } catch (e) {
    debugPrint('TTS error: $e');
  }
}

Widget _buildSpeakerButton({
  required VoidCallback onPressed,
  required double iconSize,
  String? tooltip,
}) {
  return IconButton(
    icon: const Icon(Icons.volume_up),
    iconSize: iconSize,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(),
    splashRadius: iconSize,
    tooltip: tooltip,
    onPressed: onPressed,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadAlternatives();
  await _initBestVoices();
  appSettings = AppSettings();
  runApp(const KidsDictionaryApp());
}

class KidsDictionaryApp extends StatelessWidget {
  const KidsDictionaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appSettings,
      builder: (context, child) {
        return MaterialApp(
          title: 'Kids Dictionary',
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            return Stack(
              children: [
                child!,
                // Force google_fonts to load NotoSansSC at startup so
                // the explicitly styled Chinese text renders without a flash.
                Positioned(
                  left: 0,
                  top: 0,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0,
                      child: Text('中', style: GoogleFonts.notoSansSc()),
                    ),
                  ),
                ),
              ],
            );
          },
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
            scaffoldBackgroundColor: Colors.white,
            useMaterial3: true,
            fontFamily: 'Roboto',
            fontFamilyFallback: const ['NotoSansSC'],
            tooltipTheme: const TooltipThemeData(
              textStyle: TextStyle(fontSize: 17.0),
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.teal,
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF121212),
            useMaterial3: true,
            fontFamily: 'Roboto',
            fontFamilyFallback: const ['NotoSansSC'],
            tooltipTheme: const TooltipThemeData(
              textStyle: TextStyle(fontSize: 17.0),
            ),
          ),
          themeMode: appSettings.darkMode ? ThemeMode.dark : ThemeMode.light,
          home: const HomePage(),
        );
      },
    );
  }
}

/// Displays each Chinese character with its tone-mark pinyin directly above it.
/// Punctuation and spaces stay on the character line and never appear in the
/// pinyin line. Chinese characters are centered under their pinyin, and extra
/// horizontal spacing gives the pinyin room to fit.
class PerCharPinyin extends StatelessWidget {
  final String chinese;
  final List<String> pinyin;
  final double charFontSize;
  final double pinyinFontSize;
  final double charSpacing;
  final Color? color;

  const PerCharPinyin({
    super.key,
    required this.chinese,
    required this.pinyin,
    required this.charFontSize,
    this.pinyinFontSize = 13.2,
    this.charSpacing = 10.0,
    this.color,
  });

  bool _isChinese(String char) {
    if (char.isEmpty) return false;
    final rune = char.codeUnitAt(0);
    return (rune >= 0x4E00 && rune <= 0x9FFF) ||
        (rune >= 0x3400 && rune <= 0x4DBF) ||
        (rune >= 0xF900 && rune <= 0xFAFF);
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.onSurface;
    final children = <Widget>[];
    int pinyinIndex = 0;

    for (int i = 0; i < chinese.length; i++) {
      final char = chinese[i];
      if (_isChinese(char) && pinyinIndex < pinyin.length) {
        children.add(
          Padding(
            padding: EdgeInsets.symmetric(horizontal: charSpacing / 2),
            child: IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Use NotoSansSC directly for Chinese + pinyin so it renders
                // reliably without depending on fontFamilyFallback.
                SizedBox(
                    height: pinyinFontSize * 1.2,
                    child: Center(
                      child: Text(
                        pinyin[pinyinIndex],
                        style: GoogleFonts.notoSansSc().copyWith(
                          fontSize: pinyinFontSize,
                          color: effectiveColor.withValues(alpha: 0.75),
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    char,
                    style: GoogleFonts.notoSansSc().copyWith(
                      fontSize: charFontSize,
                      color: effectiveColor,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        pinyinIndex++;
      } else {
        // Punctuation / spaces flow inline on the character line only.
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.0),
            child: Text(
              char,
              style: TextStyle(
                fontSize: charFontSize,
                color: effectiveColor,
                height: 1.1,
              ),
            ),
          ),
        );
      }
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 0,
      runSpacing: 6.0,
      children: children,
    );
  }
}

/// Loads an asset image only if the file actually exists; otherwise shows nothing.
class _ConditionalAssetImage extends StatelessWidget {
  final String assetPath;
  final double height;

  const _ConditionalAssetImage({
    required this.assetPath,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ByteData>(
      future: DefaultAssetBundle.of(context).load(assetPath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
          return Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: double.infinity,
          height: height,
          alignment: Alignment.centerLeft,
          child: Image.asset(
            assetPath,
            fit: BoxFit.contain,
          ),
        );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

Widget _buildMeaningSection(
  BuildContext context,
  Meaning meaning,
  List<WordEntry> entries,
  String word,
  double scale, {
  List<String> nounFormsToShow = const [],
  bool showOwnNounForm = false,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (meaning.partOfSpeech.isNotEmpty) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          decoration: BoxDecoration(
            color: _posColor(meaning.partOfSpeech),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Text(
            appSettings.showChinese && meaning.partOfSpeechCn.isNotEmpty
                ? '${meaning.partOfSpeech} / ${meaning.partOfSpeechCn}'
                : meaning.partOfSpeech,
            style: const TextStyle(
              fontSize: 15.0,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8.0),
      ],
      if ((meaning.plural?.isNotEmpty == true && !meaning.plural!.toLowerCase().endsWith('s')) ||
          (nounFormsToShow.isNotEmpty) ||
          (showOwnNounForm && meaning.nounForm?.isNotEmpty == true) ||
          (meaning.comparative?.isNotEmpty ?? false) ||
          (meaning.superlative?.isNotEmpty ?? false)) ...[
        Text(
          'Forms',
          style: TextStyle(
            fontSize: 18.0 * scale,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
        const SizedBox(height: 8.0),
        // Show only irregular plurals (plural that does NOT end with 's').
        if (meaning.plural?.isNotEmpty == true && !meaning.plural!.toLowerCase().endsWith('s')) _buildFormLine(context, 'Plural', meaning.plural!, scale),
        // Adverb form hidden by request.
        // if (meaning.adverb?.isNotEmpty == true) _buildFormLine(context, 'Adverb', meaning.adverb!, scale),
        if (nounFormsToShow.isNotEmpty)
          _buildFormLine(context, 'Noun form', nounFormsToShow.join(' / '), scale)
        else if (showOwnNounForm && meaning.nounForm?.isNotEmpty == true)
          _buildFormLine(context, 'Noun form', meaning.nounForm!, scale),
        if (meaning.comparative?.isNotEmpty == true) _buildFormLine(context, 'Comparative', meaning.comparative!, scale),
        if (meaning.superlative?.isNotEmpty == true) _buildFormLine(context, 'Superlative', meaning.superlative!, scale),
        const SizedBox(height: 8.0),
      ],
      if (meaning.partOfSpeech.toLowerCase().contains('verb') &&
          ((meaning.presentTense?.isNotEmpty ?? false) ||
              (meaning.presentContinuous?.isNotEmpty ?? false) ||
              (meaning.pastTense?.isNotEmpty ?? false) ||
              (meaning.pastParticiple?.isNotEmpty ?? false))) ...[
        Text(
          'Tense',
          style: TextStyle(
            fontSize: 18.0 * scale,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
        const SizedBox(height: 8.0),
        _buildTenseBubbles(context, meaning, scale),
        const SizedBox(height: 8.0),
      ],
      _buildRelationChips(
        context,
        'Synonyms / 同义词',
        meaning.synonyms,
        entries,
        word,
        scale,
      ),
      _buildRelationChips(
        context,
        'Antonyms / 反义词',
        meaning.antonyms,
        entries,
        word,
        scale,
      ),
      if (meaning.image?.isNotEmpty == true) ...[
        const SizedBox(height: 8.0),
        _ConditionalAssetImage(
          assetPath: meaning.image!,
          height: 250.0,
        ),
        const SizedBox(height: 8.0),
      ],
      Text(
        'Meaning',
        style: TextStyle(
          fontSize: 18.0 * scale,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
      const SizedBox(height: 8.0),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text.rich(
              _buildDefinitionSpan(
                context,
                meaning.definition,
                entries,
                word,
                scale: scale,
              ),
            ),
          ),
          _buildSpeakerButton(
            iconSize: 24.0 * scale,
            onPressed: () => _speak(meaning.definition, 'en-US'),
          ),
        ],
      ),
      if (meaning.definitionCn.isNotEmpty && appSettings.showChinese) ...[
        const SizedBox(height: 1.0),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: PerCharPinyin(
                chinese: meaning.definitionCn,
                pinyin: meaning.definitionPinyin,
                charFontSize: 21.6 * scale,
                pinyinFontSize: 14.4 * scale,
                charSpacing: 10.0,
              ),
            ),
            _buildSpeakerButton(
              iconSize: 24.0,
              onPressed: () => _speak(meaning.definitionCn, 'zh-CN'),
            ),
          ],
        ),
      ],
      const SizedBox(height: 8.0),
      Text(
        'Example',
        style: TextStyle(
          fontSize: 18.0 * scale,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
      const SizedBox(height: 8.0),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text.rich(
              _buildDefinitionSpan(
                context,
                meaning.example,
                entries,
                word,
                scale: scale,
              ),
            ),
          ),
          _buildSpeakerButton(
            iconSize: 24.0 * scale,
            onPressed: () => _speak(meaning.example, 'en-US'),
          ),
        ],
      ),
      if (meaning.exampleCn.isNotEmpty && appSettings.showChinese) ...[
        const SizedBox(height: 1.0),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: PerCharPinyin(
                chinese: meaning.exampleCn,
                pinyin: meaning.examplePinyin,
                charFontSize: 21.6 * scale,
                pinyinFontSize: 14.4 * scale,
                charSpacing: 10.0,
              ),
            ),
            _buildSpeakerButton(
              iconSize: 24.0,
              onPressed: () => _speak(meaning.exampleCn, 'zh-CN'),
            ),
          ],
        ),
      ],
      const Divider(height: 32.0),
    ],
  );
}

Future<void> _showSettingsDialog(BuildContext context) async {
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Settings'),
      content: StatefulBuilder(
        builder: (context, setDialogState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Chinese translations'),
                value: appSettings.showChinese,
                onChanged: (value) {
                  appSettings.toggleChinese();
                  setDialogState(() {});
                },
              ),
              ListTile(
                title: const Text('Text size'),
                subtitle: Slider(
                  value: appSettings.textScale,
                  min: 0.7,
                  max: 1.5,
                  divisions: 8,
                  label: appSettings.textScale.toStringAsFixed(1),
                  onChanged: (value) {
                    appSettings.setTextScale(value);
                    setDialogState(() {});
                  },
                ),
              ),
              SwitchListTile(
                title: const Text('Dark mode'),
                value: appSettings.darkMode,
                onChanged: (value) {
                  appSettings.toggleDarkMode();
                  setDialogState(() {});
                },
              ),
              SwitchListTile(
                title: const Text('Only words with images'),
                subtitle: const Text('Hide entries that have no picture mapped'),
                value: appSettings.onlyImageWords,
                onChanged: (value) {
                  appSettings.toggleOnlyImageWords();
                  setDialogState(() {});
                },
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final DatabaseHelper _db = DatabaseHelper.instance;
  final FavoritesManager _favoritesManager = FavoritesManager();
  final LearnedManager _learnedManager = LearnedManager();
  List<WordEntry> _rawAllWords = [];
  List<WordEntry> _allWords = [];
  List<WordEntry> _dailyWords = [];
  List<WordEntry> _results = [];
  Set<String> _favorites = {};
  Set<String> _learned = {};
  Set<String> _dailyWordsFavorites = {};
  Set<String> _dailyWordsLearned = {};
  String? _dailyWordsDate;
  int _dailyRefreshSeed = 0;
  int _dailyWordsSeed = 0;
  bool _showOnlyFavorites = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    appSettings.addListener(_onSettingsChanged);
    _loadAllWords();
  }

  @override
  void dispose() {
    appSettings.removeListener(_onSettingsChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSettingsChanged() async {
    if (mounted) {
      await _applyFilter();
    }
  }

  Future<void> _loadAllWords() async {
    final words = await _db.getAllWords();
    _rawAllWords = words;
    await _applyFilter();
  }

  Future<void> _toggleFavoritesView() async {
    setState(() {
      _showOnlyFavorites = !_showOnlyFavorites;
    });
    await _applyFilter();
  }

  Future<void> _toggleLearned(String word) async {
    await _learnedManager.toggleLearned(word);
    final isLearned = await _learnedManager.isLearned(word);
    if (mounted) {
      setState(() {
        final key = word.toLowerCase();
        if (isLearned) {
          _learned.add(key);
        } else {
          _learned.remove(key);
        }
      });
    }
  }

  Future<void> _applyFilter({bool forceRefreshDailyWords = false}) async {
    _favorites = await _favoritesManager.getFavorites();
    _learned = await _learnedManager.getLearned();
    if (!mounted) return;
    setState(() {
      _allWords = _withImages(_rawAllWords);
      if (forceRefreshDailyWords || _dailyWordsNeedRefresh()) {
        _recomputeDailyWords();
      }
      if (_showOnlyFavorites) {
        _results = _allWords.where((e) => _favorites.contains(e.word.toLowerCase())).toList();
      } else {
        _results = _dailyWords;
      }
      _isLoading = false;
    });
  }

  Future<void> _refreshDailyWords() async {
    _dailyRefreshSeed++;
    await _applyFilter(forceRefreshDailyWords: true);
  }

  List<WordEntry> _pickDailyWords(List<WordEntry> pool, {int? seed}) {
    final now = DateTime.now();
    final baseSeed = now.year * 10000 + now.month * 100 + now.day;
    final effectiveSeed = seed ?? baseSeed;
    final eligible = pool.where((e) {
      final w = e.word.toLowerCase();
      return !_favorites.contains(w) && !_learned.contains(w);
    }).toList();
    if (eligible.isEmpty) return [];
    // Sort deterministically so the daily words are stable regardless of DB row order.
    eligible.sort((a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()));
    eligible.shuffle(Random(effectiveSeed));
    final selected = eligible.take(5).toList();
    selected.sort((a, b) => a.word.toLowerCase().compareTo(b.word.toLowerCase()));
    return selected;
  }

  int _currentDailySeed() {
    final now = DateTime.now();
    return now.year * 10000 + now.month * 100 + now.day + _dailyRefreshSeed;
  }

  bool _dailyWordsNeedRefresh() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return _dailyWords.isEmpty ||
        _dailyWordsDate != today ||
        _dailyWordsSeed != _currentDailySeed() ||
        !_dailyWordsFavorites.containsAll(_favorites) ||
        !_favorites.containsAll(_dailyWordsFavorites) ||
        !_dailyWordsLearned.containsAll(_learned) ||
        !_learned.containsAll(_dailyWordsLearned);
  }

  void _recomputeDailyWords() {
    _dailyWords = _pickDailyWords(_allWords, seed: _currentDailySeed());
    _dailyWordsDate = DateTime.now().toIso8601String().substring(0, 10);
    _dailyWordsSeed = _currentDailySeed();
    _dailyWordsFavorites = Set<String>.from(_favorites);
    _dailyWordsLearned = Set<String>.from(_learned);
  }

  @override
  Widget build(BuildContext context) {
    final scale = appSettings.textScale;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kids Dictionary'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        leading: _buildIconButtonWithMixedTooltip(
          context: context,
          english: 'Settings',
          chinese: '选项',
          icon: const Icon(Icons.settings),
          onPressed: () => _showSettingsDialog(context),
        ),
        actions: [
          _buildIconButtonWithMixedTooltip(
            context: context,
            english: _showOnlyFavorites ? 'Show all words' : 'Show favourites',
            chinese: _showOnlyFavorites ? '显示全部' : '显示我的收藏',
            icon: Icon(_showOnlyFavorites ? Icons.star : Icons.star_border),
            onPressed: _toggleFavoritesView,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SelectionArea(
          child: Column(
            children: [
              RawAutocomplete<String>(
                textEditingController: _searchController,
                focusNode: _searchFocusNode,
                optionsBuilder: (TextEditingValue textEditingValue) {
                  final query = textEditingValue.text.trim().toLowerCase();
                  if (query.isEmpty) return const Iterable<String>.empty();
                  final hasChinese = query.runes.any((r) => r >= 0x4E00 && r <= 0x9FFF);
                  return _allWords
                      .where((e) {
                        if (e.word.toLowerCase().startsWith(query)) return true;
                        if (!hasChinese) return false;
                        // Chinese search across meanings 1, 2, and 3 (partial match)
                        return e.meanings.any(
                          (m) => m.definitionCn.toLowerCase().contains(query),
                        );
                      })
                      .map((e) => e.word)
                      .take(10);
                },
                onSelected: (String selection) {
                  final allIndex = _allWords.indexWhere(
                    (e) => e.word.toLowerCase() == selection.toLowerCase(),
                  );
                  if (allIndex >= 0) {
                    _openWordDetail(_allWords[allIndex], allIndex);
                  }
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      borderRadius: BorderRadius.circular(8.0),
                      child: Container(
                        width: MediaQuery.of(context).size.width - 32,
                        constraints: const BoxConstraints(maxHeight: 250),
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: options.length,
                          itemBuilder: (BuildContext context, int index) {
                            final option = options.elementAt(index);
                            final highlightedIndex = AutocompleteHighlightedOption.of(context);
                            final isHighlighted = index == highlightedIndex;
                            return ListTile(
                              dense: true,
                              tileColor: isHighlighted
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : null,
                              title: Text(
                                option,
                                style: TextStyle(
                                  fontSize: 16.0 * scale,
                                  color: isHighlighted
                                      ? Theme.of(context).colorScheme.onPrimaryContainer
                                      : null,
                                  fontWeight: isHighlighted ? FontWeight.bold : null,
                                ),
                              ),
                              onTap: () => onSelected(option),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
                fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    onSubmitted: (_) => onFieldSubmitted(),
                    decoration: InputDecoration(
                      labelText: 'Search a word / 搜尋單字',
                      hintText: 'Try "Apple" or "苹果"',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16.0),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(),
                  const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Word of the day',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4.0),
                      Text(
                        '每日一词',
                        style: TextStyle(fontSize: 18),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _buildIconButtonWithMixedTooltip(
                    context: context,
                    english: 'Refresh word of the day',
                    chinese: '刷新每日单词',
                    icon: const Icon(Icons.refresh),
                    onPressed: _refreshDailyWords,
                  ),
                ],
              ),
              const SizedBox(height: 8.0),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _results.isEmpty
                        ? const Center(
                            child: Text(
                              "No favourite words found!\nLet's bookmark some words, shall we?",
                              style: TextStyle(fontSize: 21),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final entry = _results[index];
                              final isLearned = _learned.contains(entry.word.toLowerCase());
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Card(
                                      child: ListTile(
                                        title: Text(
                                          entry.word,
                                          style: TextStyle(
                                            fontSize: 22.0 * scale,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: appSettings.showChinese && entry.wordCn.isNotEmpty
                                            ? PerCharPinyin(
                                                chinese: entry.wordCn,
                                                pinyin: entry.wordPinyin,
                                                charFontSize: 19.2 * scale,
                                                charSpacing: 10.0,
                                              )
                                            : null,
                                        trailing: const Icon(Icons.arrow_forward_ios),
                                        onTap: () => _openWordDetail(entry, index),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4.0),
                                  _buildIconButtonWithMixedTooltip(
                                    context: context,
                                    english: isLearned
                                        ? 'Mark as not learnt (this word may appear as the word of the day again)'
                                        : 'Mark as learnt (this word will not appear as the word of the day anymore)',
                                    chinese: isLearned
                                        ? '标记为未学会（这个词可能会再次成为每日单词）'
                                        : '标记为已学会（这个词不会再出现在每日单词中）',
                                    icon: Icon(isLearned ? Icons.check_circle : Icons.check_circle_outline),
                                    onPressed: () => _toggleLearned(entry.word),
                                  ),
                                ],
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openWordDetail(WordEntry entry, int index) {
    final allIndex = _allWords.indexWhere((e) => e.word.toLowerCase() == entry.word.toLowerCase());
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WordDetailPage(
          entry: entry,
          entries: _allWords.toList(),
          index: allIndex >= 0 ? allIndex : index,
        ),
      ),
    );
  }
}

class PreviousWordIntent extends Intent {
  const PreviousWordIntent();
}

class NextWordIntent extends Intent {
  const NextWordIntent();
}

class ScrollUpIntent extends Intent {
  const ScrollUpIntent();
}

class ScrollDownIntent extends Intent {
  const ScrollDownIntent();
}

class WordDetailPage extends StatefulWidget {
  final WordEntry entry;
  final List<WordEntry> entries;
  final int index;

  const WordDetailPage({
    super.key,
    required this.entry,
    required this.entries,
    required this.index,
  });

  @override
  State<WordDetailPage> createState() => _WordDetailPageState();
}

class _WordDetailPageState extends State<WordDetailPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FavoritesManager _favoritesManager = FavoritesManager();
  final LearnedManager _learnedManager = LearnedManager();
  final Map<int, ScrollController> _scrollControllers = {};
  late final PageController _pageController;
  int _currentIndex = 0;
  bool _isFavorite = false;
  bool _isLearned = false;

  void _handleSearch(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return;

    int targetIndex = widget.entries.indexWhere((e) => e.word.toLowerCase() == q);

    // 2) Try alternatives map (e.g., running -> run)
    if (targetIndex == -1) {
      final alt = alternativesMap[q];
      if (alt != null && alt.isNotEmpty) {
        targetIndex = widget.entries.indexWhere((e) => e.word.toLowerCase() == alt.toLowerCase());
      }
    }

    // 3) Try stripping common suffixes to find a base word (e.g., wonderful -> wonder)
    if (targetIndex == -1) {
      final words = widget.entries.map((e) => e.word.toLowerCase()).toSet();
      final base = findBaseWord(q, words);
      if (base != null) {
        targetIndex = widget.entries.indexWhere((e) => e.word.toLowerCase() == base);
      }
    }

    if (targetIndex != -1) {
      _pageController.jumpToPage(targetIndex);
      _searchController.clear();
      _searchFocusNode.unfocus();
    }
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.index;
    _pageController = PageController(initialPage: widget.index);
    _pageController.addListener(_onPageChanged);
    _loadFavoriteStatus();
    _loadLearnedStatus();
  }

  void _onPageChanged() {
    final page = _pageController.page;
    if (page == null) return;
    final newIndex = page.round();
    if (newIndex != _currentIndex) {
      setState(() {
        _currentIndex = newIndex;
      });
      _loadFavoriteStatus();
      _loadLearnedStatus();
    }
  }

  void _goToPreviousWord() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToNextWord() {
    if (_currentIndex < widget.entries.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _scrollBy(double delta) {
    final controller = _scrollControllers[_currentIndex];
    if (controller == null || !controller.hasClients) return;
    final target = (controller.offset + delta).clamp(
      0.0,
      controller.position.maxScrollExtent,
    );
    controller.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Future<void> _loadFavoriteStatus() async {
    final word = widget.entries[_currentIndex].word;
    final isFav = await _favoritesManager.isFavorite(word);
    if (mounted) {
      setState(() {
        _isFavorite = isFav;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final word = widget.entries[_currentIndex].word;
    await _favoritesManager.toggleFavorite(word);
    final isFav = await _favoritesManager.isFavorite(word);
    if (mounted) {
      setState(() {
        _isFavorite = isFav;
      });
    }
  }

  Future<void> _loadLearnedStatus() async {
    final word = widget.entries[_currentIndex].word;
    final isLearned = await _learnedManager.isLearned(word);
    if (mounted) {
      setState(() {
        _isLearned = isLearned;
      });
    }
  }

  Future<void> _toggleLearned() async {
    final word = widget.entries[_currentIndex].word;
    await _learnedManager.toggleLearned(word);
    final isLearned = await _learnedManager.isLearned(word);
    if (mounted) {
      setState(() {
        _isLearned = isLearned;
      });
    }
  }

  void _registerScrollController(int index, ScrollController controller) {
    _scrollControllers[index] = controller;
  }

  void _unregisterScrollController(int index) {
    _scrollControllers.remove(index);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    _scrollControllers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = appSettings.textScale;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        titleSpacing: 0.0,
        title: Row(
          children: [
            Focus(
              skipTraversal: true,
              child: _buildIconButtonWithMixedTooltip(
                context: context,
                english: 'Home',
                chinese: '首页',
                icon: const Icon(Icons.home),
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const HomePage()),
                    (route) => false,
                  );
                },
              ),
            ),
            Focus(
              skipTraversal: true,
              child: _buildIconButtonWithMixedTooltip(
                context: context,
                english: 'Settings',
                chinese: '选项',
                icon: const Icon(Icons.settings),
                onPressed: () => _showSettingsDialog(context),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: RawAutocomplete<String>(
                    textEditingController: _searchController,
                    focusNode: _searchFocusNode,
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      final query = textEditingValue.text.trim().toLowerCase();
                      if (query.isEmpty) return const Iterable<String>.empty();
                      final hasChinese = query.runes.any((r) => r >= 0x4E00 && r <= 0x9FFF);
                      return widget.entries
                          .where((e) {
                            if (e.word.toLowerCase().startsWith(query)) return true;
                            if (!hasChinese) return false;
                            // Chinese search across meanings 1, 2, and 3 (partial match)
                            return e.meanings.any(
                              (m) => m.definitionCn.toLowerCase().contains(query),
                            );
                          })
                          .map((e) => e.word)
                          .take(10);
                    },
                    onSelected: (String selection) {
                      _handleSearch(selection);
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4.0,
                          borderRadius: BorderRadius.circular(8.0),
                          child: Container(
                            width: MediaQuery.of(context).size.width * 0.7,
                            constraints: const BoxConstraints(maxHeight: 250),
                            child: ListView.builder(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: options.length,
                              itemBuilder: (BuildContext context, int index) {
                                final option = options.elementAt(index);
                                final highlightedIndex = AutocompleteHighlightedOption.of(context);
                                final isHighlighted = index == highlightedIndex;
                                return ListTile(
                                  dense: true,
                                  tileColor: isHighlighted
                                      ? Theme.of(context).colorScheme.primaryContainer
                                      : null,
                                  title: Text(
                                    option,
                                    style: TextStyle(
                                      fontSize: 16.0 * scale,
                                      color: isHighlighted
                                          ? Theme.of(context).colorScheme.onPrimaryContainer
                                          : null,
                                      fontWeight: isHighlighted ? FontWeight.bold : null,
                                    ),
                                  ),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                    fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                      return TextField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        onSubmitted: (_) => onFieldSubmitted(),
                        decoration: InputDecoration(
                          hintText: 'Search / 搜尋',
                          hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          prefixIcon: const Icon(Icons.search),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                        ),
                        style: TextStyle(fontSize: 18.0 * scale),
                      );
                    },
                  ),
                ),
              ),
            ),
            _buildIconButtonWithMixedTooltip(
              context: context,
              english: _isLearned
                  ? 'Mark as not learnt (this word may appear as the word of the day again)'
                  : 'Mark as learnt (this word will not appear as the word of the day anymore)',
              chinese: _isLearned
                  ? '标记为未学会（这个词可能会再次成为每日单词）'
                  : '标记为已学会（这个词不会再出现在每日单词中）',
              icon: Icon(_isLearned ? Icons.check_circle : Icons.check_circle_outline),
              onPressed: _toggleLearned,
            ),
            _buildIconButtonWithMixedTooltip(
              context: context,
              english: _isFavorite ? 'Remove from favourites' : 'Add to favourites',
              chinese: _isFavorite ? '从收藏中移除' : '添加到收藏',
              icon: Icon(_isFavorite ? Icons.star : Icons.star_border),
              onPressed: _toggleFavorite,
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      bottomNavigationBar: BottomAppBar(
        height: kToolbarHeight,
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _currentIndex > 0 ? _goToPreviousWord : null,
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              onPressed: _currentIndex < widget.entries.length - 1 ? _goToNextWord : null,
            ),
          ],
        ),
      ),
      body: Shortcuts(
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.arrowLeft): const PreviousWordIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowRight): const NextWordIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowUp): const ScrollUpIntent(),
          LogicalKeySet(LogicalKeyboardKey.arrowDown): const ScrollDownIntent(),
        },
        child: Actions(
          actions: {
            PreviousWordIntent: CallbackAction<PreviousWordIntent>(
              onInvoke: (_) {
                _goToPreviousWord();
                return null;
              },
            ),
            NextWordIntent: CallbackAction<NextWordIntent>(
              onInvoke: (_) {
                _goToNextWord();
                return null;
              },
            ),
            ScrollUpIntent: CallbackAction<ScrollUpIntent>(
              onInvoke: (_) {
                _scrollBy(-120);
                return null;
              },
            ),
            ScrollDownIntent: CallbackAction<ScrollDownIntent>(
              onInvoke: (_) {
                _scrollBy(120);
                return null;
              },
            ),
          },
          child: Focus(
            autofocus: true,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.entries.length,
              itemBuilder: (context, index) {
                return _WordPage(
                  index: index,
                  entry: widget.entries[index],
                  entries: widget.entries,
                  scale: scale,
                  onControllerReady: _registerScrollController,
                  onControllerDisposed: _unregisterScrollController,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _WordPage extends StatefulWidget {
  final int index;
  final WordEntry entry;
  final List<WordEntry> entries;
  final double scale;
  final void Function(int, ScrollController) onControllerReady;
  final void Function(int) onControllerDisposed;

  const _WordPage({
    required this.index,
    required this.entry,
    required this.entries,
    required this.scale,
    required this.onControllerReady,
    required this.onControllerDisposed,
  });

  @override
  State<_WordPage> createState() => _WordPageState();
}

class _WordPageState extends State<_WordPage> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    widget.onControllerReady(widget.index, _scrollController);
  }

  @override
  void dispose() {
    widget.onControllerDisposed(widget.index);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final entries = widget.entries;
    final scale = widget.scale;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: SelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  entry.word,
                  style: TextStyle(
                    fontSize: 36.0 * scale,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8.0),
                _buildSpeakerButton(
                  iconSize: 32.0,
                  tooltip: 'Listen',
                  onPressed: () => _speak(entry.word, 'en-US'),
                ),
              ],
            ),
            if (entry.wordCn.isNotEmpty && appSettings.showChinese) ...[
              const SizedBox(height: 10.0),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  PerCharPinyin(
                    chinese: entry.wordCn,
                    pinyin: entry.wordPinyin,
                    charFontSize: 28.8 * scale,
                    pinyinFontSize: 15.6 * scale,
                    charSpacing: 12.0,
                  ),
                  _buildSpeakerButton(
                    iconSize: 26.0,
                    tooltip: 'Listen in Chinese',
                    onPressed: () => _speak(entry.wordCn, 'zh-CN'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8.0),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: () {
                    // Sort meanings so verb senses always appear first
                    final sortedMeanings = entry.meanings.toList()
                      ..sort((a, b) {
                        final aIsVerb = a.partOfSpeech.toLowerCase().contains('verb');
                        final bIsVerb = b.partOfSpeech.toLowerCase().contains('verb');
                        if (aIsVerb && !bIsVerb) return -1;
                        if (!aIsVerb && bIsVerb) return 1;
                        return 0;
                      });
                    final nounForms = sortedMeanings
                        .map((m) => m.nounForm)
                        .where((f) => f != null && f.isNotEmpty)
                        .cast<String>()
                        .toSet()
                        .toList();
                    final firstAdjectiveIndex = sortedMeanings.indexWhere(
                        (m) => m.partOfSpeech.toLowerCase().contains('adjective'));
                    final fallbackNounForms = firstAdjectiveIndex == -1;
                    return [
                      for (var i = 0; i < sortedMeanings.length; i++)
                        _buildMeaningSection(
                          context,
                          sortedMeanings[i],
                          entries,
                          entry.word,
                          scale,
                          nounFormsToShow: firstAdjectiveIndex == i ? nounForms : const [],
                          showOwnNounForm: fallbackNounForms,
                        ),
                    ];
                  }(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
