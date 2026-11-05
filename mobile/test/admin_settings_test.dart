import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everlane/admin.dart';
import 'package:everlane/legal.dart';
import 'package:everlane/main.dart';
import 'package:everlane/models.dart';
import 'package:everlane/support.dart';

/// A phone-sized view for the app.
void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  test('Settings default to everything on and nothing blocked', () {
    const s = AppSettings();
    expect(s.maintenance, isFalse);
    expect(s.hangouts && s.likesYou && s.boost && s.quiz, isTrue);
    expect(s.photosNeeded, 1);
    expect(s.adultAge, 18);
    expect(
        s.needsUpdate(appVersion, web: false, platform: TargetPlatform.android),
        isFalse);
    // Missing or odd values fall back to the defaults too.
    final parsed = AppSettings.fromJson({
      'flags': {'hangouts': false},
      'age': {'min_age': 16},
      'onboarding': {'min_photos': 3},
    });
    expect(parsed.hangouts, isFalse);
    expect(parsed.sparks, isTrue);
    expect(parsed.adultAge, 18, reason: 'never below 18');
    expect(parsed.photosNeeded, 3);
  });

  test('Versions compare part by part', () {
    expect(compareVersions('0.3.9', '0.3.10'), -1);
    expect(compareVersions('0.3.9+12', '0.3.9'), 0);
    expect(compareVersions('1.0', '0.9.9'), 1);
    final s = AppSettings.fromJson({
      'min_version': {'web': '0.4.0', 'android': '0.3.0', 'ios': ''}
    });
    expect(s.needsUpdate('0.3.9', web: true, platform: TargetPlatform.android),
        isTrue);
    expect(s.needsUpdate('0.3.9', web: false, platform: TargetPlatform.android),
        isFalse);
    expect(s.needsUpdate('0.3.9', web: false, platform: TargetPlatform.iOS),
        isFalse);
  });

  testWidgets('Maintenance replaces the app with a retry screen',
      (tester) async {
    phone(tester);
    final store = PreviewStore()
      ..settings = AppSettings.fromJson({
        'maintenance': {'on': true, 'message': 'Back by 6 pm.'}
      });
    await tester.pumpWidget(EverlaneApp(onboarded: true, store: store));
    await tester.pumpAndSettle();
    expect(find.text('We’ll be right back'), findsOneWidget);
    expect(find.text('Back by 6 pm.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Ananya, 27'), findsNothing);
    // Maintenance ends: the app comes back.
    store
      ..settings = const AppSettings()
      ..update();
    await tester.pumpAndSettle();
    expect(find.text('Ananya, 27'), findsOneWidget);
  });

  testWidgets('An old version is asked to update', (tester) async {
    phone(tester);
    final store = PreviewStore()
      ..settings = AppSettings.fromJson({
        'min_version': {'web': '99.0.0', 'android': '99.0.0', 'ios': '99.0.0'}
      });
    await tester.pumpWidget(EverlaneApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Update Everlane'), findsOneWidget);
    expect(find.text('Get started'), findsNothing, reason: 'blocks onboarding');
  });

  testWidgets('Switching Hangouts off hides it and keeps the tabs right',
      (tester) async {
    phone(tester);
    final store = PreviewStore()
      ..settings = AppSettings.fromJson({
        'flags': {'hangouts': false}
      });
    await tester.pumpWidget(EverlaneApp(onboarded: true, store: store));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Hangouts'), findsNothing);
    await tester.tap(find.byTooltip('Likes you'));
    await tester.pumpAndSettle();
    expect(find.text('2 people like you.'), findsOneWidget);
    await tester.tap(find.byTooltip('You'));
    await tester.pumpAndSettle();
    expect(find.text('Rohan, 29'), findsOneWidget);
    await tester.tap(find.byTooltip('Open profile menu'));
    await tester.pumpAndSettle();
    expect(find.text('Host a plan or join one near you'), findsNothing);
    expect(find.text('Help & support'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Likes you can be switched off', (tester) async {
    phone(tester);
    final store = PreviewStore()
      ..settings = AppSettings.fromJson({
        'flags': {'likes_you': false, 'sparks': false, 'boost': false}
      });
    await tester.pumpWidget(EverlaneApp(onboarded: true, store: store));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Boost your profile'), findsNothing);
    expect(find.byTooltip('Send Ananya a Spark'), findsNothing);
    await tester.tap(find.byTooltip('Likes you'));
    await tester.pumpAndSettle();
    expect(find.text('Not available right now.'), findsOneWidget);
    expect(find.text('2 people like you.'), findsNothing);
  });

  testWidgets('Banners show one at a time, newest first, and can be dismissed',
      (tester) async {
    phone(tester);
    final store = PreviewStore();
    store.announcements.addAll([
      Announcement(
          id: 'new',
          kind: 'banner',
          title: 'Diwali week',
          body: 'Extra Sparks for everyone.',
          createdAt: DateTime(2026, 11, 2)),
      Announcement(
          id: 'old',
          kind: 'banner',
          title: 'Welcome to Everlane',
          createdAt: DateTime(2026, 10, 1)),
    ]);
    await tester.pumpWidget(EverlaneApp(onboarded: true, store: store));
    await tester.pumpAndSettle();
    expect(find.text('Diwali week'), findsOneWidget);
    expect(find.text('Welcome to Everlane'), findsNothing);
    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.text('Diwali week'), findsNothing);
    expect(store.dismissedAnnouncements, contains('new'));
    expect(find.text('Welcome to Everlane'), findsOneWidget);
    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Everlane'), findsNothing);
    expect(find.text('Ananya, 27'), findsOneWidget);
  });

  testWidgets('A notice opens once as a dialog', (tester) async {
    phone(tester);
    final store = PreviewStore();
    store.announcements.add(const Announcement(
        id: 'n1',
        kind: 'notice',
        title: 'New terms',
        body: 'We updated them.'));
    await tester.pumpWidget(EverlaneApp(onboarded: true, store: store));
    await tester.pumpAndSettle();
    expect(find.text('New terms'), findsOneWidget);
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('New terms'), findsNothing);
    store.update();
    await tester.pumpAndSettle();
    expect(find.text('New terms'), findsNothing, reason: 'only once');
  });

  testWidgets('The Help center groups FAQ by category', (tester) async {
    phone(tester);
    final store = PreviewStore()
      ..faq = const [
        FaqItem(
            id: '1',
            category: 'Account',
            question: 'How do I change my photos?',
            answer: 'Open your profile and tap a photo.'),
        FaqItem(
            id: '2',
            category: 'Safety',
            question: 'How do I report someone?',
            answer: 'Use the menu on their profile.'),
      ];
    addTearDown(store.dispose);
    await tester.pumpWidget(MaterialApp(home: HelpCenterScreen(store: store)));
    await tester.pumpAndSettle();
    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(find.text('SAFETY'), findsOneWidget);
    expect(find.text('How do I report someone?'), findsOneWidget);
    expect(find.text('Open your profile and tap a photo.'), findsNothing);
    await tester.tap(find.text('How do I change my photos?'));
    await tester.pumpAndSettle();
    expect(find.text('Open your profile and tap a photo.'), findsOneWidget);
  });

  testWidgets('Help & support is reachable from Preferences', (tester) async {
    phone(tester);
    await tester.pumpWidget(const EverlaneApp(onboarded: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('You'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Help & support'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Help & support'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Help & support'));
    await tester.pumpAndSettle();
    expect(find.text('How can we help?'), findsOneWidget);
    expect(find.text('Sign in to contact us'), findsOneWidget);
    await tester.tap(find.text('Help center'));
    await tester.pumpAndSettle();
    expect(find.text('No articles yet.'), findsOneWidget);
  });

  testWidgets('Community guidelines fall back to the built-in text offline',
      (tester) async {
    phone(tester);
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => TextButton(
                onPressed: () => openGuidelines(context),
                child: const Text('Open')))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Community guidelines'), findsOneWidget);
    expect(find.text('Be kind'), findsOneWidget);
    expect(find.text('Last updated: $legalUpdated'), findsOneWidget);
  });
}
