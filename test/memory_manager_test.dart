import 'package:flutter_test/flutter_test.dart';

import 'package:pocket_professor/ai/memory/memory_manager.dart';

void main() {
  group('MemoryManager.extractFacts', () {
    test('extracts learning statements', () {
      final facts = MemoryManager.extractFacts("I'm learning Flutter.");
      expect(facts, ['The user is learning Flutter.']);
    });

    test('extracts studying statements', () {
      final facts = MemoryManager.extractFacts('I am studying computer science.');
      expect(facts, ['The user is learning computer science.']);
    });

    test('extracts preferences', () {
      final facts = MemoryManager.extractFacts('I prefer simple explanations.');
      expect(facts, ['The user prefers simple explanations.']);
    });

    test('extracts name', () {
      final facts = MemoryManager.extractFacts('My name is Juan.');
      expect(facts, ["The user's name is Juan."]);
    });

    test('extracts occupation from "I am a"', () {
      final facts = MemoryManager.extractFacts('I am a software engineer.');
      expect(facts, ['The user is a software engineer.']);
    });

    test('returns nothing for questions without facts', () {
      expect(MemoryManager.extractFacts('What is the capital of France?'), isEmpty);
    });

    test('multiple facts from one message', () {
      final facts = MemoryManager.extractFacts(
        "I'm learning Dart and I use VS Code.",
      );
      expect(facts, contains('The user is learning Dart.'));
      expect(facts, contains('The user uses VS Code.'));
    });

    test('deduplicates identical facts from different rules', () {
      final facts = MemoryManager.extractFacts(
        "I'm learning Flutter. I am studying Flutter.",
      );
      expect(facts, ['The user is learning Flutter.']);
    });
  });
}
