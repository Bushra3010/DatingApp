/// Everlane onboarding questions and the 24-question Everlane Compatibility
/// Quiz, from the product question bank. Question IDs and answer values are
/// stable: the backend stores them, so change labels freely but never reuse
/// or rename an ID or value.
library;

/// Bump when questions or answer values change meaning.
const quizVersion = 1;

/// Matching dimensions and their starting weights (percent). The weights are
/// hypotheses to test, not validated predictors.
enum Dimension {
  intentions('Relationship intentions', 25),
  valuesBoundaries('Values and boundaries', 20),
  communication('Communication and emotional connection', 20),
  lifestyle('Lifestyle and daily habits', 15),
  personality('Personality and social preferences', 10),
  interests('Interests and dating style', 10);

  const Dimension(this.label, this.weight);
  final String label;
  final int weight;
}

class Question {
  const Question(this.id, this.topic, this.prompt, this.options,
      {this.section = '',
      this.dimension,
      this.maxChoices = 1,
      this.optional = true,
      this.exclusive = const {}});
  final String id, topic, prompt, section;

  /// (value, label) pairs.
  final List<(String, String)> options;

  /// Null for onboarding questions, which aren't scored.
  final Dimension? dimension;

  /// 1 is single-select; 0 means any number.
  final int maxChoices;
  final bool optional;

  /// Values that clear every other choice when picked (e.g. "None").
  final Set<String> exclusive;

  bool get multi => maxChoices != 1;
  String labelOf(String value) =>
      options.firstWhere((o) => o.$1 == value, orElse: () => (value, value)).$2;
}

const onboardingQuestions = [
  Question(
      'onb_hoping',
      'What you’re hoping to find',
      'What are you hoping to find on Everlane?',
      [
        ('serious_relationship', 'A serious relationship'),
        ('long_term_marriage', 'A long-term partner, possibly marriage'),
        ('casual', 'Casual dating'),
        ('new_connections', 'New connections and seeing where things go'),
        ('figuring_out', 'Still figuring it out'),
      ],
      optional: false),
  Question('onb_mindset', 'Dating mindset',
      'Which best describes your current dating mindset?', [
    ('ready_meaningful', 'Ready to build something meaningful'),
    ('open_right_person', 'Open to meeting the right person'),
    ('taking_slowly', 'Taking things slowly'),
    ('exploring', 'Exploring what I want'),
  ]),
  Question('onb_great_relationship', 'A great relationship',
      'What does a great relationship look like to you?', [
    ('best_friend', 'A best friend and romantic partner'),
    ('peaceful', 'A peaceful, supportive partnership'),
    ('passion_adventure', 'Passion, adventure, and growth'),
    ('strong_team', 'A strong team building a future'),
    ('balance_all', 'A balance of all these'),
  ]),
  Question('onb_connect', 'Connecting',
      'How do you usually like to connect with someone new?', [
    ('deep_conversations', 'Deep conversations'),
    ('humour_banter', 'Humour and playful banter'),
    ('shared_activities', 'Shared activities'),
    ('voice_video', 'Voice or video calls'),
    ('mix', 'A mix of everything'),
  ]),
  Question('onb_first_date', 'Ideal first date',
      'What would your ideal first date be?', [
    ('coffee', 'Coffee and conversation'),
    ('dinner', 'Dinner somewhere special'),
    ('walk_outdoor', 'A walk or outdoor activity'),
    ('activity_event', 'An activity, game, or event'),
    ('spontaneous', 'Something spontaneous'),
  ]),
  Question('onb_interests', 'Interests',
      'Which interests would you love to share?', [
    ('travel', 'Travel and adventure'),
    ('music_movies_art', 'Music, movies, and art'),
    ('fitness_outdoors', 'Fitness and outdoor activities'),
    ('food_places', 'Food and discovering places'),
    ('books_learning', 'Books, learning, and meaningful conversations'),
    ('gaming_tech', 'Gaming and technology'),
  ]),
  Question('onb_social', 'Social energy', 'How social are you usually?', [
    ('love_people', 'I love being around people'),
    ('mix', 'A mix of social time and quiet time'),
    ('small_groups', 'I prefer smaller groups'),
    ('introverted', 'I’m more introverted and value one-on-one time'),
  ]),
  Question('onb_partner', 'In a partner', 'What matters most in a partner?', [
    ('kindness_maturity', 'Kindness and emotional maturity'),
    ('honesty_trust', 'Honesty and trust'),
    ('ambition_growth', 'Ambition and growth'),
    ('humour', 'Humour and playfulness'),
    ('shared_values', 'Shared values and life goals'),
    ('affection', 'Affection and thoughtfulness'),
  ]),
  Question('onb_communicate', 'Communication',
      'How would you like to communicate with a match?', [
    ('text_all_day', 'Text throughout the day'),
    ('few_thoughtful', 'A few thoughtful messages'),
    ('voice_calls', 'Voice notes and calls'),
    ('mix', 'A mix depending on the day'),
  ]),
  Question('onb_meet', 'Meeting in person',
      'How quickly do you prefer to meet in person?', [
    ('when_comfortable', 'Once we feel comfortable'),
    ('few_days', 'Within a few days if the vibe is right'),
    ('longer_conversation', 'After a longer conversation'),
    ('naturally', 'Let it happen naturally'),
  ]),
];

const _a = 'Relationship intentions';
const _b = 'Communication and emotional connection';
const _c = 'Values and personality';
const _d = 'Lifestyle and daily habits';
const _e = 'Interests and dating style';
const _f = 'Boundaries and relationship expectations';

const compatibilityQuestions = [
  Question(
      'q01',
      'Relationship direction',
      'What are you ultimately hoping to build with the right person?',
      [
        ('long_term', 'A long-term committed relationship'),
        ('marriage_family', 'Marriage and building a family'),
        (
          'meaningful_no_timeline',
          'A meaningful relationship without a fixed timeline'
        ),
        ('casual', 'Casual dating'),
        ('exploring', 'I’m still exploring'),
      ],
      section: _a,
      dimension: Dimension.intentions),
  Question(
      'q02',
      'Pace',
      'How do you prefer a relationship to develop?',
      [
        ('slow_trust', 'Slowly, building trust first'),
        ('natural', 'Naturally, without pressure'),
        (
          'intentional',
          'Intentionally, with clear conversations about the future'
        ),
        ('quick', 'Quickly, when the connection feels right'),
      ],
      section: _a,
      dimension: Dimension.intentions),
  Question(
      'q03',
      'Exclusivity',
      'When would you prefer to discuss exclusivity?',
      [
        ('early', 'Early, once we both feel interested'),
        ('few_dates', 'After a few dates'),
        ('know_better', 'When we know each other better'),
        ('naturally', 'When it comes up naturally'),
      ],
      section: _a,
      dimension: Dimension.intentions),
  Question(
      'q04',
      'Future plans',
      'How important is it that your partner shares your long-term vision?',
      [
        ('essential', 'Essential'),
        ('very_important', 'Very important, with room for compromise'),
        ('build_together', 'Important, but we can build a vision together'),
        ('unsure', 'I’m not sure about my future plans yet'),
      ],
      section: _a,
      dimension: Dimension.intentions),
  Question(
      'q05',
      'Everyday communication',
      'What communication rhythm feels right to you?',
      [
        ('frequent', 'Frequent messages throughout the day'),
        ('few_meaningful', 'A few meaningful conversations'),
        ('calls_voice', 'Regular calls or voice notes'),
        ('flexible', 'Flexible, depending on each person’s day'),
      ],
      section: _b,
      dimension: Dimension.communication),
  Question(
      'q06',
      'Showing affection',
      'What makes you feel most loved?',
      [
        ('words', 'Words of appreciation'),
        ('quality_time', 'Quality time and undivided attention'),
        ('physical', 'Physical affection'),
        ('gestures_gifts', 'Thoughtful gestures and gifts'),
        ('practical_help', 'Practical help and support'),
      ],
      section: _b,
      dimension: Dimension.communication,
      maxChoices: 2),
  Question(
      'q07',
      'Difficult conversations',
      'When something bothers you in a relationship, what do you usually prefer?',
      [
        ('talk_soon', 'Talk about it as soon as possible'),
        ('think_then_talk', 'Take some time to think, then talk'),
        ('gentle_message', 'Start with a gentle message'),
        ('both_ready', 'Wait until both people feel ready'),
      ],
      section: _b,
      dimension: Dimension.communication),
  Question(
      'q08',
      'Emotional support',
      'When you’re having a difficult day, what helps most?',
      [
        ('listen', 'Someone who listens without trying to fix things'),
        ('advice', 'Practical advice and solutions'),
        ('reassurance', 'Reassurance and affection'),
        ('space_then_connect', 'Space to process, followed by connection'),
      ],
      section: _b,
      dimension: Dimension.communication),
  Question(
      'q09',
      'Core values',
      'Which values matter most in a relationship?',
      [
        ('honesty', 'Honesty and transparency'),
        ('loyalty', 'Loyalty and commitment'),
        ('kindness', 'Kindness and empathy'),
        ('ambition', 'Ambition and personal growth'),
        ('independence', 'Independence and freedom'),
        ('family', 'Family and community'),
        ('curiosity', 'Curiosity and open-mindedness'),
      ],
      section: _c,
      dimension: Dimension.valuesBoundaries,
      maxChoices: 3),
  Question(
      'q10',
      'Decision-making',
      'How do you usually make important decisions?',
      [
        ('think_carefully', 'I think carefully before deciding'),
        ('instincts', 'I trust my instincts'),
        ('talk_through', 'I talk things through with someone'),
        ('weigh_then_act', 'I weigh the options and then act'),
      ],
      section: _c,
      dimension: Dimension.personality),
  Question(
      'q11',
      'Social energy',
      'Your ideal weekend is usually…',
      [
        ('going_out', 'Going out, meeting people, and exploring'),
        ('staying_in', 'Staying in with someone I care about'),
        ('balance', 'A balance of social plans and quiet time'),
        ('spontaneous', 'Something spontaneous and unplanned'),
      ],
      section: _c,
      dimension: Dimension.personality),
  Question(
      'q12',
      'Personal growth',
      'How should a relationship support personal growth?',
      [
        ('motivate', 'We should actively motivate each other'),
        (
          'encourage_independence',
          'We should encourage each other while respecting independence'
        ),
        ('grow_naturally', 'We should grow naturally together'),
        (
          'comfort_stability',
          'Emotional comfort and stability matter most to me'
        ),
      ],
      section: _c,
      dimension: Dimension.personality),
  Question(
      'q13',
      'Routine',
      'Which lifestyle sounds most like yours?',
      [
        ('structured', 'Structured and routine-oriented'),
        ('flexible_organized', 'Flexible, but reasonably organized'),
        ('spontaneous', 'Spontaneous and adventurous'),
        ('mix', 'A mix depending on work and life'),
      ],
      section: _d,
      dimension: Dimension.lifestyle),
  Question(
      'q14',
      'Work and ambition',
      'How would you like work and ambition to fit into your relationship?',
      [
        ('both_ambitious', 'We both prioritize ambitious goals'),
        ('support_different', 'We support each other’s different ambitions'),
        ('balance_first', 'Work-life balance comes first'),
        ('depends', 'It depends on our circumstances'),
      ],
      section: _d,
      dimension: Dimension.lifestyle),
  Question(
      'q15',
      'Money mindset',
      'Which best describes your approach to money?',
      [
        ('save_plan', 'Save, plan, and prioritize financial stability'),
        ('balance', 'Balance saving with enjoying life'),
        ('experiences', 'Prefer flexibility and experiences'),
        ('developing', 'Still developing my financial habits'),
      ],
      section: _d,
      dimension: Dimension.lifestyle),
  Question(
      'q16',
      'Time together',
      'How much time would you ideally like to spend together?',
      [
        ('lots', 'Lots of shared time and activities'),
        ('regular_quality', 'Regular quality time alongside independent lives'),
        ('flexible', 'A flexible balance that changes week to week'),
        (
          'independent',
          'Plenty of independence, with meaningful time together'
        ),
      ],
      section: _d,
      dimension: Dimension.lifestyle),
  Question(
      'q17',
      'Shared interests',
      'What would you most enjoy doing together?',
      [
        ('travel', 'Travel and exploring new places'),
        ('food', 'Cooking, cafés, and discovering food'),
        ('entertainment', 'Movies, music, and entertainment'),
        ('fitness', 'Fitness, sports, and outdoor activities'),
        ('gaming', 'Gaming and technology'),
        ('culture', 'Art, books, and culture'),
        ('learning', 'Learning new skills or building projects'),
        ('staying_in', 'Staying in and relaxing together'),
      ],
      section: _e,
      dimension: Dimension.interests,
      maxChoices: 3),
  Question(
      'q18',
      'First date',
      'Which first date would make you feel most comfortable?',
      [
        ('coffee', 'Coffee or a casual conversation'),
        ('dinner', 'Dinner in a nice place'),
        ('activity', 'An activity that gives us something to do'),
        ('walk', 'A walk in a public place'),
        ('group', 'A group activity or double date'),
      ],
      section: _e,
      dimension: Dimension.interests),
  Question(
      'q19',
      'Adventure',
      'How do you feel about trying new things with a partner?',
      [
        ('love_new', 'I love trying new things regularly'),
        ('open_comfortable', 'I’m open to them when we both feel comfortable'),
        ('familiar', 'I prefer familiar activities most of the time'),
        ('depends', 'It depends on the activity'),
      ],
      section: _e,
      dimension: Dimension.interests),
  Question(
      'q20',
      'Personal space',
      'How much independence do you need in a relationship?',
      [
        ('a_lot', 'A lot; we should maintain our own routines and interests'),
        ('balance', 'A healthy balance of togetherness and independence'),
        ('share_most', 'I prefer sharing most parts of everyday life'),
        ('depends_stage', 'It depends on the stage of the relationship'),
      ],
      section: _f,
      dimension: Dimension.valuesBoundaries),
  Question(
      'q21',
      'Reassurance',
      'How do you feel about expressing your need for reassurance?',
      [
        ('openly', 'I communicate it openly'),
        ('through_actions', 'I prefer reassurance through consistent actions'),
        ('working_on_it', 'It can be difficult, but I’m working on it'),
        (
          'little_needed',
          'I generally feel comfortable without much reassurance'
        ),
      ],
      section: _f,
      dimension: Dimension.valuesBoundaries),
  Question(
      'q22',
      'Conflict repair',
      'After a disagreement, what matters most to you?',
      [
        ('honest_resolution', 'An honest conversation and a clear resolution'),
        ('heard', 'Feeling heard and understood'),
        ('apology_change', 'An apology followed by changed behaviour'),
        ('cool_off', 'Time to cool off before reconnecting'),
      ],
      section: _f,
      dimension: Dimension.valuesBoundaries),
  Question(
      'q23',
      'Family involvement',
      'How do you see family involvement in a long-term relationship?',
      [
        (
          'closely_involved',
          'Family should be closely involved in major decisions'
        ),
        (
          'couple_decides',
          'Family matters, but the couple makes its own decisions'
        ),
        (
          'strong_boundaries',
          'I prefer strong boundaries between family and relationship'
        ),
        ('depends', 'It depends on the situation and culture'),
      ],
      section: _f,
      dimension: Dimension.valuesBoundaries),
  Question(
      'q24',
      'Dealbreakers',
      'Which relationship expectations are non-negotiable for you?',
      [
        ('honesty_fidelity', 'Honesty and fidelity'),
        ('shared_intentions', 'Shared intentions for the relationship'),
        ('boundaries', 'Respect for personal boundaries'),
        ('children_family', 'Similar views on children and family'),
        (
          'lifestyle_substances',
          'Compatible lifestyle or substance-use preferences'
        ),
        ('cultural_religious', 'Respect for cultural or religious values'),
        ('none_or_later', 'None selected / I’d rather discuss these later'),
      ],
      section: _f,
      dimension: Dimension.valuesBoundaries,
      maxChoices: 0,
      exclusive: {'none_or_later'}),
];
