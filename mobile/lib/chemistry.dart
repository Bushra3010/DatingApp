import 'question_bank.dart';

typedef Answers = Map<String, List<String>>;

/// Demo quiz answers for the preview profiles, keyed by person id.
const demoQuizAnswers = <String, Answers>{
  'ananya': {
    'q01': ['long_term'],
    'q02': ['slow_trust'],
    'q03': ['few_dates'],
    'q04': ['very_important'],
    'q05': ['few_meaningful'],
    'q06': ['quality_time', 'words'],
    'q07': ['think_then_talk'],
    'q08': ['listen'],
    'q09': ['honesty', 'kindness', 'curiosity'],
    'q10': ['think_carefully'],
    'q11': ['staying_in'],
    'q12': ['encourage_independence'],
    'q13': ['flexible_organized'],
    'q14': ['support_different'],
    'q15': ['balance'],
    'q16': ['regular_quality'],
    'q17': ['food', 'culture', 'travel'],
    'q18': ['coffee'],
    'q19': ['open_comfortable'],
    'q20': ['balance'],
    'q21': ['through_actions'],
    'q22': ['heard'],
    'q23': ['couple_decides'],
    'q24': ['honesty_fidelity', 'shared_intentions'],
  },
  'meera': {
    'q01': ['meaningful_no_timeline'],
    'q02': ['natural'],
    'q03': ['know_better'],
    'q04': ['build_together'],
    'q05': ['flexible'],
    'q06': ['quality_time', 'gestures_gifts'],
    'q07': ['gentle_message'],
    'q08': ['space_then_connect'],
    'q09': ['kindness', 'curiosity', 'independence'],
    'q10': ['talk_through'],
    'q11': ['balance'],
    'q12': ['grow_naturally'],
    'q13': ['mix'],
    'q14': ['balance_first'],
    'q15': ['experiences'],
    'q16': ['flexible'],
    'q17': ['food', 'travel', 'culture'],
    'q18': ['walk'],
    'q19': ['love_new'],
    'q20': ['balance'],
    'q21': ['openly'],
    'q22': ['honest_resolution'],
    'q23': ['depends'],
    'q24': ['boundaries'],
  },
  'isha': {
    'q01': ['casual'],
    'q02': ['quick'],
    'q03': ['naturally'],
    'q04': ['unsure'],
    'q05': ['frequent'],
    'q06': ['physical', 'words'],
    'q07': ['talk_soon'],
    'q08': ['reassurance'],
    'q09': ['independence', 'curiosity', 'ambition'],
    'q10': ['instincts'],
    'q11': ['spontaneous'],
    'q12': ['motivate'],
    'q13': ['spontaneous'],
    'q14': ['both_ambitious'],
    'q15': ['experiences'],
    'q16': ['independent'],
    'q17': ['travel', 'entertainment', 'fitness'],
    'q18': ['activity'],
    'q19': ['love_new'],
    'q20': ['a_lot'],
    'q21': ['little_needed'],
    'q22': ['cool_off'],
    'q23': ['strong_boundaries'],
    'q24': ['none_or_later'],
  },
  'tara': {
    'q01': ['marriage_family'],
    'q02': ['intentional'],
    'q03': ['early'],
    'q04': ['essential'],
    'q05': ['calls_voice'],
    'q06': ['practical_help', 'quality_time'],
    'q07': ['talk_soon'],
    'q08': ['advice'],
    'q09': ['loyalty', 'family', 'honesty'],
    'q10': ['weigh_then_act'],
    'q11': ['staying_in'],
    'q12': ['comfort_stability'],
    'q13': ['structured'],
    'q14': ['support_different'],
    'q15': ['save_plan'],
    'q16': ['lots'],
    'q17': ['food', 'staying_in', 'learning'],
    'q18': ['dinner'],
    'q19': ['open_comfortable'],
    'q20': ['share_most'],
    'q21': ['openly'],
    'q22': ['apology_change'],
    'q23': ['closely_involved'],
    'q24': ['honesty_fidelity', 'shared_intentions', 'children_family'],
  },
};

/// Relationship direction, grouped so we can tell a fundamental mismatch
/// from a small difference.
String? _intentGroup(Answers a) => switch (a['q01']?.firstOrNull) {
      'long_term' ||
      'marriage_family' ||
      'meaningful_no_timeline' =>
        'committed',
      'casual' => 'casual',
      'exploring' => 'exploring',
      _ => null,
    };

/// A Chemistry report between you and one person. It's a conversation aid,
/// not a prediction of relationship success.
class Chemistry {
  const Chemistry._(
      {required this.score,
      required this.preliminary,
      required this.intentMismatch,
      required this.filteredBy,
      required this.shared,
      required this.differences,
      required this.areas});

  /// 0–100, or null when [preliminary] or [filteredBy] is set.
  final int? score;

  /// Too few shared answers for a number to mean anything.
  final bool preliminary;

  /// One wants something committed and the other something casual.
  final bool intentMismatch;

  /// The hard dealbreaker that rules this match out, if any.
  final String? filteredBy;

  /// Answers you both gave, by topic. Only identical answers are shown, so
  /// nothing private about the other person is revealed.
  final List<(String, String)> shared;

  /// 0–100 per area you both answered, for the detailed report.
  final Map<Dimension, int> areas;

  /// Topics where you answered differently, as conversation starters.
  /// Their answer itself stays private.
  final List<String> differences;

  /// Fewest of your own answers before a score is shown.
  static const minAnswers = 12;
  static const minDimensions = 4;

  static Chemistry between(Answers mine, Answers theirs) {
    final myIntent = _intentGroup(mine), theirIntent = _intentGroup(theirs);
    final intentsKnown = myIntent != null && theirIntent != null;
    final intentMismatch = intentsKnown &&
        myIntent != theirIntent &&
        {myIntent, theirIntent}.containsAll(['committed', 'casual']);

    // Hard dealbreakers filter before any scoring. Only the ones the quiz can
    // check are applied; the rest are left for people to discuss.
    String? filteredBy;
    final dealbreakers = {...?mine['q24'], ...?theirs['q24']};
    if (dealbreakers.contains('shared_intentions') &&
        intentsKnown &&
        myIntent != theirIntent) {
      filteredBy = 'You want different things from a relationship.';
    }

    final byDimension = <Dimension, List<double>>{};
    final shared = <(String, String)>[];
    final differences = <String>[];
    for (final q in compatibilityQuestions) {
      if (q.id == 'q24') continue;
      final a = mine[q.id], b = theirs[q.id];
      if (a == null || a.isEmpty || b == null || b.isEmpty) continue;
      final both = a.toSet().intersection(b.toSet());
      final similarity = q.multi
          ? both.length / a.toSet().union(b.toSet()).length
          : (both.isEmpty ? 0.0 : 1.0);
      byDimension.putIfAbsent(q.dimension!, () => []).add(similarity);
      for (final v in both) {
        shared.add((q.topic, q.labelOf(v)));
      }
      if (both.isEmpty) differences.add(q.topic);
    }

    final answered =
        mine.entries.where((e) => e.key != 'q24' && e.value.isNotEmpty).length;
    final preliminary =
        answered < minAnswers || byDimension.length < minDimensions;

    int? score;
    if (!preliminary && filteredBy == null) {
      var total = 0.0, weights = 0;
      byDimension.forEach((d, values) {
        total += d.weight * values.reduce((x, y) => x + y) / values.length;
        weights += d.weight;
      });
      score = (total / weights * 100).round();
      // A high total must not hide wanting different things.
      if (intentMismatch && score > 39) score = 39;
    }

    // Most heavily weighted dimensions first.
    int rank(String topic) => compatibilityQuestions
        .firstWhere((q) => q.topic == topic)
        .dimension!
        .weight;
    shared.sort((x, y) => rank(y.$1).compareTo(rank(x.$1)));
    differences.sort((x, y) => rank(y).compareTo(rank(x)));

    final areas = {
      for (final d in Dimension.values)
        if (byDimension[d] case final values?)
          d: (values.reduce((x, y) => x + y) / values.length * 100).round()
    };

    return Chemistry._(
        areas: areas,
        score: score,
        preliminary: preliminary,
        intentMismatch: intentMismatch,
        filteredBy: filteredBy,
        shared: shared,
        differences: differences);
  }
}
