// ignore_for_file: avoid_print
// Prints the built-in compatibility quiz as JSON, to seed Supabase.
// Run: dart run tool/export_quiz.dart
import 'dart:convert';

import 'package:everlane/question_bank.dart';

void main() {
  final rows = [
    for (final (i, q) in compatibilityQuestions.indexed)
      {
        'id': q.id,
        'position': i + 1,
        'topic': q.topic,
        'prompt': q.prompt,
        'section': q.section,
        'dimension': q.dimension?.name,
        'max_choices': q.maxChoices,
        'optional': q.optional,
        'exclusive': q.exclusive.toList(),
        'options': [
          for (final (value, label) in q.options) {'value': value, 'label': label}
        ],
      }
  ];
  print(jsonEncode(rows));
}
