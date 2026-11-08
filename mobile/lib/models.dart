import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// Comes with supabase_flutter; see pubspec.yaml.
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import 'admin.dart';
import 'backend.dart';
import 'chemistry.dart';
import 'cities.dart';
import 'legal.dart' show termsVersion;
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

/// Activity shown on a Discover card, in order of priority.
enum Presence {
  online('Online', Color(0xFF22C55E)),
  newHere('New here', Color(0xFF3B82F6)),
  recent('Recently online', Color(0xFFF59E0B));

  const Presence(this.label, this.color);
  final String label;
  final Color color;
}

/// Optional lifestyle answers on a profile, as saved (value, label). An
/// empty value means the member preferred not to say.
abstract final class Lifestyle {
  static const drinking = [
    ('never', 'Never'),
    ('socially', 'Socially'),
    ('regularly', 'Regularly'),
  ];
  static const smoking = [
    ('non_smoker', 'Non-smoker'),
    ('socially', 'Socially'),
    ('smoker', 'Smoker'),
  ];
  static const education = [
    ('high_school', 'High school'),
    ('graduate', 'Graduate'),
    ('postgraduate', 'Postgraduate'),
    ('phd', 'PhD'),
  ];
  static const familyPlans = [
    ('wants_kids', 'Wants kids'),
    ('open', 'Open to kids'),
    ('doesnt_want', 'Doesn’t want kids'),
    ('has_kids', 'Has kids'),
  ];

  /// The label for [value], or '' when it isn't set (or isn't known).
  static String label(List<(String, String)> options, String value) {
    for (final (v, l) in options) {
      if (v == value) return l;
    }
    return '';
  }
}

/// Everything the Discover filters sheet can choose. Immutable: the sheet
/// edits a copy, and [PreviewStore.discoverWith] counts what it would show.
@immutable
class DiscoverFilters {
  const DiscoverFilters(
      {this.ages = defaultAges,
      this.strictAges = true,
      this.distance = defaultDistance,
      this.strictDistance = true,
      this.onlineNow = false,
      this.activeToday = false,
      this.newMembers = false,
      this.verifiedOnly = false,
      this.intents = const {},
      this.languages = const {},
      this.heights = anyHeight,
      this.drinking = const {},
      this.smoking = const {},
      this.education = const {},
      this.familyPlans = const {},
      this.hasBioOrPrompt = false,
      this.hasVoice = false,
      this.threePhotos = false});

  static const defaultAges = RangeValues(21, 40);
  static const double defaultDistance = 25;
  static const double minHeight = 140, maxHeight = 210;
  static const anyHeight = RangeValues(minHeight, maxHeight);

  final RangeValues ages;
  final double distance;

  /// Strict: only people inside the range. Otherwise everyone, with people
  /// inside it first.
  final bool strictAges, strictDistance;
  final bool onlineNow, activeToday, newMembers, verifiedOnly;
  final Set<LookingFor> intents;
  final Set<String> languages;
  final RangeValues heights;
  final Set<String> drinking, smoking, education, familyPlans;
  final bool hasBioOrPrompt, hasVoice, threePhotos;

  bool get anyHeightChosen =>
      heights.start <= minHeight && heights.end >= maxHeight;

  DiscoverFilters copyWith(
          {RangeValues? ages,
          bool? strictAges,
          double? distance,
          bool? strictDistance,
          bool? onlineNow,
          bool? activeToday,
          bool? newMembers,
          bool? verifiedOnly,
          Set<LookingFor>? intents,
          Set<String>? languages,
          RangeValues? heights,
          Set<String>? drinking,
          Set<String>? smoking,
          Set<String>? education,
          Set<String>? familyPlans,
          bool? hasBioOrPrompt,
          bool? hasVoice,
          bool? threePhotos}) =>
      DiscoverFilters(
          ages: ages ?? this.ages,
          strictAges: strictAges ?? this.strictAges,
          distance: distance ?? this.distance,
          strictDistance: strictDistance ?? this.strictDistance,
          onlineNow: onlineNow ?? this.onlineNow,
          activeToday: activeToday ?? this.activeToday,
          newMembers: newMembers ?? this.newMembers,
          verifiedOnly: verifiedOnly ?? this.verifiedOnly,
          intents: intents ?? this.intents,
          languages: languages ?? this.languages,
          heights: heights ?? this.heights,
          drinking: drinking ?? this.drinking,
          smoking: smoking ?? this.smoking,
          education: education ?? this.education,
          familyPlans: familyPlans ?? this.familyPlans,
          hasBioOrPrompt: hasBioOrPrompt ?? this.hasBioOrPrompt,
          hasVoice: hasVoice ?? this.hasVoice,
          threePhotos: threePhotos ?? this.threePhotos);

  /// Choices inside "More preferences".
  int get moreCount => [
        languages.isNotEmpty,
        !anyHeightChosen,
        drinking.isNotEmpty,
        smoking.isNotEmpty,
        education.isNotEmpty,
        familyPlans.isNotEmpty,
        hasBioOrPrompt,
        hasVoice,
        threePhotos,
      ].where((on) => on).length;

  /// Every choice that differs from the defaults.
  int get activeCount =>
      moreCount +
      [
        ages != defaultAges,
        !strictAges,
        distance != defaultDistance,
        !strictDistance,
        onlineNow,
        activeToday,
        newMembers,
        verifiedOnly,
        intents.isNotEmpty,
      ].where((on) => on).length;

  /// A real member without a birthday has age 0; don't hide them.
  bool inAgeRange(Person p) =>
      p.age == 0 || (p.age >= ages.start && p.age <= ages.end);
  bool inDistance(Person p) => p.distance <= distance;

  /// Everything except age and distance, which can be soft.
  bool matches(Person p) {
    bool pick(Set<String> chosen, String value) =>
        chosen.isEmpty || chosen.contains(value);
    final h = p.heightCm;
    return (!onlineNow || p.presence == Presence.online) &&
        (!activeToday || p.activeToday) &&
        (!newMembers || p.isNew) &&
        (!verifiedOnly || p.verified) &&
        (intents.isEmpty || p.lookingFor.any(intents.contains)) &&
        (languages.isEmpty || p.languages.any(languages.contains)) &&
        (anyHeightChosen ||
            (h != null && h >= heights.start && h <= heights.end)) &&
        pick(drinking, p.drinking) &&
        pick(smoking, p.smoking) &&
        pick(education, p.education) &&
        pick(familyPlans, p.familyPlans) &&
        (!hasBioOrPrompt ||
            p.bio.trim().isNotEmpty ||
            p.answer.trim().isNotEmpty) &&
        (!hasVoice || p.hasVoice) &&
        (!threePhotos || p.photoCount >= 3);
  }

  /// Filters and orders [pool]: with a strict range only people inside it,
  /// otherwise people inside it first (in their original order), then the
  /// rest — nearest first when distance is soft.
  List<Person> apply(Iterable<Person> pool) {
    final kept = [
      for (final p in pool)
        if (matches(p) &&
            (!strictAges || inAgeRange(p)) &&
            (!strictDistance || inDistance(p)))
          p
    ];
    if (strictAges && strictDistance) return kept;
    int rank(Person p) =>
        (inAgeRange(p) ? 0 : 2) + (inDistance(p) ? 0 : 1);
    // Sorted with the original position as a tie-break, so it's stable.
    final indexed = kept.indexed.toList()
      ..sort((x, y) {
        final (i, a) = x;
        final (j, b) = y;
        final byRank = rank(a).compareTo(rank(b));
        if (byRank != 0) return byRank;
        if (!inDistance(a)) {
          final byKm = a.distance.compareTo(b.distance);
          if (byKm != 0) return byKm;
        }
        return i.compareTo(j);
      });
    return [for (final (_, p) in indexed) p];
  }

  Map<String, dynamic> toJson() => {
        'ages': [ages.start, ages.end],
        'strictAges': strictAges,
        'distance': distance,
        'strictDistance': strictDistance,
        'onlineNow': onlineNow,
        'activeToday': activeToday,
        'newMembers': newMembers,
        'verifiedOnly': verifiedOnly,
        'intents': [for (final i in intents) i.name],
        'languages': languages.toList(),
        'heights': [heights.start, heights.end],
        'drinking': drinking.toList(),
        'smoking': smoking.toList(),
        'education': education.toList(),
        'familyPlans': familyPlans.toList(),
        'hasBioOrPrompt': hasBioOrPrompt,
        'hasVoice': hasVoice,
        'threePhotos': threePhotos,
      };

  /// Anything missing or malformed falls back to its default.
  factory DiscoverFilters.fromJson(Map<String, dynamic> j) {
    RangeValues range(Object? v, RangeValues fallback, double lo, double hi) {
      if (v is! List || v.length != 2 || v[0] is! num || v[1] is! num) {
        return fallback;
      }
      final a = (v[0] as num).toDouble().clamp(lo, hi);
      final b = (v[1] as num).toDouble().clamp(lo, hi);
      return a <= b ? RangeValues(a, b) : fallback;
    }

    Set<String> strings(Object? v) =>
        v is List ? {for (final s in v) if (s is String) s} : const {};
    bool flag(String k, bool fallback) => j[k] is bool ? j[k] as bool : fallback;
    const d = DiscoverFilters();
    return DiscoverFilters(
        ages: range(j['ages'], defaultAges, 18, 60),
        strictAges: flag('strictAges', d.strictAges),
        distance: j['distance'] is num
            ? (j['distance'] as num).toDouble().clamp(1, 100)
            : defaultDistance,
        strictDistance: flag('strictDistance', d.strictDistance),
        onlineNow: flag('onlineNow', false),
        activeToday: flag('activeToday', false),
        newMembers: flag('newMembers', false),
        verifiedOnly: flag('verifiedOnly', false),
        intents: {
          for (final name in strings(j['intents']))
            for (final l in LookingFor.values)
              if (l.name == name) l
        },
        languages: strings(j['languages']),
        heights: range(j['heights'], anyHeight, minHeight, maxHeight),
        drinking: strings(j['drinking']),
        smoking: strings(j['smoking']),
        education: strings(j['education']),
        familyPlans: strings(j['familyPlans']),
        hasBioOrPrompt: flag('hasBioOrPrompt', false),
        hasVoice: flag('hasVoice', false),
        threePhotos: flag('threePhotos', false));
  }
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
      this.voiceLabel = '',
      this.voiceUrl = '',
      this.verified = false,
      this.activeNow = false,
      this.bio = '',
      this.interests = const [],
      this.city = 'Bengaluru',
      this.photoUrls = const [],
      this.remote = false,
      this.heightCm,
      this.languages = const [],
      this.lastSeenAt,
      this.joinedAt,
      this.drinking = '',
      this.smoking = '',
      this.education = '',
      this.familyPlans = ''});

  final int? heightCm;

  /// Optional lifestyle answers (see [Lifestyle]); '' when not given.
  final String drinking, smoking, education, familyPlans;

  /// Real members' uploaded photos; a demo person has their one portrait.
  int get photoCount =>
      photoUrls.isNotEmpty ? photoUrls.length : (photo.isNotEmpty ? 1 : 0);

  /// Seen in the last day (Online, Recently online, or a new member who was
  /// around recently).
  bool get activeToday {
    final p = presence;
    if (p == Presence.online || p == Presence.recent) return true;
    final seen = lastSeenAt;
    return remote &&
        seen != null &&
        DateTime.now().difference(seen) < const Duration(hours: 24);
  }

  /// Joined in the last week.
  bool get isNew =>
      presence == Presence.newHere ||
      (remote &&
          joinedAt != null &&
          DateTime.now().difference(joinedAt!) <= const Duration(days: 7));

  /// When a real member was last active (null when they hide it, and for
  /// automated profiles), and when they joined.
  final DateTime? lastSeenAt, joinedAt;

  /// The Discover card's activity badge, or null for none.
  Presence? get presence {
    final now = DateTime.now();
    final seen = lastSeenAt;
    if (!remote) return activeNow ? Presence.online : null;
    if (seen != null && now.difference(seen) < const Duration(minutes: 5)) {
      return Presence.online;
    }
    if (joinedAt != null && now.difference(joinedAt!) <= const Duration(days: 7)) {
      return Presence.newHere;
    }
    if (seen != null && now.difference(seen) < const Duration(hours: 24)) {
      return Presence.recent;
    }
    return null;
  }
  final List<String> languages;

  /// A real member, from a Supabase card (see `discover_members`).
  factory Person.fromCard(
      Map<String, dynamic> r, String Function(String path) photoUrl,
      {String Function(String path)? voiceUrl}) {
    final voicePath = r['voice_path'] as String? ?? '';
    final looking = switch (r['looking_for'] as String? ?? '') {
      'Casual' || 'Short term' => LookingFor.shortTerm,
      'Chit chat' || 'Friendship first' => LookingFor.newFriends,
      // 'Hangout' is no longer offered; older profiles may still have it.
      'Hangout' || 'Open to see' => LookingFor.coffeeDate,
      _ => LookingFor.longTerm,
    };
    return Person(
        id: r['id'] as String,
        name: r['name'] as String? ?? '',
        age: (r['age'] as num?)?.toInt() ?? 0,
        job: r['job'] as String? ?? '',
        photo: '',
        // Rounded server-side from city centres; unknown is "Nearby".
        distance: (r['distance_km'] as num?)?.toInt() ?? 0,
        answer: r['prompt_answer'] as String? ?? '',
        lookingFor: [looking],
        verified: r['verified'] as bool? ?? false,
        bio: r['bio'] as String? ?? '',
        interests: List<String>.from(r['interests'] as List? ?? const []),
        city: r['city'] as String? ?? '',
        heightCm: (r['height_cm'] as num?)?.toInt(),
        languages: List<String>.from(r['languages'] as List? ?? const []),
        voiceLabel: r['voice_prompt_label'] as String? ?? '',
        voiceSeconds: (r['voice_seconds'] as num?)?.toInt() ?? 0,
        voiceUrl: voicePath.isEmpty || voiceUrl == null ? '' : voiceUrl(voicePath),
        photoUrls: [
          for (final path in List<String>.from(r['photos'] as List? ?? const []))
            photoUrl(path)
        ],
        lastSeenAt: DateTime.tryParse(r['last_seen_at'] as String? ?? '')?.toLocal(),
        joinedAt: DateTime.tryParse(r['joined_at'] as String? ?? '')?.toLocal(),
        drinking: r['drinking'] as String? ?? '',
        smoking: r['smoking'] as String? ?? '',
        education: r['education'] as String? ?? '',
        familyPlans: r['family_plans'] as String? ?? '',
        remote: true);
  }

  final String id, name, job, photo, answer;
  final String city;

  /// Real members' photos (public Storage URLs); demo people use assets.
  final List<String> photoUrls;

  /// True for real members from Supabase; likes, passes and chat with them
  /// are saved. Demo people stay local.
  final bool remote;

  /// Sample profile flag (disabled so bot profiles appear as regular profiles).
  bool get sample => false;

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

  /// A real member's recorded voice prompt: the question they answered and
  /// the public URL of the recording. Empty when they haven't recorded one.
  final String voiceLabel, voiceUrl;
  bool get hasVoice => voicePrompt.isNotEmpty || voiceUrl.isNotEmpty;

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
      heightCm: 165,
      languages: ['English', 'Kannada'],
      drinking: 'socially',
      smoking: 'non_smoker',
      education: 'postgraduate',
      familyPlans: 'wants_kids',
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
      heightCm: 170,
      languages: ['English', 'Hindi'],
      drinking: 'never',
      smoking: 'non_smoker',
      education: 'graduate',
      familyPlans: 'open',
      bio: 'Architect who sketches cafés instead of buildings on Sundays. Long walks, always.',
      interests: ['Travel', 'Art', 'Pets'],
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
          'Finding a little café with a big personality. Bonus points if there’s live music.'),
  Person(
      id: 'isha',
      heightCm: 158,
      languages: ['English', 'Hindi', 'Marathi'],
      drinking: 'regularly',
      smoking: 'socially',
      education: 'graduate',
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
      languages: ['English', 'Tamil'],
      drinking: 'socially',
      smoking: 'non_smoker',
      education: 'phd',
      familyPlans: 'wants_kids',
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
  free('Free', '₹0', 'The essential dating experience', 8, 0, 1, [
    '8 likes each day',
    '1 Spark each week to stand out',
    'Like profiles and match when interest is mutual',
    'Message your matches',
    'A Chemistry summary with each person',
    'Blocking, reporting, privacy controls and account deletion',
  ]),
  plus('Plus', '₹249', 'Simple, affordable upgrade', 25, 0, 1, [
    'Everything in Free',
    '25 likes each day',
    'Filter by relationship intentions',
    'A fuller Chemistry explanation, including where you differ',
    'Rewind your last accidental pass',
  ]),
  gold('Gold', '₹499', 'The mainstream premium tier', 50, 2, 2, [
    'Everything in Plus',
    'See who has liked you',
    '50 likes each day',
    '2 Sparks each week',
    '2 profile boosts each month',
  ]),
  platinum('Platinum', '₹899', 'The full-featured premium experience', 100, 5, 3, [
    'Everything in Gold',
    '100 likes each day',
    '3 Sparks each week',
    '5 profile boosts each month',
    'A detailed Chemistry report, area by area',
    'Hangouts: host or join plans nearby',
  ]);

  const Plan(this._title, this.price, this._tagline, this._dailyLikes,
      this._monthlyBoosts, this._weeklySparks, this._perks);
  final String _title, price, _tagline;
  final int _dailyLikes, _monthlyBoosts, _weeklySparks;
  final List<String> _perks;

  /// The admin panel can rename a tier and change what it includes; the
  /// built-in values are the fallback.
  PlanConfig? get _c => planConfigs[this];
  String get title => _c?.title ?? _title;
  String get tagline => _c?.tagline ?? _tagline;
  int get dailyLikes => _c?.dailyLikes ?? _dailyLikes;
  int get monthlyBoosts => _c?.monthlyBoosts ?? _monthlyBoosts;
  int get weeklySparks => _c?.weeklySparks ?? _weeklySparks;
  List<String> get perks => _c?.perks ?? _perks;
  String get highlight => _c?.highlight ?? (this == Plan.gold ? 'Most popular' : '');

  bool atLeast(Plan other) => index >= other.index;

  /// The price the team set in the admin panel, or the built-in one.
  String get displayPrice => planPrices[this] ?? price;
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

/// Tags for plans built around an event, so people with a spare ticket
/// can find a +1 (see migration 035).
enum HangoutEvent {
  concert('Concert', Icons.music_note_rounded),
  sports('IPL / Sports', Icons.sports_cricket_rounded),
  comedy('Stand-up', Icons.theater_comedy_rounded),
  movie('Movie', Icons.local_movies_rounded);

  const HangoutEvent(this.label, this.icon);
  final String label;
  final IconData icon;

  static HangoutEvent? fromName(String? name) {
    for (final e in values) {
      if (e.name == name) return e;
    }
    return null;
  }
}

/// How long a member's plan stays up without an accepted guest, and how
/// long an accepted pair has to lock in the time and place.
const hangoutLifetime = Duration(hours: 24);
const hangoutLockWindow = Duration(hours: 2);

/// Longest voice note when answering a plan's icebreaker.
const maxHangoutVoiceSeconds = 20;

/// A plan someone hosts and others ask to join. A null [host] means you.
class Hangout {
  Hangout(
      {required this.id,
      required this.host,
      required this.kind,
      required this.title,
      required this.startsAt,
      required this.area,
      this.city = '',
      this.venue = '',
      this.note = '',
      this.lookingFor = '',
      required this.spots,
      int? spotsLeft,
      this.distanceKm,
      this.status,
      this.pendingRequests = 0,
      this.official = false,
      this.prompt = '',
      this.event,
      this.expiresAt,
      this.acceptedAt})
      : spotsLeft = spotsLeft ?? spots;

  /// From a `hangouts_near` row (see migration 020).
  factory Hangout.fromRow(Map<String, dynamic> r, String Function(String) photoUrl) {
    final mine = r['mine'] as bool? ?? false;
    return Hangout(
        id: r['id'] as String,
        host: mine
            ? null
            : Person(
                id: r['host'] as String,
                name: r['host_name'] as String? ?? '',
                age: (r['host_age'] as num?)?.toInt() ?? 0,
                job: '',
                photo: '',
                distance: (r['distance_km'] as num?)?.toInt() ?? 0,
                answer: '',
                lookingFor: const [],
                verified: r['host_verified'] as bool? ?? false,
                city: r['city'] as String? ?? '',
                photoUrls: [
                  for (final path in List<String>.from(r['host_photos'] as List? ?? const []))
                    photoUrl(path)
                ],
                remote: true),
        kind: HangoutKind.values.firstWhere((k) => k.name == r['kind'],
            orElse: () => HangoutKind.coffee),
        title: r['title'] as String? ?? '',
        startsAt: DateTime.parse(r['starts_at'] as String).toLocal(),
        area: r['area'] as String? ?? '',
        city: r['city'] as String? ?? '',
        venue: r['venue'] as String? ?? '',
        note: r['note'] as String? ?? '',
        lookingFor: r['looking_for'] as String? ?? '',
        spots: (r['spots'] as num?)?.toInt() ?? 1,
        spotsLeft: (r['spots_left'] as num?)?.toInt(),
        distanceKm: (r['distance_km'] as num?)?.toInt(),
        status: r['my_status'] as String?,
        pendingRequests: (r['pending_requests'] as num?)?.toInt() ?? 0,
        official: r['host_official'] as bool? ?? false,
        prompt: r['prompt'] as String? ?? '',
        event: HangoutEvent.fromName(r['event_tag'] as String?),
        expiresAt: DateTime.tryParse(r['expires_at'] as String? ?? '')?.toLocal(),
        acceptedAt:
            DateTime.tryParse(r['my_accepted_at'] as String? ?? '')?.toLocal());
  }

  /// The host's icebreaker; asking to join means answering it out loud.
  final String prompt;
  final HangoutEvent? event;

  /// When the plan drops off the feed if nobody is accepted; null for the
  /// team's plans, which don't expire.
  final DateTime? expiresAt;

  /// When the host accepted you, which starts the 2-hour lock-in window.
  DateTime? acceptedAt;

  final String id, title, area, city, venue, note, lookingFor;

  /// Hosted by the Everlane team's own profile (made in the admin panel).
  final bool official;
  final Person? host;
  final HangoutKind kind;
  final DateTime startsAt;
  final int spots, spotsLeft, pendingRequests;
  final int? distanceKm;

  /// Your request: null (none), 'pending', 'accepted' or 'declined'.
  String? status;

  bool get mine => host == null;

  /// "Tonight, 8:00 pm", "Tomorrow, 4:00 pm" or "Sat 1 Nov, 7:00 pm".
  String get when => whenLabel(startsAt);

  /// The public area, e.g. "Kurla, Mumbai".
  String get place => [area, city.split(',').first]
      .where((s) => s.trim().isNotEmpty)
      .toSet()
      .join(', ');
}

String whenLabel(DateTime t) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final diff = DateTime(t.year, t.month, t.day).difference(today).inDays;
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final time = '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'am' : 'pm'}';
  final day = switch (diff) {
    0 => t.hour >= 17 ? 'Tonight' : 'Today',
    1 => 'Tomorrow',
    _ => '${days[t.weekday - 1]} ${t.day} ${months[t.month - 1]}',
  };
  return '$day, $time';
}

/// Someone asking to join one of your plans, with their voice answer.
class HangoutRequest {
  HangoutRequest(this.hangoutId, this.person, this.status,
      {this.voiceUrl = '', this.voiceSeconds = 0, this.acceptedAt});
  final String hangoutId;
  final Person person;
  final String voiceUrl;
  final int voiceSeconds;
  String status;
  DateTime? acceptedAt;
}

/// "5h 12m" or "38m": how long is left until [t], or null once it's passed.
String? timeLeft(DateTime? t) {
  if (t == null) return null;
  final d = t.difference(DateTime.now());
  if (d.isNegative) return null;
  final h = d.inHours, m = d.inMinutes % 60;
  return h > 0 ? '${h}h ${m}m' : '${d.inMinutes.clamp(1, 59)}m';
}

DateTime _at(int days, int hour, [int minute = 0]) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day + days, hour, minute);
}

List<Hangout> demoHangouts() {
  // Demo plans were posted a few hours ago, so the 24-hour clock shows.
  DateTime posted(int hoursAgo) =>
      DateTime.now().subtract(Duration(hours: hoursAgo)).add(hangoutLifetime);
  return [
    Hangout(
        id: 'h1',
        host: demoPeople[0],
        kind: HangoutKind.coffee,
        title: 'Filter coffee and a bookstore',
        startsAt: _at(1, 10, 30),
        area: 'Church Street',
        city: 'Bengaluru',
        note: 'Slow morning, good books, no rush.',
        spots: 2,
        prompt: 'Best late-night chai spot in town?',
        expiresAt: posted(3)),
    Hangout(
        id: 'h2',
        host: demoPeople[3],
        kind: HangoutKind.dinner,
        title: 'Dinner and good conversation',
        startsAt: _at(0, 20),
        area: 'Indiranagar',
        city: 'Bengaluru',
        note: 'No phones at the table.',
        lookingFor: 'People who love long conversations',
        spots: 3,
        prompt: 'What’s a dish you could eat every single day?',
        expiresAt: posted(9)),
    Hangout(
        id: 'h3',
        host: demoPeople[2],
        kind: HangoutKind.movie,
        title: 'Spare ticket: Coldplay, Saturday',
        startsAt: _at(2, 19, 30),
        area: 'DY Patil Stadium',
        city: 'Mumbai',
        note: 'I have one extra pass. Come sing along.',
        spots: 1,
        prompt: 'Coldplay or Diljit?',
        event: HangoutEvent.concert,
        expiresAt: posted(1)),
    Hangout(
        id: 'h4',
        host: demoPeople[1],
        kind: HangoutKind.outdoors,
        title: 'Sunset walk at Cubbon Park',
        startsAt: _at(0, 17, 30),
        area: 'Cubbon Park',
        city: 'Bengaluru',
        note: 'Easy pace, followed by chai.',
        spots: 4,
        prompt: 'Mountains or beaches, and why?',
        expiresAt: posted(14)),
    Hangout(
        id: 'h5',
        host: demoPeople[2],
        kind: HangoutKind.drinks,
        title: 'IPL night: RCB vs CSK screening',
        startsAt: _at(1, 19),
        area: 'MG Road',
        city: 'Bengaluru',
        note: 'Big screen, small group.',
        spots: 2,
        prompt: 'Who’s winning the IPL this year?',
        event: HangoutEvent.sports,
        expiresAt: posted(6)),
  ];
}

class ChatMessage {
  ChatMessage(this.text, {this.mine = false, DateTime? sentAt})
      : sentAt = sentAt ?? DateTime.now();

  /// From a Supabase `messages` row.
  factory ChatMessage.fromRow(Map<String, dynamic> m, {bool mine = false}) =>
      ChatMessage(m['body'] as String,
          mine: mine,
          sentAt: DateTime.tryParse(m['created_at'] as String? ?? '')?.toLocal());

  final String text;
  final bool mine;
  final DateTime sentAt;
}

/// Areas are about 1 km across: coordinates are rounded down to 0.01° and
/// shown at the centre of that square, so no one's exact spot is kept.
const areaStep = 0.01;
(double, double) snapToArea(double lat, double lng) => (
      ((lat / areaStep).floor() + .5) * areaStep,
      ((lng / areaStep).floor() + .5) * areaStep,
    );

/// Someone you were in the same area as on the same day (Happn-style), at
/// the centre of the area you last shared.
class Crossing {
  const Crossing(
      {required this.person,
      required this.lat,
      required this.lng,
      required this.lastDay,
      required this.times,
      this.area = ''});

  /// From a Supabase `crossed_paths` row.
  factory Crossing.fromRow(Map<String, dynamic> r, Person person) => Crossing(
      person: person,
      lat: (r['area_lat'] as num).toDouble(),
      lng: (r['area_lng'] as num).toDouble(),
      lastDay: DateTime.tryParse(r['last_day'] as String? ?? '') ??
          DateTime.now(),
      times: (r['times'] as num?)?.toInt() ?? 1);

  final Person person;
  final double lat, lng;
  final DateTime lastDay;
  final int times;

  /// A place name for demo areas; real areas have none (no reverse geocoding).
  final String area;

  String get areaKey => '${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)}';
}

class SentLike {
  const SentLike(this.personId, this.target, this.comment,
      {this.spark = false});
  final String personId, target, comment;

  /// A Spark puts this like at the top of their Likes, highlighted.
  final bool spark;
}

class Conversation {
  Conversation(this.person, this.messages, {this.matchId});
  final Person person;
  final List<ChatMessage> messages;

  /// The Supabase match, for real members. Null for demo chats, and briefly
  /// while a like back is still turning into a match.
  String? matchId;
  Future<String?>? pendingMatch;

  /// Messages from them you haven't opened the chat to see yet.
  int unread = 0;
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

  /// A warning from the moderation team, shown until the member dismisses it.
  String adminWarning = '';

  void acknowledgeWarning() {
    adminWarning = '';
    notifyListeners();
    _remote((b) => b.acknowledgeWarning());
  }

  /// Sends a report to the moderation team (real members only). Awaited
  /// before blocking, so the server can keep the last few messages first.
  Future<void> report(Person p, String reason) async {
    final b = backend;
    if (!p.remote || b == null || !b.signedIn) return;
    try {
      await b.report(p.id, reason);
    } catch (_) {
      _failed('Couldn’t send your report. Try again.');
    }
  }

  final Set<String> passed = {};
  final Set<String> liked = {};
  final List<SentLike> sentLikes = [];
  final List<Person> incoming = [..._demoIncoming];
  final List<Conversation> conversations = [..._demoConversations()];

  static final _demoIncoming = [demoPeople[1], demoPeople[2]];
  static List<Conversation> _demoConversations() => [
        Conversation(demoPeople[3], [
          ChatMessage('You liked their answer to “My ideal Sunday”',
              mine: true,
              sentAt: DateTime.now().subtract(const Duration(days: 1, hours: 3))),
          ChatMessage('Okay, important question: what’s your go-to dessert?',
              sentAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)))
        ]),
      ];

  /// Signed-in members see real people from Supabase instead of the demo
  /// cast; the account-less preview (and tests) keep the demo data.
  bool get live => signedIn;
  final List<Person> members = [];

  /// Crossed paths. Sharing your area is opt-in and off by default; only a
  /// ~1 km area and the day are ever saved.
  bool shareArea = false;
  (double, double)? myArea;
  final List<Crossing> crossings = [..._demoCrossings()];

  static List<Crossing> _demoCrossings() {
    final now = DateTime.now();
    Crossing at(int i, double lat, double lng, String area, int daysAgo,
            int times) =>
        Crossing(
            person: demoPeople[i % demoPeople.length],
            lat: lat,
            lng: lng,
            area: area,
            lastDay: now.subtract(Duration(days: daysAgo)),
            times: times);
    return [
      at(0, 12.9785, 77.6405, '100 Feet Road, Indiranagar', 0, 3),
      at(2, 12.9785, 77.6405, '100 Feet Road, Indiranagar', 1, 1),
      at(1, 12.9715, 77.6095, 'MG Road', 2, 2),
      at(3, 12.9355, 77.6245, 'Koramangala 5th Block', 4, 1),
    ];
  }

  /// Saves the area you're in now (after rounding it) and reloads who
  /// you've crossed paths with. In the account-less preview only the map
  /// marker moves.
  Future<void> recordArea(double lat, double lng) async {
    myArea = snapToArea(lat, lng);
    shareArea = true;
    notifyListeners();
    final b = backend;
    if (b == null || !b.signedIn) return;
    try {
      await b.recordArea(myArea!.$1, myArea!.$2);
      await refreshCrossings();
    } catch (_) {
      _failed('Couldn’t update your area. Check your connection.');
    }
  }

  /// Turning sharing off also deletes your saved areas.
  void stopSharingArea() {
    shareArea = false;
    myArea = null;
    notifyListeners();
    final b = backend;
    if (b == null || !b.signedIn) return;
    b.clearAreas().then((_) => refreshCrossings(),
        onError: (Object e) =>
            _failed('Couldn’t clear your area history. Try again.'));
  }

  Future<void> refreshCrossings() async {
    final b = backend;
    if (b == null || !b.signedIn) return;
    try {
      final rows = await b.crossedPaths();
      crossings
        ..clear()
        ..addAll([
          for (final r in rows)
            Crossing.fromRow(
                r, Person.fromCard(r, b.photoUrl, voiceUrl: b.voiceUrl))
        ].where((c) => !passed.contains(c.person.id)));
      notifyListeners();
    } catch (_) {
      _failed('Couldn’t load crossed paths right now.');
    }
  }

  /// What a real member wrote when they liked you, keyed by their id.
  final Map<String, SentLike> likeNotes = {};

  /// Set when a new match arrives (your like back, or theirs); the app shell
  /// shows the celebration and clears it.
  final ValueNotifier<Conversation?> newMatch = ValueNotifier(null);

  /// "Your hangout request is accepted" for the app shell to show (instead
  /// of a match celebration, since a hangout connects you through a match).
  final ValueNotifier<String?> hangoutAccepted = ValueNotifier(null);
  RealtimeChannel? _channel;
  Timer? _matchPollTimer;

  List<Person> get _pool => live ? members : demoPeople;
  /// Everything chosen in the Discover filters sheet.
  DiscoverFilters filters = const DiscoverFilters();

  RangeValues get ages => filters.ages;
  set ages(RangeValues v) => filters = filters.copyWith(ages: v);
  double get distance => filters.distance;
  set distance(double v) => filters = filters.copyWith(distance: v);
  bool get verifiedOnly => filters.verifiedOnly;
  set verifiedOnly(bool v) => filters = filters.copyWith(verifiedOnly: v);

  /// Plus and up: only show people looking for one of these. Empty = everyone.
  Set<LookingFor> get intentFilter => filters.intents;

  /// Discover asks the server for people within [distance] of where you
  /// are (your shared position, or your city) — or everyone, nearest first,
  /// when distance isn't strict.
  int? get _maxKm => filters.strictDistance ? distance.round() : null;

  /// Saves new filters, on this device too, and updates Discover.
  void setFilters(DiscoverFilters next) {
    filters = next;
    _filtersTouched = true;
    notifyListeners();
    _saveFilters();
  }

  static const _filtersKey = 'everlane.discover_filters';
  bool _filtersTouched = false;

  /// Like dismissed announcements, filters are only remembered on a device
  /// with a backend; tests and the bare preview keep them in memory.
  void _saveFilters() {
    if (backend == null) return;
    final json = jsonEncode(filters.toJson());
    SharedPreferences.getInstance()
        .then((p) => p.setString(_filtersKey, json))
        .catchError((Object _) => false);
  }

  /// Restores the filters saved on this device, at start-up.
  Future<void> loadFilters() async {
    if (backend == null) return;
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_filtersKey);
      // Changed before the saved ones arrived: keep the new choice.
      if (raw == null || _filtersTouched) return;
      final loaded =
          DiscoverFilters.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      final refetch = loaded.strictDistance != filters.strictDistance ||
          loaded.distance.round() != filters.distance.round();
      filters = loaded.copyWith(
          verifiedOnly: canFilterVerified && loaded.verifiedOnly,
          intents: canFilterIntentions ? loaded.intents : const {});
      notifyListeners();
      if (refetch && members.isNotEmpty) refreshMembers().ignore();
    } catch (_) {
      // Defaults, then.
    }
  }

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
    _recordConsent();
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
    saveProfile();
  }

  void deleteQuizAnswers() {
    quizAnswers.clear();
    notifyListeners();
    saveProfile();
  }

  /// Quiz answers of real members (and sample profiles), by member id.
  final Map<String, Answers> remoteQuizAnswers = {};

  /// Null until you've answered at least one quiz question.
  Chemistry? chemistryWith(Person p) => quizAnswers.isEmpty
      ? null
      : Chemistry.between(quizAnswers,
          remoteQuizAnswers[p.id] ?? demoQuizAnswers[p.id] ?? const {});

  /// Fetches quiz answers for every member on screen, for Chemistry.
  Future<void> _loadQuizAnswers(ProfileBackend b) async {
    final ids = {
      for (final p in [...members, ...incoming, for (final c in conversations) c.person])
        if (p.remote && !remoteQuizAnswers.containsKey(p.id)) p.id
    };
    if (ids.isEmpty) return;
    try {
      remoteQuizAnswers.addAll(await b.quizAnswersOf(ids.toList()));
      notifyListeners();
    } catch (_) {
      // Chemistry just stays hidden for them.
    }
  }

  /// The premium dark look is the default; Settings can switch to light.
  bool darkMode = true;

  /// Hidden from Discover except to people you've liked. A privacy control,
  /// so it's free.
  bool invisible = false;

  /// Others see "Online" / "Recently online" on your card (Preferences).
  bool showOnline = true;

  void setShowOnline(bool value) {
    showOnline = value;
    notifyListeners();
    final b = backend;
    if (b != null && b.signedIn) b.setShowOnline(value).ignore();
  }
  bool get canSeeLikes => plan.atLeast(Plan.gold);

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

  /// True when [plan] was paid for (a verified UPI payment) or given by the
  /// team, rather than picked in the preview. Such a plan runs until
  /// [planUntil] (or for good when that's null) and can't be dropped here.
  bool planPaid = false;
  DateTime? planUntil;

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

  /// Hinge-style voice prompt: a question and a recorded answer (WAV, up to
  /// 30 seconds). When signed in, the recording is uploaded and its storage
  /// path kept in [_voicePath].
  String myVoiceLabel = '';
  Uint8List? myVoice;
  int myVoiceSeconds = 0;
  String _voicePath = '';

  /// Whether the profiles table has the voice columns (migration 005), so
  /// saving keeps working on a database that hasn't been migrated yet.
  bool _voiceColumns = false;
  bool get hasVoice => myVoice != null || _voicePath.isNotEmpty;

  /// Public URL of the saved recording, for playback once it's uploaded.
  String get myVoiceUrl =>
      _voicePath.isEmpty || backend == null ? '' : backend!.voiceUrl(_voicePath);

  static const voicePromptOptions = [
    'My simple pleasures',
    'A story only I can tell',
    'The way to win me over is',
    'Two truths and a lie',
    'My most irrational fear',
    'I’ll know it’s right when',
  ];

  Future<void> setVoice(String label, Uint8List wav, int seconds) async {
    final old = _voicePath;
    myVoiceLabel = label;
    myVoice = wav;
    myVoiceSeconds = seconds;
    _voicePath = '';
    notifyListeners();
    final b = backend;
    if (b == null || !b.signedIn) return;
    try {
      _voicePath = await b.uploadVoice(wav);
      await saveProfile();
      if (old.isNotEmpty) b.deleteVoice(old).ignore();
    } catch (_) {
      _failed('Couldn’t save your voice prompt. Try again.');
    }
  }

  void removeVoice() {
    final path = _voicePath;
    myVoiceLabel = '';
    myVoice = null;
    myVoiceSeconds = 0;
    _voicePath = '';
    notifyListeners();
    if (path.isNotEmpty && signedIn) backend!.deleteVoice(path).ignore();
    saveProfile();
  }

  /// Permanently deletes the signed-in member's account, photos and voice
  /// prompt. Throws if Supabase couldn't do it, leaving them signed in. In
  /// the account-less preview it clears the local profile instead.
  Future<void> deleteAccount() async {
    final b = backend;
    if (b == null || !b.signedIn) {
      _restoreDemo();
      startFreshAccount();
      return;
    }
    await b.deleteAccount(
        photos: [..._photoPaths.values], voice: _voicePath);
    _restoreDemo();
    startFreshAccount();
  }

  String myBio = '';
  String myLookingFor = 'Long term';
  static const lookingForOptions = [
    'Casual',
    'Long term',
    'Chit chat',
    'Short term',
  ];

  /// Height in cm, and languages spoken (optional), from sign-up.
  int? myHeightCm;
  final Set<String> myLanguages = {};

  /// Optional lifestyle answers (see [Lifestyle]); '' = prefer not to say.
  String myDrinking = '', mySmoking = '', myEducation = '', myFamilyPlans = '';
  static List<String> languageOptions = [
    'English',
    'Hindi',
    'Kannada',
    'Tamil',
    'Telugu',
    'Malayalam',
    'Marathi',
    'Bengali',
    'Gujarati',
    'Punjabi',
    'Urdu',
  ];

  final Set<String> myInterests = {};
  static List<String> promptOptions = [
    'My ideal Sunday is',
    'I’m happiest when',
    'Ask me about',
  ];

  static List<String> interestOptions = [
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

  /// The live-selfie check: '' (never sent), 'pending', 'rejected'.
  /// Approval shows up as [myVerified], which only an admin can set.
  String verificationStatus = '';

  /// Why the last selfie was turned down, from the reviewer.
  String verificationNote = '';

  /// Sends the selfie burst for review. Without an account (the preview)
  /// nothing leaves the phone, so the badge is simply switched on.
  Future<void> submitVerification(List<Uint8List> frames) async {
    final b = backend;
    if (b == null || !b.signedIn) {
      myVerified = true;
      notifyListeners();
      return;
    }
    await b.submitVerification(frames);
    verificationStatus = 'pending';
    verificationNote = '';
    notifyListeners();
  }

  Future<void> _loadVerification(ProfileBackend b) async {
    try {
      final latest = await b.latestVerification();
      verificationStatus = switch (latest?.status) {
        'pending' || 'rejected' => latest!.status,
        _ => '',
      };
      verificationNote = latest?.note ?? '';
      notifyListeners();
    } catch (_) {
      // Before migration 009 the table doesn't exist; leave it unknown.
    }
  }

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

  /// Every plan has a daily limit, so actions stay fair-use. Sparks come
  /// from their own weekly allowance, not the daily likes; messages are free.
  int get remaining =>
      plan.dailyLikes - (liked.length - sparked.length - messaged.length);
  bool get outOfLikes => remaining <= 0;
  List<Person> get discover => discoverWith(filters);

  /// Who Discover would show with [f] (the filters sheet's live count uses
  /// it before anything is saved).
  List<Person> discoverWith(DiscoverFilters f) => paused
      ? []
      : f.apply(_pool.where((p) =>
          !passed.contains(p.id) &&
          !liked.contains(p.id) &&
          !conversations.any((chat) => chat.person.id == p.id)));

  /// People close by (within 5 km, shown as "Nearby"), closest first.
  /// Exact distances are never shown.
  List<Person> get nearby => _pool
      .where((p) =>
          p.distance <= 5 &&
          !passed.contains(p.id) &&
          !conversations.any((chat) => chat.person.id == p.id))
      .toList()
    ..sort((a, b) => a.distance.compareTo(b.distance));

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

  /// Messages sent from the Discover card. They reach the other person in
  /// their Likes, like a like does, but don't use up a daily like.
  final Set<String> messaged = {};

  void message(Person p, String text) {
    if (liked.contains(p.id) || text.trim().isEmpty) return;
    liked.add(p.id);
    messaged.add(p.id);
    sentLikes.add(SentLike(p.id, 'message', text.trim()));
    notifyListeners();
    if (!p.remote) return;
    _remote((b) async {
      // If they'd already liked you, this makes a match.
      final matchId =
          await b.like(p.id, target: 'message', comment: text.trim());
      if (matchId != null) _addMatch(p, matchId, celebrate: true);
    });
  }

  /// Sparks: a weekly allowance of likes that stand out.
  final Set<String> sparked = {};
  int get sparksLeft => plan.weeklySparks - sparked.length;

  void spark(Person p, {String comment = ''}) {
    if (sparksLeft <= 0 || liked.contains(p.id)) return;
    liked.add(p.id);
    sparked.add(p.id);
    sentLikes.add(SentLike(p.id, 'profile', comment.trim(), spark: true));
    notifyListeners();
    if (!p.remote) return;
    _remote((b) async {
      // Saved as a like for now; the server has no Spark flag yet.
      final matchId =
          await b.like(p.id, target: 'profile', comment: comment.trim());
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
    }, failure: 'Couldn’t send that message. Check your connection.',
        banned: 'That message contains words that aren’t allowed, so it wasn’t sent.');
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
      {String failure = 'Couldn’t reach the server. Check your connection.',
      String? banned}) {
    final b = backend;
    if (b == null || !b.signedIn) return;
    action(b).catchError((Object e) =>
        _failed(banned != null && isBannedWordError(e) ? banned : failure));
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
    _loadMessages(chat, matchId);
    return chat;
  }

  /// Ids of chat messages already shown, so a live update that races the
  /// first load isn't added twice.
  final Set<String> _seenMessages = {};

  /// A new match can already have messages (a sample profile says hello,
  /// or answers the note sent from Discover), written before the app was
  /// listening for them.
  void _loadMessages(Conversation chat, String matchId) {
    final b = backend;
    if (b == null || !b.signedIn) return;
    final me = b.user!.id;
    b.messages(matchId).then((rows) {
      var added = false;
      for (final m in rows) {
        if (!_seenMessages.add(m['id'] as String)) continue;
        chat.messages.add(ChatMessage.fromRow(m, mine: m['sender'] == me));
        added = true;
      }
      if (added) notifyListeners();
    }, onError: (Object _) {});
  }

  /// Tells the server roughly where the member is (about 1 km), so Discover
  /// and Hangouts use real distances rather than the home city. Quiet when
  /// location is off; Discover then falls back to the city.
  Future<void> _shareLiveLocation(ProfileBackend b) async {
    final at = await currentPosition();
    if (at == null || !b.signedIn) return;
    try {
      await b.recordLocation(at.$1, at.$2);
      await refreshMembers();
    } catch (_) {
      // The city centre is used instead.
    }
  }

  Future<void> _loadCommunitySafely() async {
    try {
      await loadCommunity();
    } catch (_) {
      _failed('Couldn’t load people right now. Check your connection.');
    }
  }

  Future<void> _loadSampleIds(ProfileBackend b) async {
    try {
      sampleProfileIds
        ..clear()
        ..addAll(await b.sampleProfileIds());
    } catch (_) {
      // Unlabelled is worse than missing: keep the last known ids.
    }
  }

  /// Re-fetches people to discover (e.g. after onboarding or on return to
  /// the Discover tab).
  Future<void> refreshMembers() async {
    final b = backend;
    if (b == null || !b.signedIn) return;
    try {
      await _loadSampleIds(b);
      final rows = await b.discover(maxKm: _maxKm);
      members
        ..clear()
        ..addAll(rows
            .map((r) => Person.fromCard(r, b.photoUrl, voiceUrl: b.voiceUrl))
            .where((p) => !passed.contains(p.id) && !liked.contains(p.id)));
      notifyListeners();
      _loadQuizAnswers(b).ignore();
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
    await _loadSampleIds(b);
    final results = await Future.wait(
        [b.discover(maxKm: _maxKm), b.likesReceived(), b.myMatches()]);
    Person card(Map<String, dynamic> r) => Person.fromCard(r, b.photoUrl, voiceUrl: b.voiceUrl);
    _clearCommunity();
    members.addAll(results[0].map(card));
    for (final r in results[1]) {
      final p = card(r);
      incoming.add(p);
      likeNotes[p.id] = SentLike(
          p.id, r['target'] as String? ?? 'photo', r['comment'] as String? ?? '');
    }
    // Fetch every conversation's messages at once rather than one by one.
    final threads = await Future.wait(
        [for (final r in results[2]) b.messages(r['match_id'] as String)]);
    for (final (i, r) in results[2].indexed) {
      final matchId = r['match_id'] as String;
      final msgs = threads[i];
      conversations.add(Conversation(
          card(r),
          [
            for (final m in msgs)
              if (_seenMessages.add(m['id'] as String))
                ChatMessage.fromRow(m, mine: m['sender'] == me)
          ],
          matchId: matchId));
    }
    _listen(b, me);
    notifyListeners();
    _loadQuizAnswers(b).ignore();
    _loadUnread(b).ignore();
  }

  /// Total unread messages, for the Messages tab.
  int get unreadMessages =>
      conversations.fold(0, (sum, c) => sum + c.unread);

  /// The chat on screen right now: new messages there are read at once.
  Conversation? openChat;

  Future<void> _loadUnread(ProfileBackend b) async {
    try {
      final counts = await b.unread();
      for (final c in conversations) {
        c.unread = c == openChat ? 0 : counts[c.matchId] ?? 0;
      }
      notifyListeners();
    } catch (_) {
      // Counts just stay as they are.
    }
  }

  /// Opening a chat clears its count, here and on the server.
  void markRead(Conversation c) {
    openChat = c;
    if (c.unread == 0 && c.matchId == null) return;
    c.unread = 0;
    notifyListeners();
    final b = backend;
    final id = c.matchId;
    if (b != null && b.signedIn && id != null) b.markRead(id).ignore();
  }

  void closeChat(Conversation c) {
    if (openChat == c) openChat = null;
  }

  void _listen(ProfileBackend b, String me) {
    if (_channel != null) return;
    _matchPollTimer?.cancel();
    var pollCount = 0;
    b.touchPresence().ignore();
    _matchPollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      // Tell the server you're around, every two minutes or so.
      if (pollCount % 24 == 0) backend?.touchPresence().ignore();
      if (!signedIn || backend == null) return;
      try {
        await backend!.checkBotReplies();
        pollCount++;
        if (pollCount % 12 == 0) {
          await backend!.myMatches();
          // Waiting on a host? Check now and then whether they said yes.
          if (hangouts.any((h) => h.status == 'pending')) await loadHangouts();
          // Likewise for a UPI payment waiting to be verified.
          if (upiPayments.any((p) => p.pending)) await loadUpiPayments();
        }
      } catch (_) {}
    });
    _channel = b.listen(onMessage: (m) {
      if (m['sender'] == me) return; // already shown when sent
      if (m['id'] is String && !_seenMessages.add(m['id'] as String)) return;
      for (final c in conversations) {
        if (c.matchId == m['match_id']) {
          c.messages.add(ChatMessage.fromRow(m));
          if (c == openChat) {
            b.markRead(c.matchId!).ignore();
          } else {
            c.unread++;
          }
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
      final p = Person.fromCard(row, b.photoUrl, voiceUrl: b.voiceUrl);
      // A host accepting a hangout request connects you: say that, rather
      // than celebrating a match. (The host, who accepted, needs no news.)
      if (m['origin'] == 'hangout') {
        _addMatch(p, matchId, celebrate: false);
        final accepted = await loadHangouts();
        if (accepted.isEmpty &&
            hangouts.any((h) => h.host?.id == p.id && h.status == 'accepted')) {
          hangoutAccepted.value =
              'Your hangout request is accepted 🎉 You can now chat with ${p.name}.';
        }
        return;
      }
      // You liked them back from Likes: that screen already celebrated.
      final mine = conversations.any((c) => c.person.id == p.id);
      _addMatch(p, matchId, celebrate: !mine);
    }, onLike: (_) async {
      final rows = await b.likesReceived();
      for (final r in rows) {
        final p = Person.fromCard(r, b.photoUrl, voiceUrl: b.voiceUrl);
        if (incoming.any((x) => x.id == p.id)) continue;
        incoming.insert(0, p);
        likeNotes[p.id] = SentLike(p.id, r['target'] as String? ?? 'photo',
            r['comment'] as String? ?? '');
      }
      notifyListeners();
    });
  }

  void _clearCommunity() {
    _seenMessages.clear();
    remoteQuizAnswers.clear();
    members.clear();
    incoming.clear();
    conversations.clear();
    likeNotes.clear();
    passed.clear();
    passHistory.clear();
    liked.clear();
    sparked.clear();
    messaged.clear();
    sentLikes.clear();
    crossings.clear();
  }

  /// Back to the demo cast after logging out.
  void _restoreDemo() {
    final channel = _channel;
    _channel = null;
    _matchPollTimer?.cancel();
    _matchPollTimer = null;
    if (channel != null) backend?.stopListening(channel).ignore();
    _clearCommunity();
    incoming.addAll(_demoIncoming);
    conversations.addAll(_demoConversations());
    crossings.addAll(_demoCrossings());
  }

  /// Hangouts are open to everyone: one of Everlane's main features.
  bool get canHangout => true;
  final List<Hangout> hangouts = demoHangouts();

  /// People asking to join your plans (real members only).
  final List<HangoutRequest> hangoutRequests = [];
  bool hangoutsLoading = false;

  /// Set by "Ready to Hangout?"; null until the member picks a vibe.
  String? hangoutMood;
  String hangoutDetail = '';
  bool hangoutHasPlace = false;

  void joinHangouts(String mood, String detail, bool hasPlace) {
    hangoutMood = mood;
    hangoutDetail = detail.trim();
    hangoutHasPlace = hasPlace;
    notifyListeners();
  }

  /// Plans within your Discover distance, and requests to your own plans.
  /// Reloads plans near you; returns the plans whose request (yours) was
  /// accepted since the last load, and announces them.
  Future<List<Hangout>> loadHangouts() async {
    final b = backend;
    if (b == null || !b.signedIn) return const [];
    hangoutsLoading = true;
    notifyListeners();
    final before = {for (final h in hangouts) h.id: h.status};
    final accepted = <Hangout>[];
    try {
      final results = await Future.wait(
          [b.hangoutsNear(maxKm: distance.round()), b.hangoutRequestsMine()]);
      hangouts
        ..clear()
        ..addAll(results[0].map((r) => Hangout.fromRow(r, b.photoUrl)));
      for (final h in hangouts) {
        if (h.status == 'accepted' && before[h.id] == 'pending') accepted.add(h);
      }
      if (accepted.isNotEmpty) {
        final h = accepted.first;
        hangoutAccepted.value =
            'Your hangout request is accepted 🎉 “${h.title}”${h.venue.isEmpty ? '' : ' at ${h.venue}'}';
      }
      hangoutRequests
        ..clear()
        ..addAll(results[1].map((r) => HangoutRequest(
            r['hangout'] as String,
            Person.fromCard({...r, 'id': r['member']}, b.photoUrl),
            r['status'] as String,
            voiceUrl: (r['voice_path'] as String? ?? '').isEmpty
                ? ''
                : b.voiceUrl(r['voice_path'] as String),
            voiceSeconds: (r['voice_seconds'] as num?)?.toInt() ?? 0,
            acceptedAt: DateTime.tryParse(r['accepted_at'] as String? ?? '')
                ?.toLocal())));
    } catch (_) {
      _failed('Couldn’t load Hangouts. Check your connection.');
    } finally {
      hangoutsLoading = false;
      notifyListeners();
    }
    return accepted;
  }

  /// Asks to join [h]. Plans with an icebreaker need a [voice] answer (a WAV
  /// of up to 20 seconds); it's uploaded first, then sent with the request.
  Future<void> requestToJoin(Hangout h,
      {Uint8List? voice, int voiceSeconds = 0}) async {
    final b = backend;
    h.status = 'pending';
    notifyListeners();
    if (b == null || !b.signedIn || h.host?.remote != true) return;
    String? path;
    try {
      if (voice != null) path = await b.uploadVoice(voice);
      h.status = await b.requestHangout(h.id,
          voicePath: path ?? '', voiceSeconds: voiceSeconds);
      notifyListeners();
    } catch (_) {
      h.status = null;
      if (path != null) b.deleteVoice(path).ignore();
      _failed('Couldn’t send your request. Try again.');
    }
  }

  Future<void> hostHangout(Hangout h) async {
    final b = backend;
    if (b == null || !b.signedIn) {
      hangouts.insert(0, h);
      notifyListeners();
      return;
    }
    await b.hostHangout(h);
    await loadHangouts();
  }

  Future<void> cancelHangout(Hangout h) async {
    hangouts.remove(h);
    notifyListeners();
    final b = backend;
    if (b != null && b.signedIn) await b.cancelHangout(h.id);
  }

  Future<void> answerHangoutRequest(HangoutRequest r, {required bool accept}) async {
    final b = backend;
    if (b == null || !b.signedIn) return;
    r.status = accept ? 'accepted' : 'declined';
    if (accept) r.acceptedAt = DateTime.now();
    if (!accept) hangoutRequests.remove(r);
    notifyListeners();
    try {
      await b.answerHangoutRequest(r.hangoutId, r.person.id, accept: accept);
      await loadHangouts();
    } catch (_) {
      _failed('Couldn’t update the request. Try again.');
    }
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
    // A paid plan stays until it ends; the server would bring it back anyway.
    if (planPaid && !next.atLeast(plan)) return;
    plan = next;
    if (!next.atLeast(Plan.plus)) {
      filters = filters.copyWith(intents: const {}, verifiedOnly: false);
    }
    notifyListeners();
    final b = backend;
    if (b != null && b.signedIn) {
      b.choosePreviewPlan(next.name).catchError((Object _) => _failed(
          'Your plan couldn’t be saved, so it will reset when you reload.'));
    }
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
        'height_cm': myHeightCm,
        'languages': myLanguages.toList(),
        'drinking': myDrinking,
        'smoking': mySmoking,
        'education': myEducation,
        'family_plans': myFamilyPlans,
        'interests': myInterests.toList(),
        'prompt_label': myPromptLabel,
        'prompt_answer': myPrompt,
        if (_voiceColumns || _voicePath.isNotEmpty) ...{
          'voice_prompt_label': _voicePath.isEmpty ? '' : myVoiceLabel,
          'voice_path': _voicePath,
          'voice_seconds': _voicePath.isEmpty ? 0 : myVoiceSeconds,
        },
        'photos': [
          for (final b in myPhotos)
            if (_photoPaths[b] != null) _photoPaths[b]
        ],
        'onboarding_answers': onboardingAnswers,
        'quiz_answers': quizAnswers,
        'onboarded': onboarded,
        'posted': myProfilePosted,
        'verified': myVerified,
      };

  /// Saves the member's profile in the background. A no-op when not signed
  /// in (tests, or the account-less preview).
  Future<void> saveProfile() {
    final b = backend;
    // A restricted account is never written to from the app.
    if (b == null || !b.signedIn || restriction != null) return Future.value();
    return b.saveProfile(profileRow).then((_) {
      if (syncError != null) {
        syncError = null;
        notifyListeners();
      }
    }, onError: (Object e) => _failed(isBannedWordError(e)
        ? 'Your profile has words that aren’t allowed. Edit them and save again.'
        : 'Couldn’t save your profile. Check your connection.'));
  }

  /// A new account starts blank instead of with the demo member's details.
  void startFreshAccount() {
    myName = '';
    myJob = '';
    myCity = '';
    myBio = '';
    myPrompt = '';
    myPromptLabel = 'My ideal Sunday is';
    myLookingFor = 'Long term';
    myHeightCm = null;
    myLanguages.clear();
    myDrinking = '';
    mySmoking = '';
    myEducation = '';
    myFamilyPlans = '';
    myInterests.clear();
    myBirthday = null;
    myGender = '';
    interestedIn = '';
    onboardingAnswers.clear();
    myPhotos.clear();
    _photoPaths.clear();
    myVoiceLabel = '';
    myVoice = null;
    myVoiceSeconds = 0;
    _voicePath = '';
    myProfilePosted = false;
    myVerified = false;
    verificationStatus = '';
    verificationNote = '';
    onboarded = false;
    notifyListeners();
  }

  /// Pulls the admin-managed quiz and option lists. Keeps the built-in ones
  /// if Supabase is unreachable or a list comes back empty.
  Future<void> loadContent() async {
    final b = backend;
    if (b == null) return;
    try {
      final rows = await b.quizQuestions();
      final questions = [
        for (final r in rows)
          if ((r['options'] as List? ?? const []).isNotEmpty)
            questionFromRow(r)
      ];
      if (questions.isNotEmpty) quizQuestions = questions;
      final options = await b.appOptions();
      List<String> of(String kind) => [
            for (final o in options)
              if (o['kind'] == kind) o['value'] as String
          ];
      if (of('interest').isNotEmpty) interestOptions = of('interest');
      if (of('language').isNotEmpty) languageOptions = of('language');
      if (of('prompt').isNotEmpty) promptOptions = of('prompt');
      for (final r in await b.plans()) {
        for (final p in Plan.values) {
          if (p.name == r['plan']) {
            planConfigs[p] = PlanConfig(
                title: r['title'] as String? ?? p._title,
                tagline: r['tagline'] as String? ?? p._tagline,
                dailyLikes: (r['daily_likes'] as num?)?.toInt() ?? p._dailyLikes,
                weeklySparks: (r['weekly_sparks'] as num?)?.toInt() ?? p._weeklySparks,
                monthlyBoosts: (r['monthly_boosts'] as num?)?.toInt() ?? p._monthlyBoosts,
                perks: List<String>.from(r['perks'] as List? ?? p._perks),
                highlight: r['highlight'] as String? ?? '');
          }
        }
      }
      for (final r in await b.planPrices()) {
        for (final p in Plan.values) {
          if (p.name == r['plan']) {
            final n = (r['price'] as num);
            planPrices[p] =
                '${r['symbol']}${n == n.roundToDouble() ? n.toInt() : n.toStringAsFixed(2)}';
          }
        }
      }
      notifyListeners();
    } catch (_) {
      // Built-in content is a fine fallback.
    }
  }

  /// Loads the signed-in member's profile and photos. Returns whether they
  /// have finished onboarding before (so they can skip straight in).
  Future<bool> loadProfile() async {
    final b = backend;
    if (b == null || !b.signedIn) return false;
    final banned = _banned(b);
    final row = await b.loadProfile();
    // Blocked and suspended members stay signed in, but only to appeal or
    // log out (see AccountRestrictedScreen); nothing else loads.
    if (row?['blocked'] == true) {
      startFreshAccount();
      restriction = const AccountRestriction(
          title: 'Account blocked',
          message:
              'This account has been blocked for breaking our community guidelines. If you think this is a mistake, you can appeal.');
      notifyListeners();
      return false;
    }
    final suspendedUntil =
        DateTime.tryParse(row?['suspended_until'] as String? ?? '')?.toLocal();
    if (suspendedUntil != null && suspendedUntil.isAfter(DateTime.now())) {
      startFreshAccount();
      final d = suspendedUntil;
      restriction = AccountRestriction(
          title: 'Account suspended',
          message:
              'This account is suspended until ${d.day}/${d.month}/${d.year}. If you think this is a mistake, you can appeal.');
      notifyListeners();
      return false;
    }
    if (await banned) {
      await b.logOut();
      startFreshAccount();
      restriction = const AccountRestriction(
          title: 'Account unavailable',
          message:
              'This account can’t use Everlane. Contact support if you think this is a mistake.',
          canAppeal: false);
      notifyListeners();
      return false;
    }
    loadAnnouncements().ignore();
    loadTickets().ignore();
    startFreshAccount();
    if (row == null) {
      await _loadCommunitySafely();
      return false;
    }
    // People, likes and chats load alongside the member's own photos.
    final community = _loadCommunitySafely();
    _shareLiveLocation(b).ignore();
    myName = row['name'] as String? ?? '';
    myBirthday = DateTime.tryParse(row['birthday'] as String? ?? '');
    myGender = row['gender'] as String? ?? '';
    interestedIn = row['interested_in'] as String? ?? '';
    myCity = row['city'] as String? ?? '';
    myJob = row['job'] as String? ?? '';
    myBio = row['bio'] as String? ?? '';
    myLookingFor = row['looking_for'] as String? ?? 'Long term';
    myHeightCm = (row['height_cm'] as num?)?.toInt();
    myLanguages.addAll(List<String>.from(row['languages'] as List? ?? []));
    myDrinking = row['drinking'] as String? ?? '';
    mySmoking = row['smoking'] as String? ?? '';
    myEducation = row['education'] as String? ?? '';
    myFamilyPlans = row['family_plans'] as String? ?? '';
    myInterests.addAll(List<String>.from(row['interests'] as List? ?? []));
    myPromptLabel = row['prompt_label'] as String? ?? 'My ideal Sunday is';
    myPrompt = row['prompt_answer'] as String? ?? '';
    _voiceColumns = row.containsKey('voice_path');
    _voicePath = row['voice_path'] as String? ?? '';
    myVoiceLabel = row['voice_prompt_label'] as String? ?? '';
    myVoiceSeconds = (row['voice_seconds'] as num?)?.toInt() ?? 0;
    myProfilePosted = row['posted'] as bool? ?? false;
    adminWarning = row['warning'] as String? ?? '';
    _applyPlan(row);
    myVerified = row['verified'] as bool? ?? false;
    showOnline = row['show_online_status'] as bool? ?? true;
    if (!myVerified) _loadVerification(b).ignore();
    (row['onboarding_answers'] as Map? ?? {}).forEach((k, v) =>
        onboardingAnswers[k as String] = List<String>.from(v as List));
    (row['quiz_answers'] as Map? ?? {}).forEach((k, v) =>
        quizAnswers[k as String] = List<String>.from(v as List));
    final paths = List<String>.from(row['photos'] as List? ?? []);
    final photos = await Future.wait([
      for (final path in paths)
        // A missing photo shouldn't stop the rest of the profile loading.
        b.downloadPhoto(path).then<Uint8List?>((v) => v, onError: (_) => null)
    ]);
    for (final (i, bytes) in photos.indexed) {
      if (bytes == null) continue;
      myPhotos.add(bytes);
      _photoPaths[bytes] = paths[i];
    }
    await community;
    onboarded = row['onboarded'] as bool? ?? false;
    notifyListeners();
    return onboarded;
  }

  /// Sets [plan] from a profiles row.
  void _applyPlan(Map<String, dynamic> row) {
    // A plan set by an admin (support, or a verified UPI payment) wins,
    // until it ends.
    final adminPlan = row['plan'] as String? ?? '';
    final until = DateTime.tryParse(row['plan_until'] as String? ?? '');
    var adminSet = false;
    if (until == null || until.isAfter(DateTime.now())) {
      for (final p in Plan.values) {
        if (p.name == adminPlan) {
          plan = p;
          adminSet = true;
        }
      }
    }
    planPaid = adminSet;
    planUntil = adminSet ? until : null;
    // Otherwise the plan picked in the app, while payments aren't live.
    if (!adminSet) {
      final picked = row['preview_plan'] as String? ?? '';
      for (final p in Plan.values) {
        if (p.name == picked) plan = p;
      }
    }
  }

  /// Re-reads just the plan from the profile (after a payment is verified).
  Future<void> refreshPlan() async {
    final b = backend;
    if (b == null || !b.signedIn) return;
    try {
      final row = await b.loadProfile();
      if (row == null) return;
      _applyPlan(row);
      notifyListeners();
    } catch (_) {
      // Picked up on the next load.
    }
  }

  // ---- Paying by UPI ----

  /// Paid plans go through the UPI sheet instead of switching locally.
  bool get upiCheckout => signedIn && settings.upi.ready;

  /// Newest first, as `my_upi_payments()` returns them.
  final List<UpiPayment> upiPayments = [];
  bool _upiLoaded = false;

  /// "Your Gold plan is active", once, when a payment is verified; the app
  /// shows it and clears it.
  final ValueNotifier<String?> planActivated = ValueNotifier(null);

  Future<void> loadUpiPayments() async {
    final b = backend;
    if (b == null || !b.signedIn) return;
    try {
      final list = [for (final r in await b.myUpiPayments()) UpiPayment.fromRow(r)];
      final waiting = {
        for (final p in upiPayments)
          if (!p.approved) p.id
      };
      final verified = _upiLoaded
          ? list.where((p) => p.approved && waiting.contains(p.id)).toList()
          : const <UpiPayment>[];
      upiPayments
        ..clear()
        ..addAll(list);
      _upiLoaded = true;
      notifyListeners();
      if (verified.isNotEmpty) {
        await refreshPlan();
        planActivated.value = 'Your ${verified.first.planTitle} plan is active';
      }
    } catch (_) {
      // Keep what we had.
    }
  }

  /// Sends the UTR for [p] to be verified. Throws with the server's reason
  /// if it's refused; the plan only changes once an admin approves it.
  Future<void> submitUpiPayment(Plan p, String utr, {String note = ''}) async {
    final b = backend;
    if (b == null || !b.signedIn) {
      throw StateError('Sign in to pay for a plan.');
    }
    if (!_upiLoaded) await loadUpiPayments();
    await b.submitUpiPayment(plan: p.name, utr: utr.trim(), note: note.trim());
    await loadUpiPayments();
  }

  Future<void> logOut() async {
    _restoreDemo();
    _clearAccountExtras();
    await backend?.logOut();
    startFreshAccount();
  }

  // ---- Set by admins in the panel (see admin.dart) ----

  /// Safe defaults until `app_settings()` loads, and for good without a
  /// backend: everything on, nothing blocked.
  AppSettings settings = const AppSettings();

  bool get maintenance => settings.maintenance;
  bool get updateRequired => settings.needsUpdate(appVersion,
      web: kIsWeb, platform: defaultTargetPlatform);

  /// Loaded at start-up and whenever the app comes back to the front.
  Future<void> loadSettings() async {
    final b = backend;
    if (b == null) return;
    try {
      settings = AppSettings.fromJson(await b.appSettings());
      notifyListeners();
    } catch (_) {
      // Keep the last known settings.
    }
  }

  /// Set when the signed-in account is blocked, suspended or banned; the
  /// app then shows only AccountRestrictedScreen.
  AccountRestriction? restriction;

  void clearRestriction() {
    restriction = null;
    notifyListeners();
  }

  Future<bool> _banned(ProfileBackend b) async {
    try {
      return await b.isBanned();
    } catch (_) {
      return false; // the database still enforces it
    }
  }

  void _clearAccountExtras() {
    restriction = null;
    announcements.clear();
    tickets.clear();
    dataRequests.clear();
    upiPayments.clear();
    _upiLoaded = false;
    referral = null;
  }

  // ---- Announcements ----

  /// Newest first.
  final List<Announcement> announcements = [];

  /// Remembered on this device, so a dismissed one stays gone.
  final Set<String> dismissedAnnouncements = {};
  bool _dismissedLoaded = false;
  static const _dismissedKey = 'everlane.dismissed_announcements';

  Announcement? get banner => announcements
      .where((a) => a.isBanner && !dismissedAnnouncements.contains(a.id))
      .firstOrNull;
  Announcement? get pendingNotice => announcements
      .where((a) => a.isNotice && !dismissedAnnouncements.contains(a.id))
      .firstOrNull;

  void dismissAnnouncement(String id) {
    if (!dismissedAnnouncements.add(id)) return;
    notifyListeners();
    if (backend == null) return;
    SharedPreferences.getInstance()
        .then((p) =>
            p.setStringList(_dismissedKey, dismissedAnnouncements.toList()))
        .catchError((Object _) => false);
  }

  Future<void> loadAnnouncements() async {
    final b = backend;
    if (b == null) return;
    try {
      if (!_dismissedLoaded) {
        _dismissedLoaded = true;
        try {
          final p = await SharedPreferences.getInstance();
          dismissedAnnouncements.addAll(p.getStringList(_dismissedKey) ?? []);
        } catch (_) {
          // Not remembered across launches, then.
        }
      }
      final rows = await b.myAnnouncements();
      final list = [for (final r in rows) Announcement.fromRow(r)]
        ..sort((x, y) => (y.createdAt ?? DateTime(0))
            .compareTo(x.createdAt ?? DateTime(0)));
      announcements
        ..clear()
        ..addAll(list);
      notifyListeners();
    } catch (_) {
      // No announcements, then.
    }
  }

  // ---- Help & support ----

  /// Help center articles; null until loaded.
  List<FaqItem>? faq;
  bool faqFailed = false;

  Future<void> loadFaq() async {
    final b = backend;
    if (b == null) {
      // Called from initState, so no notify: the screen reads it next.
      faq ??= const [];
      return;
    }
    try {
      faq = [for (final r in await b.faq()) FaqItem.fromRow(r)];
      faqFailed = false;
    } catch (_) {
      faqFailed = faq == null;
      faq ??= const [];
    }
    notifyListeners();
  }

  /// Contact support, appeals and data requests need an account.
  bool get canContactSupport => signedIn;

  final List<SupportTicket> tickets = [];
  int get unreadTickets => tickets.where((t) => t.unread > 0).length;

  Future<void> loadTickets() async {
    final b = backend;
    if (b == null || !b.signedIn) return;
    try {
      final rows = await b.myTickets();
      tickets
        ..clear()
        ..addAll(rows.map(SupportTicket.fromRow));
      notifyListeners();
    } catch (_) {
      // Keep what we had.
    }
  }

  /// Returns the new ticket's id. Throws if it couldn't be sent.
  Future<String> createTicket(
      {required String subject,
      required String category,
      required String body}) async {
    final b = backend;
    if (b == null || !b.signedIn) {
      throw StateError('Sign in to contact support.');
    }
    final id =
        await b.createTicket(subject: subject, category: category, body: body);
    loadTickets().ignore();
    return id;
  }

  Future<List<TicketMessage>> ticketThread(String ticket) async {
    final b = backend;
    if (b == null || !b.signedIn) return const [];
    final rows = await b.ticketThread(ticket);
    // Opening a thread reads it.
    loadTickets().ignore();
    return [for (final r in rows) TicketMessage.fromRow(r)];
  }

  Future<void> replyTicket(String ticket, String body) async {
    final b = backend;
    if (b == null || !b.signedIn) return;
    await b.replyTicket(ticket, body);
  }

  // ---- Your data ----

  final List<DataRequest> dataRequests = [];

  Future<void> loadDataRequests() async {
    final b = backend;
    if (b == null || !b.signedIn) return;
    try {
      final rows = await b.myDataRequests();
      dataRequests
        ..clear()
        ..addAll(rows.map(DataRequest.fromRow));
      notifyListeners();
    } catch (_) {
      // Keep what we had.
    }
  }

  /// [kind] is 'export' or 'deletion'. Throws if it couldn't be sent.
  Future<void> requestMyData(String kind) async {
    final b = backend;
    if (b == null || !b.signedIn) {
      throw StateError('Sign in to request your data.');
    }
    await b.requestMyData(kind);
    await loadDataRequests();
  }

  // ---- Referrals and consent ----

  bool get referralsOn => settings.referralsOn;
  Referral? referral;

  /// A friend's invite code entered at sign-up, applied once the new
  /// member's profile is saved (end of onboarding). Also kept on the
  /// account, so it survives confirming the email on another device.
  String pendingReferralCode = '';
  String get signUpReferralCode {
    if (pendingReferralCode.isNotEmpty) return pendingReferralCode;
    final meta = backend?.user?.userMetadata?['referral_code'];
    return meta is String ? meta.trim() : '';
  }

  Future<void> loadReferral() async {
    final b = backend;
    if (b == null || !b.signedIn || !referralsOn) return;
    try {
      referral = Referral.fromJson(await b.myReferral());
      notifyListeners();
    } catch (_) {
      // The invite card just doesn't show.
    }
  }

  /// Returns the name of the friend who invited you. Throws with the
  /// server's message (e.g. an unknown code).
  Future<String> applyReferral(String code) async {
    final b = backend;
    if (b == null || !b.signedIn) {
      throw StateError('Sign in to use an invite code.');
    }
    return b.applyReferral(code.trim());
  }

  /// "Send me tips and offers", from the last onboarding step.
  bool marketingConsent = false;

  void _recordConsent() {
    final b = backend;
    if (b == null || !b.signedIn) return;
    final marketing = marketingConsent;
    termsVersion()
        .then((v) => b.recordConsent(termsVersion: v, marketing: marketing))
        .catchError((Object _) {});
  }
}

/// 175 → "5′9″ · 175 cm".
String heightLabel(int cm) {
  final inches = (cm / 2.54).round();
  return '${inches ~/ 12}′${inches % 12}″ · $cm cm';
}

/// Admin-made bot profiles (see `sample_profile_ids()` in Supabase).
final Set<String> sampleProfileIds = {};

/// A tier's name, limits and perks as set in the admin panel (plans table).
class PlanConfig {
  const PlanConfig(
      {required this.title,
      required this.tagline,
      required this.dailyLikes,
      required this.weeklySparks,
      required this.monthlyBoosts,
      required this.perks,
      required this.highlight});
  final String title, tagline, highlight;
  final int dailyLikes, weeklySparks, monthlyBoosts;
  final List<String> perks;
}

final Map<Plan, PlanConfig> planConfigs = {};

/// Monthly prices from Supabase's plan_prices (set in the admin panel),
/// e.g. {Plan.gold: '₹499'}. Empty until loaded; plans fall back to their
/// built-in price.
final Map<Plan, String> planPrices = {};
