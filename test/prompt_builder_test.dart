import 'package:flutter_test/flutter_test.dart';

import 'package:pocket_professor/ai/prompt/prompt_builder.dart';

void main() {
  group('PromptBuilder.buildSystemPrompt', () {
    test('includes the professor persona', () {
      final prompt = PromptBuilder.buildSystemPrompt();
      expect(prompt, contains('Pocket Professor'));
      expect(prompt, contains('Use simple English'));
      expect(prompt, contains('Keep answers short and to the point'));
    });

    test('injects memory facts', () {
      final prompt = PromptBuilder.buildSystemPrompt(
        memoryFacts: const ['The user is learning Flutter.'],
      );
      expect(prompt, contains('About the user:'));
      expect(prompt, contains('The user is learning Flutter.'));
    });

    test('omits memory section when no facts', () {
      final prompt = PromptBuilder.buildSystemPrompt();
      expect(prompt, isNot(contains('About the user:')));
    });
  });

  group('PromptBuilder.selectHistory', () {
    test('returns history unchanged when within limit', () {
      final history = [
        for (var i = 0; i < 10; i++)
          (role: i.isEven ? 'user' : 'assistant', content: 'm$i'),
      ];
      final selected = PromptBuilder.selectHistory(history);
      expect(selected.length, 10);
    });

    test('keeps only the most recent messages over the limit', () {
      final history = [
        for (var i = 0; i < 30; i++)
          (role: i.isEven ? 'user' : 'assistant', content: 'm$i'),
      ];
      final selected = PromptBuilder.selectHistory(history, maxMessages: 8);
      expect(selected.length, 8);
      expect(selected.first.content, 'm22');
      expect(selected.last.content, 'm29');
    });
  });
}
