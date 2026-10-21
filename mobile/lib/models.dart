import 'package:flutter/material.dart';
import 'chemistry.dart';
import 'question_bank.dart';
import 'theme.dart';

/// What someone is looking for. Shown on profiles and browsed in Explore.
enum LookingFor {
  longTerm(
      'Long-term relationship',
      'Long-term',
      'Ready for something that lasts',
      Icons.favorite_rounded,
      EverlaneColors.like),
  shortTerm('Short-term fun', 'Short-term fun', 'Keeping it light and easy',
      Icons.celebration_rounded, EverlaneColors.star),
  coffeeDate('Coffee date', 'Coffee date', 'Low-key first meet over coffee',
      Icons.coffee_rounded, EverlaneColors.pass),
  dateNight('Date night', 'Date night', 'Dinner, drinks and dressing up',
      Icons.nightlife_rounded, Color(0xFF7A3E5C)),
  newFriends('New friends', 'New friends', 'Good people, no pressure',
      Icons.people_alt_rounded, EverlaneColors.boost),
  travelBuddy('Travel buddy', 'Travel buddy', 'Someone to explore places with',
      Icons.flight_takeoff_rounded, Color(0xFF3F7CAC));

  const LookingFor(this.title, this.short, this.blurb, this.icon, this.color);
  final String title, short, blurb;
  final IconData icon;
  final Color color;
}

class Person {
  const Person(
      {required this.id,
      required this.name,
      required this.age,
      required this.job,
      required this.photo,
      required this.distance,
      required this.answer,
      required this.lookingFor,
      this.soundtrack = '',
      this.voicePrompt = '',
      this.voiceSeconds = 0,
      this.verified = false});
  final String id, name, job, photo, answer;
  final List<LookingFor> lookingFor;
  final int age, distance;

  /// Kept rare on purpose, so the badge means something.
  final bool verified;

  /// "Artist – Song", shown as a prompt chip on the photo.
  final String soundtrack;

  /// Transcript of a short voice prompt; empty when there is none.
  final String voicePrompt;
  final int voiceSeconds;

  /// Exact distance is never shown: close by reads "Nearby", the rest is
  /// rounded up to the next 5 km.
  String get distanceLabel =>
      distance <= 5 ? 'Nearby' : 'Within ${(distance / 5).ceil() * 5} km';
  String get image =>
      'https://images.unsplash.com/$photo?auto=format&fit=crop&w=1000&q=85';
}

const demoPeople = [
  Person(
      id: 'ananya',
      verified: true,
      soundtrack: 'Prateek Kuhad – cold/mess',
      voicePrompt:
          'The fastest way to my heart? Recommend me a book you couldn’t put down.',
      voiceSeconds: 9,
      lookingFor: [LookingFor.longTerm, LookingFor.coffeeDate],
      name: 'Ananya',
      age: 27,
      job: 'Product designer',
      photo: 'photo-1534528741775-53994a69daeb',
      distance: 4,
      answer:
          'A slow morning, a strong filter coffee, and getting wonderfully lost in a bookstore.'),
  Person(
      id: 'meera',
      soundtrack: 'Norah Jones – Sunrise',
      lookingFor: [
        LookingFor.coffeeDate,
        LookingFor.newFriends,
        LookingFor.travelBuddy
      ],
      name: 'Meera',
      age: 28,
      job: 'Architect',
      photo: 'photo-1524504388940-b1c1722653e1',
      distance: 7,
      answer:
          'Finding a little café with a big personality. Bonus points if there’s a dog.'),
  Person(
      id: 'isha',
      soundtrack: 'The Local Train – Choo Lo',
      voicePrompt: 'Ask me about the time I drove to Gokarna on a whim.',
      voiceSeconds: 7,
      lookingFor: [
        LookingFor.shortTerm,
        LookingFor.dateNight,
        LookingFor.travelBuddy
      ],
      name: 'Isha',
      age: 25,
      job: 'Creative strategist',
      photo: 'photo-1524250502761-1ac6f2e30d43',
      distance: 3,
      answer:
          'A spontaneous drive, a very specific playlist, and absolutely no rush to get home.'),
  Person(
      id: 'tara',
      verified: true,
      soundtrack: 'A. R. Rahman – Tere Bina',
      voicePrompt: 'I make a mean tiramisu. That’s it, that’s the pitch.',
      voiceSeconds: 6,
      lookingFor: [LookingFor.longTerm, LookingFor.dateNight],
      name: 'Tara',
      age: 29,
      job: 'Doctor',
      photo: 'photo-1517841905240-472988babdf9',
      distance: 12,
      answer:
          'Cooking something new together. I’ll handle dessert if you handle the playlist.'),
];

/// The four launch tiers recommended in the Everlane membership options.
/// Prices sit in the middle of each test range; they're hypotheses to test,
/// not final. The preview switches plans locally and takes no payment.
/// Safety and privacy controls are free on every plan.
enum Plan {
  free('Free', '₹0', 'The essential dating experience', 8, 0, [
    '8 likes each day',
    'Like profiles and match when interest is mutual',
    'Message your matches',
    'A Chemistry summary with each person',
    'Blocking, reporting, privacy controls and account deletion',
  ]),
  plus('Plus', '₹249', 'Simple, affordable upgrade', 25, 0, [
    'Everything in Free',
    '25 likes each day',
    'Filter by relationship intentions',
    'A fuller Chemistry explanation, including where you differ',
    'Rewind your last accidental pass',
  ]),
  gold('Gold', '₹499', 'The mainstream premium tier', 50, 2, [
    'Everything in Plus',
    'See who has liked you',
    '50 likes each day',
    '2 profile boosts each month',
  ]),
  platinum('Platinum', '₹899', 'The full-featured premium experience', 100, 5, [
    'Everything in Gold',
    '100 likes each day',
    '5 profile boosts each month',
    'A detailed Chemistry report, area by area',
    'Hangouts: host or join plans nearby',
  ]);

  const Plan(this.title, this.price, this.tagline, this.dailyLikes,
      this.monthlyBoosts, this.perks);
  final String title, price, tagline;
  final int dailyLikes, monthlyBoosts;
  final List<String> perks;

  bool atLeast(Plan other) => index >= other.index;
}

enum HangoutKind {
  dinner('Dinner', Icons.restaurant_rounded),
  movie('Movie', Icons.movie_outlined),
  coffee('Coffee', Icons.coffee_outlined),
  drinks('Drinks', Icons.local_bar_outlined),
  outdoors('Outdoors', Icons.park_outlined);

  const HangoutKind(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// A plan someone hosts and others ask to join. A null [host] means you.
class Hangout {
  const Hangout(
      {required this.id,
      required this.host,
      required this.kind,
      required this.title,
      required this.when,
      required this.place,
      required this.note,
      required this.spots});
  final String id, title, when, place, note;
  final Person? host;
  final HangoutKind kind;
  final int spots;
}

final demoHangouts = [
  Hangout(
      id: 'h1',
      host: demoPeople[0],
      kind: HangoutKind.coffee,
      title: 'Filter coffee and a bookstore',
      when: 'Saturday, 10:30 am',
      place: 'Church Street, Bengaluru',
      note: 'Slow morning, good books, no rush.',
      spots: 2),
  Hangout(
      id: 'h2',
      host: demoPeople[3],
      kind: HangoutKind.dinner,
      title: 'Cook-along dinner night',
      when: 'Tonight, 8:00 pm',
      place: 'Indiranagar, Bengaluru',
      note: 'I’ll handle dessert. Bring a playlist.',
      spots: 3),
  Hangout(
      id: 'h3',
      host: demoPeople[2],
      kind: HangoutKind.movie,
      title: 'Late show at the cinema',
      when: 'Friday, 9:30 pm',
      place: 'Koramangala, Bengaluru',
      note: 'Open to any genre. We vote at the door.',
      spots: 2),
  Hangout(
      id: 'h4',
      host: demoPeople[1],
      kind: HangoutKind.outdoors,
      title: 'Sunset walk at Cubbon Park',
      when: 'Sunday, 5:30 pm',
      place: 'Cubbon Park, Bengaluru',
      note: 'Easy pace, followed by chai.',
      spots: 4),
  Hangout(
      id: 'h5',
      host: demoPeople[2],
      kind: HangoutKind.drinks,
      title: 'Rooftop drinks after work',
      when: 'Thursday, 7:00 pm',
      place: 'MG Road, Bengaluru',
      note: 'Small group, big views.',
      spots: 1),
];

class ChatMessage {
  ChatMessage(this.text, {this.mine = false});
  final String text;
  final bool mine;
}

class SentLike {
  const SentLike(this.personId, this.target, this.comment);
  final String personId, target, comment;
}

class Conversation {
  Conversation(this.person, this.messages);
  final Person person;
  final List<ChatMessage> messages;
}

/// Local preview state. No likes, messages or account changes reach the API yet.
class PreviewStore extends ChangeNotifier {
  final Set<String> passed = {};
  final Set<String> liked = {};
  final List<SentLike> sentLikes = [];
  final List<Person> incoming = [demoPeople[1], demoPeople[2]];
  final List<Conversation> conversations = [
    Conversation(demoPeople[3], [
      ChatMessage('You liked their answer to “My ideal Sunday”', mine: true),
      ChatMessage('Okay, important question: what’s your go-to dessert?')
    ]),
  ];
  RangeValues ages = const RangeValues(24, 32);
  double distance = 25;
  bool verifiedOnly = false;
  bool paused = false;
  bool notifications = true;

  /// First launch shows onboarding until it's finished or skipped.
  bool onboarded = false;
  DateTime? myBirthday;
  String myGender = '';
  String interestedIn = '';
  String myCity = 'Bengaluru';
  final Answers onboardingAnswers = {};

  /// Age from the date of birth given at onboarding; the demo profile is 29.
  int get myAge {
    final b = myBirthday;
    if (b == null) return 29;
    final now = DateTime.now();
    final birthdayPassed =
        now.month > b.month || (now.month == b.month && now.day >= b.day);
    return now.year - b.year - (birthdayPassed ? 0 : 1);
  }

  void finishOnboarding() {
    onboarded = true;
    notifyListeners();
  }

  /// Compatibility quiz answers, saved as each question is answered.
  final Answers quizAnswers = {};
  int quizAnsweredVersion = quizVersion;
  int get quizAnswered => quizAnswers.values.where((v) => v.isNotEmpty).length;

  void answerQuiz(String questionId, List<String> values) {
    if (values.isEmpty) {
      quizAnswers.remove(questionId);
    } else {
      quizAnswers[questionId] = values;
    }
    quizAnsweredVersion = quizVersion;
    notifyListeners();
  }

  void deleteQuizAnswers() {
    quizAnswers.clear();
    notifyListeners();
  }

  /// Null until you've answered at least one quiz question.
  Chemistry? chemistryWith(Person p) => quizAnswers.isEmpty
      ? null
      : Chemistry.between(quizAnswers, demoQuizAnswers[p.id] ?? const {});

  /// Light is the default; Settings can switch to dark.
  bool darkMode = false;

  /// Hidden from Discover except to people you've liked. A privacy control,
  /// so it's free.
  bool invisible = false;
  bool get canSeeLikes => plan.atLeast(Plan.gold);

  /// Plus and up: only show people looking for one of these. Empty = everyone.
  final Set<LookingFor> intentFilter = {};
  bool get canFilterIntentions => plan.atLeast(Plan.plus);

  /// Plus and up see where you differ; Platinum sees each area's score.
  bool get fullerChemistry => plan.atLeast(Plan.plus);
  bool get detailedChemistry => plan.atLeast(Plan.platinum);

  /// Boosts: a monthly allowance, each lasting [boostLength].
  static const boostLength = Duration(minutes: 30);
  int boostsUsed = 0;
  DateTime? boostEndsAt;
  int get boostsLeft => plan.monthlyBoosts - boostsUsed;
  bool get boosting =>
      boostEndsAt != null && DateTime.now().isBefore(boostEndsAt!);

  void startBoost() {
    if (boostsLeft <= 0 || boosting) return;
    boostsUsed++;
    boostEndsAt = DateTime.now().add(boostLength);
    notifyListeners();
  }

  String myName = 'Rohit';
  String myJob = 'Software engineer';
  String myPrompt =
      'Good food, better company, and finding a new favourite place.';
  Plan plan = Plan.free;

  /// Rewind (undo a pass) comes with Plus and up.
  bool get canRewind => plan.atLeast(Plan.plus);

  /// Every plan has a daily limit, so actions stay fair-use.
  int get remaining => plan.dailyLikes - liked.length;
  bool get outOfLikes => remaining <= 0;
  List<Person> get discover => paused
      ? []
      : demoPeople
          .where((p) =>
              !passed.contains(p.id) &&
              !liked.contains(p.id) &&
              !conversations.any((chat) => chat.person.id == p.id) &&
              p.age >= ages.start &&
              p.age <= ages.end &&
              p.distance <= distance &&
              (!verifiedOnly || p.verified) &&
              (intentFilter.isEmpty || p.lookingFor.any(intentFilter.contains)))
          .toList();

  /// Everyone looking for [category], minus profiles passed on or hidden.
  List<Person> exploring(LookingFor category) => demoPeople
      .where((p) => p.lookingFor.contains(category) && !passed.contains(p.id))
      .toList();

  /// Passes in order, so Undo can bring back the most recent one.
  /// Blocked and reported profiles are hidden via [passed] but never land here.
  final List<String> passHistory = [];
  bool get canUndo => passHistory.isNotEmpty;

  void skip(Person p) {
    passed.add(p.id);
    passHistory.add(p.id);
    notifyListeners();
  }

  /// Brings back the last profile passed on and returns it, or null.
  /// Free members can't rewind.
  Person? undoLastPass() {
    if (passHistory.isEmpty || !canRewind) return null;
    final id = passHistory.removeLast();
    passed.remove(id);
    notifyListeners();
    return demoPeople.firstWhere((p) => p.id == id);
  }

  void like(Person p, {String target = 'photo', String comment = ''}) {
    if (outOfLikes || liked.contains(p.id)) return;
    liked.add(p.id);
    sentLikes.add(SentLike(p.id, target, comment.trim()));
    notifyListeners();
  }

  void removeLike(Person p) {
    incoming.remove(p);
    notifyListeners();
  }

  Conversation match(Person p) {
    incoming.remove(p);
    final chat = Conversation(p, [
      ChatMessage(
          'I love your idea of a perfect Sunday. What’s your favourite spot?')
    ]);
    conversations.insert(0, chat);
    notifyListeners();
    return chat;
  }

  void send(Conversation chat, String text) {
    if (text.trim().isEmpty) return;
    chat.messages.add(ChatMessage(text.trim(), mine: true));
    notifyListeners();
  }

  /// Hangouts come with Platinum.
  bool get canHangout => plan == Plan.platinum;
  final List<Hangout> hangouts = [...demoHangouts];
  final Set<String> hangoutRequests = {};

  /// Set by "Ready to Hangout?"; null until the member joins Hangouts.
  String? hangoutMood;
  String hangoutDetail = '';
  bool hangoutHasPlace = false;

  void joinHangouts(String mood, String detail, bool hasPlace) {
    hangoutMood = mood;
    hangoutDetail = detail.trim();
    hangoutHasPlace = hasPlace;
    notifyListeners();
  }

  void requestToJoin(Hangout h) {
    hangoutRequests.add(h.id);
    notifyListeners();
  }

  void hostHangout(Hangout h) {
    hangouts.insert(0, h);
    notifyListeners();
  }

  /// The existing conversation with [p], or a new one.
  Conversation chatWith(Person p) {
    for (final c in conversations) {
      if (c.person.id == p.id) return c;
    }
    final chat = Conversation(p, []);
    conversations.insert(0, chat);
    notifyListeners();
    return chat;
  }

  void choosePlan(Plan next) {
    plan = next;
    if (!next.atLeast(Plan.plus)) intentFilter.clear();
    notifyListeners();
  }

  void update() => notifyListeners();
}
