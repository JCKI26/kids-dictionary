import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'database_helper.dart';
import 'alternatives.dart';
import 'favorites_manager.dart';

final FlutterTts _tts = FlutterTts();

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
          if (e.image.isNotEmpty) return true;
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
                      ? Colors.green.shade300
                      : Colors.green.shade100),
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
    await _tts.setLanguage(language);
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.speak(text);
  } catch (e) {
    debugPrint('TTS error: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadAlternatives();
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
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
            scaffoldBackgroundColor: Colors.white,
            useMaterial3: true,
            fontFamily: 'Roboto',
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.teal,
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF121212),
            useMaterial3: true,
            fontFamily: 'Roboto',
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
                  SizedBox(
                    height: pinyinFontSize * 1.2,
                    child: Center(
                      child: Text(
                        pinyin[pinyinIndex],
                        style: TextStyle(
                          fontSize: pinyinFontSize,
                          color: effectiveColor.withValues(alpha: 0.75),
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    char,
                    style: TextStyle(
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
  String? headerImage,
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
          (meaning.adverb?.isNotEmpty ?? false) ||
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
        if (meaning.adverb?.isNotEmpty == true) _buildFormLine(context, 'Adverb', meaning.adverb!, scale),
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
      SizedBox(height: (headerImage?.isNotEmpty == true || meaning.image?.isNotEmpty == true) ? 8.0 : 0.0),
      if (headerImage?.isNotEmpty == true || meaning.image?.isNotEmpty == true) ...[
        _ConditionalAssetImage(
          assetPath: meaning.image?.isNotEmpty == true ? meaning.image! : headerImage!,
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
          IconButton(
            icon: const Icon(Icons.volume_up),
            iconSize: 24.0 * scale,
            tooltip: 'Read meaning',
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
            IconButton(
              icon: const Icon(Icons.volume_up),
              iconSize: 24.0,
              tooltip: 'Read Chinese meaning',
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
          IconButton(
            icon: const Icon(Icons.volume_up),
            iconSize: 24.0 * scale,
            tooltip: 'Read example',
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
            IconButton(
              icon: const Icon(Icons.volume_up),
              iconSize: 24.0,
              tooltip: 'Read Chinese example',
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
  final DatabaseHelper _db = DatabaseHelper.instance;
  final FavoritesManager _favoritesManager = FavoritesManager();
  List<WordEntry> _rawAllWords = [];
  List<WordEntry> _allWords = [];
  List<WordEntry> _results = [];
  Set<String> _favorites = {};
  bool _showOnlyFavorites = false;
  bool _isLoading = true;
  int _selectedIndex = -1;

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
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) {
      _applyFilter();
    }
  }

  Future<void> _loadAllWords() async {
    final words = await _db.getAllWords();
    _rawAllWords = words;
    _favorites = await _favoritesManager.getFavorites();
    _applyFilter();
  }

  void _toggleFavoritesView() {
    setState(() {
      _showOnlyFavorites = !_showOnlyFavorites;
    });
    _applyFilter();
  }

  void _applyFilter() {
    setState(() {
      _allWords = _withImages(_rawAllWords);
      if (_showOnlyFavorites) {
        _allWords = _allWords.where((e) => _favorites.contains(e.word.toLowerCase())).toList();
      }
      _results = _allWords;
      _isLoading = false;
    });
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = _allWords;
        _selectedIndex = -1;
      });
      return;
    }

    final matches = await _db.searchWords(query.trim());
    setState(() {
      _results = _withImages(matches);
      _selectedIndex = -1;
    });
  }

  void _moveSelection(int delta) {
    if (_results.isEmpty) return;
    setState(() {
      if (_selectedIndex == -1) {
        _selectedIndex = delta > 0 ? 0 : _results.length - 1;
      } else {
        _selectedIndex = (_selectedIndex + delta).clamp(0, _results.length - 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scale = appSettings.textScale;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kids Dictionary'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        leading: IconButton(
          icon: const Icon(Icons.settings),
          tooltip: 'Settings',
          onPressed: () => _showSettingsDialog(context),
        ),
        actions: [
          IconButton(
            icon: Icon(_showOnlyFavorites ? Icons.star : Icons.star_border),
            tooltip: _showOnlyFavorites ? 'Show all words' : 'Show favorites',
            onPressed: _toggleFavoritesView,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SelectionArea(
          child: Column(
            children: [
              Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent) {
                    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                      _moveSelection(1);
                      return KeyEventResult.handled;
                    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      _moveSelection(-1);
                      return KeyEventResult.handled;
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  onSubmitted: (value) {
                    if (_results.isNotEmpty) {
                      final index = _selectedIndex >= 0 ? _selectedIndex : 0;
                      _openWordDetail(_results[index], index);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Search a word / 搜尋單字',
                    hintText: 'Try "apple" or "happy"',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _results.isEmpty
                        ? const Center(child: Text('No words found. Keep trying!'))
                        : ListView.builder(
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final entry = _results[index];
                              final isSelected = index == _selectedIndex;
                              return Card(
                                color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
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
  final ScrollController _scrollController = ScrollController();
  bool _isFavorite = false;

  void _handleSearch(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return;
    final targetIndex = widget.entries.indexWhere((e) => e.word.toLowerCase() == q);
    if (targetIndex != -1) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => WordDetailPage(
            entry: widget.entries[targetIndex],
            entries: widget.entries,
            index: targetIndex,
          ),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadFavoriteStatus();
  }

  void _goToPreviousWord() {
    if (widget.index > 0) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => WordDetailPage(
            entry: widget.entries[widget.index - 1],
            entries: widget.entries,
            index: widget.index - 1,
          ),
        ),
      );
    }
  }

  void _goToNextWord() {
    if (widget.index < widget.entries.length - 1) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => WordDetailPage(
            entry: widget.entries[widget.index + 1],
            entries: widget.entries,
            index: widget.index + 1,
          ),
        ),
      );
    }
  }

  void _scrollBy(double delta) {
    if (!_scrollController.hasClients) return;
    final target = (_scrollController.offset + delta).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Future<void> _loadFavoriteStatus() async {
    final isFav = await _favoritesManager.isFavorite(widget.entry.word);
    if (mounted) {
      setState(() {
        _isFavorite = isFav;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    await _favoritesManager.toggleFavorite(widget.entry.word);
    final isFav = await _favoritesManager.isFavorite(widget.entry.word);
    if (mounted) {
      setState(() {
        _isFavorite = isFav;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final entries = widget.entries;
    final scale = appSettings.textScale;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 0.0,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.home),
              tooltip: 'Home',
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Settings',
              onPressed: () => _showSettingsDialog(context),
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
                      return widget.entries
                          .where((e) => e.word.toLowerCase().startsWith(query))
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
                                return ListTile(
                                  dense: true,
                                  title: Text(option, style: TextStyle(fontSize: 16.0 * scale)),
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
            IconButton(
              icon: Icon(_isFavorite ? Icons.star : Icons.star_border),
              tooltip: _isFavorite ? 'Remove from favorites' : 'Add to favorites',
              onPressed: _toggleFavorite,
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      bottomNavigationBar: BottomAppBar(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Previous word',
              onPressed: widget.index > 0 ? _goToPreviousWord : null,
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward),
              tooltip: 'Next word',
              onPressed: widget.index < widget.entries.length - 1 ? _goToNextWord : null,
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
            child: Padding(
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
                  IconButton(
                    icon: const Icon(Icons.volume_up),
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
                    IconButton(
                      icon: const Icon(Icons.volume_up),
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
                            headerImage: i == 0 && entry.image.isNotEmpty ? entry.image : null,
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
            ),
          ),
        ),
      ),
    );
  }
}