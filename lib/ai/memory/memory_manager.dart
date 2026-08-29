import '../../database/memory_dao.dart';

/// Extracts and persists facts about the user from conversation text.
///
/// v1 uses rule-based extraction (high precision, low recall). Facts are
/// stored as "The user ..." sentences and injected into future prompts.
class MemoryManager {
  final MemoryDao _dao;

  MemoryManager(this._dao);

  static final List<({RegExp pattern, String Function(String) build})> _rules = [
    (
      pattern: RegExp(r"I(?:'m| am) learning (.+?)(?:[.,!?]| and | but |$)", caseSensitive: false),
      build: (s) => 'The user is learning $s.',
    ),
    (
      pattern: RegExp(r"I(?:'m| am) studying (.+?)(?:[.,!?]| and | but |$)", caseSensitive: false),
      build: (s) => 'The user is learning $s.',
    ),
    (
      pattern: RegExp(r"I(?:'m| am) working on (.+?)(?:[.,!?]| and | but |$)", caseSensitive: false),
      build: (s) => 'The user is learning $s.',
    ),
    (
      pattern: RegExp(r"I study (.+?)(?:[.,!?]| and | but |$)", caseSensitive: false),
      build: (s) => 'The user studies $s.',
    ),
    (
      pattern: RegExp(r"I prefer (.+?)(?:[.,!?]| and | but |$)", caseSensitive: false),
      build: (s) => 'The user prefers $s.',
    ),
    (
      pattern: RegExp(r"I like (.+?)(?:[.,!?]| and | but |$)", caseSensitive: false),
      build: (s) => 'The user likes $s.',
    ),
    (
      pattern: RegExp(r"I love (.+?)(?:[.,!?]| and | but |$)", caseSensitive: false),
      build: (s) => 'The user loves $s.',
    ),
    (
      pattern: RegExp(r"I use (.+?)(?:[.,!?]| and | but |$)", caseSensitive: false),
      build: (s) => 'The user uses $s.',
    ),
    (
      pattern: RegExp(r"I(?:'m| am) (?:a|an) (.+?)(?:[.,!?]| and | but |$)", caseSensitive: false),
      build: (s) => 'The user is a $s.',
    ),
    (
      pattern: RegExp(r"My name is (.+?)(?:[.,!?]| and | but |$)", caseSensitive: false),
      build: (s) => "The user's name is $s.",
    ),
  ];

  /// Extracts candidate facts from [text] as "The user ..." sentences.
  static List<String> extractFacts(String text) {
    final facts = <String>[];
    for (final rule in _rules) {
      final match = rule.pattern.firstMatch(text);
      if (match == null) continue;
      final subject = match.group(1)!.trim();
      if (subject.isEmpty || subject.length > 100) continue;
      final fact = rule.build(subject);
      if (!facts.contains(fact)) {
        facts.add(fact);
      }
    }
    return facts;
  }

  /// Extracts facts from [text] and persists any new ones.
  ///
  /// Returns the facts that were newly saved.
  Future<List<String>> extractAndSave(String text) async {
    final facts = extractFacts(text);
    final saved = <String>[];
    for (final fact in facts) {
      final id = await _dao.insert(fact);
      if (id != 0) {
        saved.add(fact);
      }
    }
    return saved;
  }

  /// All stored facts as plain sentences, for prompt injection.
  Future<List<String>> getAllFacts() async {
    final facts = await _dao.getAll();
    return facts.map((f) => f.fact).toList();
  }
}
