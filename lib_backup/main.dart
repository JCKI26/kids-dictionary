import 'package:flutter/material.dart';
import 'database_helper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KidsDictionaryApp());
}

class KidsDictionaryApp extends StatelessWidget {
  const KidsDictionaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kids Dictionary',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<WordEntry> _results = [];
  List<WordEntry> _allWords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllWords();
  }

  Future<void> _loadAllWords() async {
    final words = await _db.getAllWords();
    setState(() {
      _allWords = words;
      _results = words;
      _isLoading = false;
    });
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = _allWords;
      });
      return;
    }

    final matches = await _db.searchWords(query.trim());
    setState(() {
      _results = matches;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kids Dictionary'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                labelText: 'Search a word',
                hintText: 'Try "apple" or "happy"',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
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
                            return Card(
                              child: ListTile(
                                title: Text(
                                  entry.word,
                                  style: const TextStyle(
                                    fontSize: 22.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios),
                                onTap: () => _openWordDetail(entry),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _openWordDetail(WordEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WordDetailPage(entry: entry),
      ),
    );
  }
}

class WordDetailPage extends StatelessWidget {
  final WordEntry entry;

  const WordDetailPage({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(entry.word),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.word,
              style: const TextStyle(
                fontSize: 36.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24.0),
            Text(
              'Meaning',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              entry.definition,
              style: const TextStyle(fontSize: 20.0, height: 1.4),
            ),
            const SizedBox(height: 24.0),
            Text(
              'Example',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              entry.example,
              style: const TextStyle(
                fontSize: 20.0,
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
