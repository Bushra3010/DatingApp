import 'package:flutter_test/flutter_test.dart';
import 'package:everlane/chemistry.dart';
import 'package:everlane/question_bank.dart';

void main() {
  final ananya = demoQuizAnswers['ananya']!;
  final isha = demoQuizAnswers['isha']!;

  test('Question IDs and answer values are unique and stable', () {
    final ids = compatibilityQuestions.map((q) => q.id).toList();
    expect(ids.length, 24);
    expect(ids.toSet().length, 24);
    for (final q in [...compatibilityQuestions, ...onboardingQuestions]) {
      final values = q.options.map((o) => o.$1).toList();
      expect(values.toSet().length, values.length, reason: q.id);
    }
    expect(onboardingQuestions.length, 10);
    final weights = Dimension.values.fold(0, (sum, d) => sum + d.weight);
    expect(weights, 100);
  });

  test('Demo answers only use real question IDs and values', () {
    demoQuizAnswers.forEach((person, answers) {
      answers.forEach((id, values) {
        final q = compatibilityQuestions.firstWhere((q) => q.id == id);
        for (final v in values) {
          expect(q.options.any((o) => o.$1 == v), isTrue,
              reason: '$person $id $v');
        }
        if (q.maxChoices > 0) {
          expect(values.length, lessThanOrEqualTo(q.maxChoices));
        }
      });
    });
  });

  test('Identical answers score 100 and explain what is shared', () {
    final c = Chemistry.between(ananya, ananya);
    expect(c.score, 100);
    expect(c.preliminary, isFalse);
    expect(c.differences, isEmpty);
    expect(c.shared.first.$1, 'Relationship direction');
  });

  test('Too few answers give a preliminary view, not a number', () {
    final few = {for (final e in ananya.entries.take(6)) e.key: e.value};
    final c = Chemistry.between(few, ananya);
    expect(c.preliminary, isTrue);
    expect(c.score, isNull);
  });

  test('A shared-intentions dealbreaker filters before scoring', () {
    final c = Chemistry.between(ananya, isha);
    expect(c.filteredBy, isNotNull);
    expect(c.score, isNull);
  });

  test('A high score cannot hide wanting different things', () {
    // Same answers as Isha except relationship direction and no dealbreakers.
    final mine = {
      ...isha,
      'q01': ['long_term'],
      'q24': ['none_or_later']
    };
    final c = Chemistry.between(mine, isha);
    expect(c.filteredBy, isNull);
    expect(c.intentMismatch, isTrue);
    expect(c.score, lessThanOrEqualTo(39));
  });

  test('Multi-select answers count by overlap', () {
    final mine = {
      ...ananya,
      'q09': ['honesty', 'loyalty', 'family']
    };
    final c = Chemistry.between(mine, ananya);
    expect(c.score, lessThan(100));
    expect(c.shared, contains(('Core values', 'Honesty and transparency')));
  });

  test('Differences name the topic, never the other person’s answer', () {
    final c = Chemistry.between({
      ...ananya,
      'q15': ['save_plan'],
      'q24': ['none_or_later']
    }, ananya);
    expect(c.differences, contains('Money mindset'));
    expect(c.shared.any((s) => s.$1 == 'Money mindset'), isFalse);
  });
}
