import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everlane/models.dart';

Person member(String id,
        {int age = 30,
        int distance = 5,
        DateTime? lastSeenAt,
        DateTime? joinedAt,
        int? heightCm,
        String drinking = '',
        String smoking = '',
        String bio = '',
        String answer = '',
        List<String> languages = const [],
        List<String> photos = const []}) =>
    Person(
        id: id,
        name: id,
        age: age,
        job: '',
        photo: '',
        distance: distance,
        answer: answer,
        bio: bio,
        lookingFor: const [LookingFor.longTerm],
        remote: true,
        lastSeenAt: lastSeenAt,
        joinedAt: joinedAt,
        heightCm: heightCm,
        drinking: drinking,
        smoking: smoking,
        languages: languages,
        photoUrls: photos);

List<String> ids(List<Person> people) => [for (final p in people) p.id];

void main() {
  final now = DateTime.now();

  test('Presence toggles: online, active in 24 hours, new members', () {
    final online = member('online',
        lastSeenAt: now.subtract(const Duration(minutes: 1)),
        joinedAt: now.subtract(const Duration(days: 300)));
    final recent = member('recent',
        lastSeenAt: now.subtract(const Duration(hours: 3)),
        joinedAt: now.subtract(const Duration(days: 300)));
    final fresh = member('new',
        lastSeenAt: now.subtract(const Duration(days: 2)),
        joinedAt: now.subtract(const Duration(days: 2)));
    final away = member('away',
        lastSeenAt: now.subtract(const Duration(days: 9)),
        joinedAt: now.subtract(const Duration(days: 300)));
    final pool = [online, recent, fresh, away];
    const f = DiscoverFilters();
    expect(ids(f.apply(pool)), ['online', 'recent', 'new', 'away']);
    expect(ids(f.copyWith(onlineNow: true).apply(pool)), ['online']);
    expect(ids(f.copyWith(activeToday: true).apply(pool)), ['online', 'recent']);
    expect(ids(f.copyWith(newMembers: true).apply(pool)), ['new']);
    // Demo people: online is their activeNow flag.
    expect(ids(f.copyWith(onlineNow: true).apply(demoPeople)),
        ['ananya', 'isha']);
  });

  test('Height range keeps people without a height only at "Any height"', () {
    final pool = [
      member('short', heightCm: 150),
      member('tall', heightCm: 190),
      member('unknown'),
    ];
    const f = DiscoverFilters();
    expect(f.anyHeightChosen, isTrue);
    expect(f.apply(pool).length, 3);
    final ranged = f.copyWith(heights: const RangeValues(160, 210));
    expect(ids(ranged.apply(pool)), ['tall']);
    expect(ranged.moreCount, 1);
  });

  test('Lifestyle and language chips exclude empty values only when chosen',
      () {
    final pool = [
      member('never', drinking: 'never', languages: ['Hindi']),
      member('social', drinking: 'socially', languages: ['Tamil', 'English']),
      member('unsaid'),
    ];
    const f = DiscoverFilters();
    expect(f.apply(pool).length, 3);
    expect(ids(f.copyWith(drinking: {'socially', 'regularly'}).apply(pool)),
        ['social']);
    expect(ids(f.copyWith(smoking: {'non_smoker'}).apply(pool)), isEmpty);
    expect(ids(f.copyWith(languages: {'English', 'Hindi'}).apply(pool)),
        ['never', 'social']);
  });

  test('Profile quality toggles', () {
    final pool = [
      member('bio', bio: 'Hi'),
      member('prompt', answer: 'Sundays'),
      member('photos', photos: ['a', 'b', 'c']),
      member('bare'),
    ];
    const f = DiscoverFilters();
    expect(ids(f.copyWith(hasBioOrPrompt: true).apply(pool)), ['bio', 'prompt']);
    expect(ids(f.copyWith(threePhotos: true).apply(pool)), ['photos']);
    expect(ids(f.copyWith(hasVoice: true).apply(demoPeople)),
        ['ananya', 'isha', 'tara']);
  });

  test('Strict ranges hide people; soft ranges list them after, nearest first',
      () {
    final pool = [
      member('far', distance: 60),
      member('old', age: 55),
      member('near', distance: 3),
      member('mid', distance: 40),
      member('noBirthday', age: 0),
    ];
    const f = DiscoverFilters();
    expect(ids(f.apply(pool)), ['near', 'noBirthday']);
    expect(ids(f.copyWith(strictDistance: false).apply(pool)),
        ['near', 'noBirthday', 'mid', 'far']);
    expect(ids(f.copyWith(strictAges: false).apply(pool)),
        ['near', 'noBirthday', 'old']);
    expect(
        ids(f.copyWith(strictAges: false, strictDistance: false).apply(pool)),
        ['near', 'noBirthday', 'mid', 'far', 'old']);
  });

  test('Reset is the defaults; activeCount counts changes; JSON round-trips',
      () {
    const defaults = DiscoverFilters();
    expect(defaults.activeCount, 0);
    expect(defaults.ages, const RangeValues(21, 40));
    expect(defaults.distance, 25);
    expect(defaults.strictAges && defaults.strictDistance, isTrue);
    final busy = defaults.copyWith(
        ages: const RangeValues(25, 35),
        strictDistance: false,
        onlineNow: true,
        intents: {LookingFor.dateNight},
        languages: {'Hindi'},
        heights: const RangeValues(150, 180),
        education: {'phd'},
        threePhotos: true);
    expect(busy.activeCount, 8);
    expect(busy.moreCount, 4);
    final back = DiscoverFilters.fromJson(busy.toJson());
    expect(back.toJson(), busy.toJson());
    expect(DiscoverFilters.fromJson(const {}).toJson(), defaults.toJson());

    final store = PreviewStore();
    addTearDown(store.dispose);
    store.setFilters(busy);
    expect(store.discover, isEmpty);
    store.setFilters(const DiscoverFilters());
    expect(store.filters.activeCount, 0);
    // Tara is already in a demo conversation.
    expect(ids(store.discover), ['ananya', 'meera', 'isha']);
  });

  test('The live count uses the same filtering as Discover', () {
    final store = PreviewStore();
    addTearDown(store.dispose);
    final pending = store.filters.copyWith(education: {'graduate'});
    expect(ids(store.discoverWith(pending)), ['meera', 'isha']);
    expect(store.discover.length, 3, reason: 'nothing saved yet');
    store.skip(demoPeople[1]);
    expect(ids(store.discoverWith(pending)), ['isha']);
  });

  test('Lifestyle fields come from cards and go into the profile row', () {
    final p = Person.fromCard({
      'id': 'x',
      'drinking': 'socially',
      'smoking': 'non_smoker',
      'education': 'phd',
      'family_plans': 'open',
    }, (path) => path);
    expect([p.drinking, p.smoking, p.education, p.familyPlans],
        ['socially', 'non_smoker', 'phd', 'open']);
    expect(Person.fromCard({'id': 'y'}, (path) => path).familyPlans, '');
    final store = PreviewStore();
    addTearDown(store.dispose);
    store.myFamilyPlans = 'has_kids';
    expect(store.profileRow['family_plans'], 'has_kids');
    expect(store.profileRow['drinking'], '');
  });
}
