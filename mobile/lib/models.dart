import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import 'backend.dart';
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
      this.verified = false,
      this.activeNow = false,
      this.bio = '',
      this.interests = const [],
      this.city = 'Bengaluru',
      this.photoUrls = const [],
      this.remote = false});

  /// A real member, from a Supabase card (see `discover_members`).
  factory Person.fromCard(
      Map<String, dynamic> r, String Function(String path) photoUrl) {
    final looking = switch (r['looking_for'] as String? ?? '') {
      'Friendship first' => LookingFor.newFriends,
      'Open to see' => LookingFor.coffeeDate,
      _ => LookingFor.longTerm,
    };
    return Person(
        id: r['id'] as String,
        name: r['name'] as String? ?? '',
        age: (r['age'] as num?)?.toInt() ?? 0,
        job: r['job'] as String? ?? '',
        photo: '',
        distance: 0,
        answer: r['prompt_answer'] as String? ?? '',
        lookingFor: [looking],
        verified: r['verified'] as bool? ?? false,
        bio: r['bio'] as String? ?? '',
        interests: List<String>.from(r['interests'] as List? ?? const []),
        city: r['city'] as String? ?? '',
        photoUrls: [
          for (final path in List<String>.from(r['photos'] as List? ?? const []))
            photoUrl(path)
        ],
        remote: true);
  }

  final String id, name, job, photo, answer;
  final String city;

  /// Real members' photos (public Storage URLs); demo people use assets.
  final List<String> photoUrls;

  /// True for real members from Supabase; likes, passes and chat with them
  /// are saved. Demo people stay local.
  final bool remote;

  /// A short line shown over the photo on the Discover card.
  final String bio;
  final List<String> interests;
  final bool activeNow;
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
      activeNow: true,
      bio: 'Designer by day, bookstore wanderer by weekend. Looking for someone to share filter coffee and long walks with.',
      interests: ['Coffee', 'Books', 'Design'],
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
      bio: 'Architect who sketches cafés instead of buildings on Sundays. Dog person, always.',
      interests: ['Travel', 'Art', 'Dogs'],
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
      activeNow: true,
      bio: 'Road trips, loud playlists and late-night chai. Spontaneity is my love language.',
      interests: ['Road trips', 'Live music', 'Chai'],
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
      bio: 'Doctor who unwinds in the kitchen. I’ll bake the tiramisu, you pick the movie.',
      interests: ['Cooking', 'Movies', 'Fitness'],
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
  Conversation(this.person, this.messages, {this.matchId});
  final Person person;
  final List<ChatMessage> messages;

  /// The Supabase match, for real members. Null for demo chats, and briefly
  /// while a like back is still turning into a match.
  String? matchId;
  Future<String?>? pendingMatch;
}

/// App state. The signed-in member's own profile and photos sync to Supabase
/// through [backend]; likes, messages and discovery are still local demo data.
class PreviewStore extends ChangeNotifier {
  PreviewStore({this.backend});

  /// Null in tests and when Supabase can't be reached: everything then stays
  /// in memory, and "Skip to the app (preview)" works without an account.
  final ProfileBackend? backend;
  bool get signedIn => backend?.signedIn ?? false;
  String? get accountEmail => backend?.user?.email;

  /// True while a returning member's profile is being loaded at start-up.
  bool restoring = false;

  /// The last sync problem, shown to the member; cleared on the next success.
  String? syncError;

  final Set<String> passed = {};
  final Set<String> liked = {};
  final List<SentLike> sentLikes = [];
  final List<Person> incoming = [..._demoIncoming];
  final List<Conversation> conversations = [..._demoConversations()];

  static final _demoIncoming = [demoPeople[1], demoPeople[2]];
  static List<Conversation> _demoConversations() => [
        Conversation(demoPeople[3], [
          ChatMessage('You liked their answer to “My ideal Sunday”',
              mine: true),
          ChatMessage('Okay, important question: what’s your go-to dessert?')
        ]),
      ];

  /// Signed-in members see real people from Supabase instead of the demo
  /// cast; the account-less preview (and tests) keep the demo data.
  bool get live => signedIn;
  final List<Person> members = [];

  /// What a real member wrote when they liked you, keyed by their id.
  final Map<String, SentLike> likeNotes = {};

  /// Set when a new match arrives (your like back, or theirs); the app shell
  /// shows the celebration and clears it.
  final ValueNotifier<Conversation?> newMatch = ValueNotifier(null);
  RealtimeChannel? _channel;

  List<Person> get _pool => live ? members : demoPeople;
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
  String myCity = 'Indiranagar';
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
    // Discovery matches on your saved gender and preferences, so load it
    // once the finished profile is saved.
    saveProfile().then((_) => refreshMembers());
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

  /// The premium dark look is the default; Settings can switch to light.
  bool darkMode = true;

  /// Hidden from Discover except to people you've liked. A privacy control,
  /// so it's free.
  bool invisible = false;
  bool get canSeeLikes => plan.atLeast(Plan.gold);

  /// Plus and up: only show people looking for one of these. Empty = everyone.
  final Set<LookingFor> intentFilter = {};
  bool get canFilterIntentions => plan.atLeast(Plan.plus);

  /// Plus and up: filter Discover down to selfie-verified profiles only.
  bool get canFilterVerified => plan.atLeast(Plan.plus);

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

  String myName = 'Rohan';
  String myJob = 'Software engineer';
  String myPromptLabel = 'My ideal Sunday is';
  String myPrompt =
      'Good food, better company, and finding a new favourite place.';
  Plan plan = Plan.free;

  /// Photos added during sign-up or from Edit profile, main photo first.
  /// When signed in, each is uploaded and its storage path kept here.
  final List<Uint8List> myPhotos = [];
  final Map<Uint8List, String> _photoPaths = Map.identity();
  bool get hasPhoto => myPhotos.isNotEmpty;
  static const maxPhotos = 6;
  bool get canAddPhoto => myPhotos.length < maxPhotos;

  void addPhoto(Uint8List bytes) {
    if (!canAddPhoto) return;
    myPhotos.add(bytes);
    notifyListeners();
    _upload(bytes);
  }

  void _upload(Uint8List bytes) {
    final b = backend;
    if (b == null || !b.signedIn) return;
    b.uploadPhoto(bytes).then((path) {
      // Removed while it was uploading.
      if (!myPhotos.any((p) => identical(p, bytes))) {
        b.deletePhoto(path).ignore();
        return;
      }
      _photoPaths[bytes] = path;
      saveProfile();
    }, onError: (Object e) => _failed('Couldn’t upload that photo. Try again.'));
  }

  void removePhoto(int index) {
    final path = _photoPaths.remove(myPhotos.removeAt(index));
    notifyListeners();
    if (path != null && signedIn) backend!.deletePhoto(path).ignore();
    saveProfile();
  }

  /// Makes the photo at [index] the main one (first in the list — the one
  /// everyone sees first, used as the avatar everywhere in this preview).
  void setMainPhoto(int index) {
    if (index <= 0 || index >= myPhotos.length) return;
    myPhotos.insert(0, myPhotos.removeAt(index));
    notifyListeners();
    saveProfile();
  }

  String myBio = '';
  String myLookingFor = 'Relationship';
  static const lookingForOptions = [
    'Relationship',
    'Friendship first',
    'Open to see',
  ];

  final Set<String> myInterests = {};
  static const interestOptions = [
    'Travel',
    'Coffee',
    'Music',
    'Cooking',
    'Fitness',
    'Art',
    'Books',
    'Movies',
    'Hiking',
    'Dancing',
    'Photography',
    'Pets',
  ];

  bool myProfilePosted = false;
  bool myVerified = false;

  /// A rough sense of how filled-in the preview profile is, out of the
  /// optional extras beyond the required sign-up basics.
  int get profileCompleteness {
    final checks = [
      hasPhoto,
      myJob.trim().isNotEmpty,
      myBio.trim().isNotEmpty,
      myInterests.isNotEmpty,
      myPrompt.trim().isNotEmpty,
      myLookingFor.isNotEmpty,
      myVerified,
    ];
    return (checks.where((done) => done).length * 100 / checks.length).round();
  }

  /// Rewind (undo a pass) comes with Plus and up.
  bool get canRewind => plan.atLeast(Plan.plus);

  /// Every plan has a daily limit, so actions stay fair-use.
  int get remaining => plan.dailyLikes - liked.length;
  bool get outOfLikes => remaining <= 0;
  List<Person> get discover => paused
      ? []
      : _pool
          .where((p) =>
              !passed.contains(p.id) &&
              !liked.contains(p.id) &&
              !conversations.any((chat) => chat.person.id == p.id) &&
              // A real member without a birthday has age 0; don't hide them.
              (p.age == 0 || (p.age >= ages.start && p.age <= ages.end)) &&
              p.distance <= distance &&
              (!verifiedOnly || p.verified) &&
              (intentFilter.isEmpty || p.lookingFor.any(intentFilter.contains)))
          .toList();

  /// Everyone looking for [category], minus profiles passed on or hidden.
  List<Person> exploring(LookingFor category) => _pool
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
    if (p.remote) _remote((b) => b.pass(p.id));
  }

  /// Brings back the last profile passed on and returns it, or null.
  /// Free members can't rewind.
  Person? undoLastPass() {
    if (passHistory.isEmpty || !canRewind) return null;
    final id = passHistory.removeLast();
    passed.remove(id);
    notifyListeners();
    final p = _pool.firstWhere((p) => p.id == id);
    if (p.remote) _remote((b) => b.unpass(id));
    return p;
  }

  void like(Person p, {String target = 'photo', String comment = ''}) {
    if (outOfLikes || liked.contains(p.id)) return;
    liked.add(p.id);
    sentLikes.add(SentLike(p.id, target, comment.trim()));
    notifyListeners();
    if (!p.remote) return;
    _remote((b) async {
      // If they'd already liked you, this like makes a match.
      final matchId =
          await b.like(p.id, target: target, comment: comment.trim());
      if (matchId != null) _addMatch(p, matchId, celebrate: true);
    });
  }

  void removeLike(Person p) {
    incoming.remove(p);
    notifyListeners();
    if (p.remote) _remote((b) => b.pass(p.id));
  }

  /// Likes back someone who liked you. The chat opens right away; for a
  /// real member the match id follows once the like is saved.
  Conversation match(Person p) {
    incoming.remove(p);
    final chat = Conversation(p, [
      if (!p.remote)
        ChatMessage(
            'I love your idea of a perfect Sunday. What’s your favourite spot?')
    ]);
    conversations.insert(0, chat);
    notifyListeners();
    if (p.remote && backend != null && signedIn) {
      chat.pendingMatch = backend!.like(p.id).then((id) {
        chat.matchId = id;
        return id;
      }, onError: (Object e) {
        _failed('Couldn’t save your like. Check your connection.');
        return null;
      });
    }
    return chat;
  }

  void send(Conversation chat, String text) {
    if (text.trim().isEmpty) return;
    chat.messages.add(ChatMessage(text.trim(), mine: true));
    notifyListeners();
    if (!chat.person.remote) return;
    _remote((b) async {
      final id = chat.matchId ?? await chat.pendingMatch;
      if (id == null) throw StateError('no match yet');
      await b.sendMessage(id, text.trim());
    }, failure: 'Couldn’t send that message. Check your connection.');
  }

  /// Ends a match with a real member (block, report or unmatch).
  void forgetRemotely(Person p) {
    if (!p.remote) return;
    final matchIds = [
      for (final c in conversations)
        if (c.person.id == p.id && c.matchId != null) c.matchId!
    ];
    _remote((b) async {
      await b.pass(p.id);
      for (final id in matchIds) {
        await b.unmatch(id);
      }
    });
  }

  void _remote(Future<void> Function(ProfileBackend b) action,
      {String failure = 'Couldn’t reach the server. Check your connection.'}) {
    final b = backend;
    if (b == null || !b.signedIn) return;
    action(b).catchError((Object e) => _failed(failure));
  }

  Conversation _addMatch(Person p, String matchId, {required bool celebrate}) {
    for (final c in conversations) {
      if (c.matchId == matchId || c.person.id == p.id) {
        c.matchId ??= matchId;
        return c;
      }
    }
    incoming.removeWhere((x) => x.id == p.id);
    members.removeWhere((x) => x.id == p.id);
    final chat = Conversation(p, [], matchId: matchId);
    conversations.insert(0, chat);
    notifyListeners();
    if (celebrate) newMatch.value = chat;
    return chat;
  }

  Future<void> _loadCommunitySafely() async {
    try {
      await loadCommunity();
    } catch (_) {
      _failed('Couldn’t load people right now. Check your connection.');
    }
  }

  /// Re-fetches people to discover (e.g. after onboarding or on return to
  /// the Discover tab).
  Future<void> refreshMembers() async {
    final b = backend;
    if (b == null || !b.signedIn) return;
    try {
      final rows = await b.discover();
      members
        ..clear()
        ..addAll(rows
            .map((r) => Person.fromCard(r, b.photoUrl))
            .where((p) => !passed.contains(p.id) && !liked.contains(p.id)));
      notifyListeners();
    } catch (_) {
      _failed('Couldn’t load people right now. Check your connection.');
    }
  }

  /// Loads real members, likes and matches for a signed-in member and
  /// starts listening for new ones. Replaces the demo cast.
  Future<void> loadCommunity() async {
    final b = backend;
    if (b == null || !b.signedIn) return;
    final me = b.user!.id;
    final results = await Future.wait(
        [b.discover(), b.likesReceived(), b.myMatches()]);
    Person card(Map<String, dynamic> r) => Person.fromCard(r, b.photoUrl);
    _clearCommunity();
    members.addAll(results[0].map(card));
    for (final r in results[1]) {
      final p = card(r);
      incoming.add(p);
      likeNotes[p.id] = SentLike(
          p.id, r['target'] as String? ?? 'photo', r['comment'] as String? ?? '');
    }
    for (final r in results[2]) {
      final matchId = r['match_id'] as String;
      final msgs = await b.messages(matchId);
      conversations.add(Conversation(
          card(r),
          [
            for (final m in msgs)
              ChatMessage(m['body'] as String, mine: m['sender'] == me)
          ],
          matchId: matchId));
    }
    _listen(b, me);
    notifyListeners();
  }

  void _listen(ProfileBackend b, String me) {
    if (_channel != null) return;
    _channel = b.listen(onMessage: (m) {
      if (m['sender'] == me) return; // already shown when sent
      for (final c in conversations) {
        if (c.matchId == m['match_id']) {
          c.messages.add(ChatMessage(m['body'] as String));
          notifyListeners();
          return;
        }
      }
    }, onMatch: (m) async {
      if (me != m['user_a'] && me != m['user_b']) return;
      final matchId = m['id'] as String;
      if (conversations.any((c) => c.matchId == matchId)) return;
      final rows = await b.myMatches();
      final row = rows.where((r) => r['match_id'] == matchId).firstOrNull;
      if (row == null) return;
      final p = Person.fromCard(row, b.photoUrl);
      // You liked them back from Likes: that screen already celebrated.
      final mine = conversations.any((c) => c.person.id == p.id);
      _addMatch(p, matchId, celebrate: !mine);
    }, onLike: (_) async {
      final rows = await b.likesReceived();
      for (final r in rows) {
        final p = Person.fromCard(r, b.photoUrl);
        if (incoming.any((x) => x.id == p.id)) continue;
        incoming.insert(0, p);
        likeNotes[p.id] = SentLike(p.id, r['target'] as String? ?? 'photo',
            r['comment'] as String? ?? '');
      }
      notifyListeners();
    });
  }

  void _clearCommunity() {
    members.clear();
    incoming.clear();
    conversations.clear();
    likeNotes.clear();
    passed.clear();
    passHistory.clear();
    liked.clear();
    sentLikes.clear();
  }

  /// Back to the demo cast after logging out.
  void _restoreDemo() {
    final channel = _channel;
    _channel = null;
    if (channel != null) backend?.stopListening(channel).ignore();
    _clearCommunity();
    incoming.addAll(_demoIncoming);
    conversations.addAll(_demoConversations());
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

  void _failed(String message) {
    syncError = message;
    notifyListeners();
  }

  /// The profiles row for the signed-in member.
  Map<String, dynamic> get profileRow => {
        'name': myName,
        'birthday': myBirthday?.toIso8601String().substring(0, 10),
        'gender': myGender,
        'interested_in': interestedIn,
        'city': myCity,
        'job': myJob,
        'bio': myBio,
        'looking_for': myLookingFor,
        'interests': myInterests.toList(),
        'prompt_label': myPromptLabel,
        'prompt_answer': myPrompt,
        'photos': [
          for (final b in myPhotos)
            if (_photoPaths[b] != null) _photoPaths[b]
        ],
        'onboarding_answers': onboardingAnswers,
        'onboarded': onboarded,
        'posted': myProfilePosted,
        'verified': myVerified,
      };

  /// Saves the member's profile in the background. A no-op when not signed
  /// in (tests, or the account-less preview).
  Future<void> saveProfile() {
    final b = backend;
    if (b == null || !b.signedIn) return Future.value();
    return b.saveProfile(profileRow).then((_) {
      if (syncError != null) {
        syncError = null;
        notifyListeners();
      }
    }, onError: (Object e) => _failed('Couldn’t save your profile. Check your connection.'));
  }

  /// A new account starts blank instead of with the demo member's details.
  void startFreshAccount() {
    myName = '';
    myJob = '';
    myCity = '';
    myBio = '';
    myPrompt = '';
    myPromptLabel = 'My ideal Sunday is';
    myLookingFor = 'Relationship';
    myInterests.clear();
    myBirthday = null;
    myGender = '';
    interestedIn = '';
    onboardingAnswers.clear();
    myPhotos.clear();
    _photoPaths.clear();
    myProfilePosted = false;
    myVerified = false;
    onboarded = false;
    notifyListeners();
  }

  /// Loads the signed-in member's profile and photos. Returns whether they
  /// have finished onboarding before (so they can skip straight in).
  Future<bool> loadProfile() async {
    final b = backend;
    if (b == null || !b.signedIn) return false;
    final row = await b.loadProfile();
    startFreshAccount();
    await _loadCommunitySafely();
    if (row == null) return false;
    myName = row['name'] as String? ?? '';
    myBirthday = DateTime.tryParse(row['birthday'] as String? ?? '');
    myGender = row['gender'] as String? ?? '';
    interestedIn = row['interested_in'] as String? ?? '';
    myCity = row['city'] as String? ?? '';
    myJob = row['job'] as String? ?? '';
    myBio = row['bio'] as String? ?? '';
    myLookingFor = row['looking_for'] as String? ?? 'Relationship';
    myInterests.addAll(List<String>.from(row['interests'] as List? ?? []));
    myPromptLabel = row['prompt_label'] as String? ?? 'My ideal Sunday is';
    myPrompt = row['prompt_answer'] as String? ?? '';
    myProfilePosted = row['posted'] as bool? ?? false;
    myVerified = row['verified'] as bool? ?? false;
    (row['onboarding_answers'] as Map? ?? {}).forEach((k, v) =>
        onboardingAnswers[k as String] = List<String>.from(v as List));
    for (final path in List<String>.from(row['photos'] as List? ?? [])) {
      try {
        final bytes = await b.downloadPhoto(path);
        myPhotos.add(bytes);
        _photoPaths[bytes] = path;
      } catch (_) {
        // A missing photo shouldn't stop the rest of the profile loading.
      }
    }
    onboarded = row['onboarded'] as bool? ?? false;
    notifyListeners();
    return onboarded;
  }

  Future<void> logOut() async {
    _restoreDemo();
    await backend?.logOut();
    startFreshAccount();
  }
}
