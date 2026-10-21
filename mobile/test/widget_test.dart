import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:flutter_test/flutter_test.dart';
import 'package:everlane/hangouts.dart';
import 'package:everlane/introductions.dart';
import 'package:everlane/main.dart';
import 'package:everlane/models.dart';
import 'package:everlane/screens.dart';

void main() {
  testWidgets('Main screens work on a phone and accepting a like opens a chat',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const EverlaneApp());
    await tester.pumpAndSettle();
    expect(find.text('Ananya, 27'), findsOneWidget);
    await tester.tap(find.text('Likes you'));
    await tester.pumpAndSettle();
    expect(find.text('2 people like you.'), findsOneWidget);
    expect(find.text('Like back & say hello'), findsNothing);
    await tester.tap(find.text('Explore incoming connections'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Choose Plus'), 200,
        scrollable: find
            .descendant(
                of: find.byType(MembershipScreen),
                matching: find.byType(Scrollable))
            .first);
    await tester.ensureVisible(find.text('Choose Plus'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose Plus'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Like back & say hello').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Like back & say hello').first);
    await tester.pumpAndSettle();
    expect(find.text('Meera'), findsOneWidget);
    await tester.enterText(
        find.byType(TextField), 'What’s your favourite café?');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(find.text('What’s your favourite café?'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Messages'));
    await tester.pumpAndSettle();
    expect(find.text('What’s your favourite café?'), findsOneWidget);
    await tester.tap(find.text('You'));
    await tester.pumpAndSettle();
    expect(find.text('Rohit, 29'), findsOneWidget);
  });

  testWidgets('Filters and like composer fit a small screen', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const EverlaneApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Discovery preferences'));
    await tester.pumpAndSettle();
    expect(find.text('Show my people'), findsOneWidget);
    await tester.ensureVisible(find.text('Show my people'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show my people'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Like Ananya’s photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Like Ananya’s photo'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField), 'Your ideal Sunday sounds lovely.');
    await tester.ensureVisible(find.text('Send like'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send like'));
    await tester.pumpAndSettle();
    expect(find.text('Meera, 28'), findsOneWidget);
  });
  testWidgets('Profile details and drawer navigation work', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const EverlaneApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ananya, 27'));
    await tester.pumpAndSettle();
    expect(find.text('About'), findsOneWidget);
    expect(find.text('Bengaluru · Nearby'), findsOneWidget);
    await tester.tap(find.byTooltip('Play voice prompt'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byTooltip('Pause voice prompt'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Interests'), 200,
        scrollable: find
            .descendant(
                of: find.byType(PersonDetailsScreen),
                matching: find.byType(Scrollable))
            .first);
    expect(find.text('Interests'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open profile menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Matches'));
    await tester.pumpAndSettle();
    expect(find.text('Tara'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Swiping right likes and swiping left passes', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const EverlaneApp());
    await tester.pumpAndSettle();
    await tester.drag(find.text('Ananya, 27'), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(find.text('You liked Ananya'), findsOneWidget);
    expect(find.text('7 likes left · Preview'), findsOneWidget);
    await tester.drag(find.text('Meera, 28'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text('Isha, 25'), findsOneWidget);
    await tester.drag(find.text('Isha, 25'), const Offset(40, 0));
    await tester.pumpAndSettle();
    expect(find.text('Isha, 25'), findsOneWidget);
    expect(find.text('7 likes left · Preview'), findsOneWidget);
  });

  testWidgets('Explore lists people by what they are looking for',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const EverlaneApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore').last);
    await tester.pumpAndSettle();
    expect(find.text('Long-term relationship'), findsOneWidget);
    await tester.ensureVisible(find.text('Date night'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Date night'));
    await tester.pumpAndSettle();
    expect(find.text('Isha, 25'), findsOneWidget);
    expect(find.text('Tara, 29'), findsOneWidget);
    expect(find.text('Ananya, 27'), findsNothing);
    await tester.tap(find.text('Tara, 29'));
    await tester.pumpAndSettle();
    expect(find.text('Long-term relationship'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Rewind needs Plus, then brings back the last pass',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const EverlaneApp());
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Pass on Ananya'));
    await tester.tap(find.byTooltip('Pass on Ananya'));
    await tester.pumpAndSettle();
    expect(find.text('Meera, 28'), findsOneWidget);
    await tester.tap(find.byTooltip('Undo last pass'));
    await tester.pumpAndSettle();
    expect(find.text('Passed by mistake?'), findsOneWidget);
    await tester.tap(find.text('See membership'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Choose Plus'), 200,
        scrollable: find
            .descendant(
                of: find.byType(MembershipScreen),
                matching: find.byType(Scrollable))
            .first);
    await tester.ensureVisible(find.text('Choose Plus'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose Plus'));
    await tester.pumpAndSettle();
    expect(find.text('Plus member'), findsOneWidget);
    expect(find.text('Current plan'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Unlimited likes · Plus'), findsOneWidget);
    await tester.tap(find.byTooltip('Undo last pass'));
    await tester.pumpAndSettle();
    expect(find.text('Ananya, 27'), findsOneWidget);
    expect(find.text('Ananya is back'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Hangouts are Premium-only, then let you join and host plans',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const EverlaneApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hangouts'));
    await tester.pumpAndSettle();
    expect(find.text('Hangouts are a Premium feature.'), findsOneWidget);
    await tester.tap(find.text('See membership'));
    await tester.pumpAndSettle();
    final plans = find
        .descendant(
            of: find.byType(MembershipScreen),
            matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(find.text('Choose Premium'), 200,
        scrollable: plans);
    await tester.ensureVisible(find.text('Choose Premium'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose Premium'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hangouts'));
    await tester.pumpAndSettle();
    expect(find.text('Ready to hang out?'), findsOneWidget);
    await tester.tap(find.text('Grab food'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Join Hangouts'), 200,
        scrollable: find
            .descendant(
                of: find.byType(HangoutSetupScreen),
                matching: find.byType(Scrollable))
            .first);
    await tester.ensureVisible(find.text('Join Hangouts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Join Hangouts'));
    await tester.pumpAndSettle();
    expect(find.text('Grab food · Flexible'), findsOneWidget);
    await tester.tap(find.text('Dinner'));
    await tester.pumpAndSettle();
    expect(find.text('Cook-along dinner night'), findsOneWidget);
    expect(find.text('Filter coffee and a bookstore'), findsNothing);
    await tester.tap(find.text('Request to join'));
    await tester.pumpAndSettle();
    expect(find.text('Requested'), findsOneWidget);
    expect(find.text('Request sent to Tara'), findsOneWidget);
    await tester.tap(find.text('Message host'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Hi, I’m interested in “Cook-along dinner night”. Is there still room?'),
        findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('All'));
    await tester.tap(find.text('Host a plan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Sunday brunch');
    await tester.enterText(find.byType(TextField).at(1), 'Sunday, 11 am');
    await tester.enterText(find.byType(TextField).at(2), 'Indiranagar');
    await tester.ensureVisible(find.text('Post plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Post plan'));
    await tester.pumpAndSettle();
    expect(find.text('Sunday brunch'), findsOneWidget);
    expect(find.text('You’re hosting'.toUpperCase()), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Light by default, dark mode can be switched on in Settings',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const EverlaneApp());
    await tester.pumpAndSettle();
    Color background() =>
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor ??
        Theme.of(tester.element(find.byType(Scaffold).first))
            .scaffoldBackgroundColor;
    expect(background(), const Color(0xFFFFF8EC));
    await tester.tap(find.text('You'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Dark mode'), 200,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Dark mode'));
    await tester.pumpAndSettle();
    expect(background(), const Color(0xFF17120F));
    await tester.tap(find.text('Dark mode'));
    await tester.pumpAndSettle();
    expect(background(), const Color(0xFFFFF8EC));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Photo prompts invite a reply; Invisible mode needs Plus',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const EverlaneApp());
    await tester.pumpAndSettle();
    expect(find.text('Bengaluru · Nearby'), findsOneWidget);
    await tester.tap(find.text('Ask about this photo'));
    await tester.pumpAndSettle();
    expect(find.text('You’re liking Ananya’s photo.'), findsOneWidget);
    Navigator.of(tester.element(find.text('You’re liking Ananya’s photo.')))
        .pop();
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Ananya’s soundtrack'));
    await tester.pumpAndSettle();
    expect(find.text('You’re liking Ananya’s soundtrack.'), findsOneWidget);
    Navigator.of(
            tester.element(find.text('You’re liking Ananya’s soundtrack.')))
        .pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('You'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Invisible mode · Plus'), 200,
        scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Invisible mode · Plus'));
    await tester.pumpAndSettle();
    expect(find.text('Date on your own terms.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sheets with text fields close cleanly even when slow',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // Closing now takes longer than the old fixed 300 ms dispose delay.
    timeDilation = 3;
    await tester.pumpWidget(const EverlaneApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ask about this photo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Where was this taken?');
    await tester.ensureVisible(find.text('Send like'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send like'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    await tester.pumpAndSettle();
    expect(find.text('Like sent to Ananya in this preview.'), findsOneWidget);
    await tester.tap(find.text('You'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Rohan');
    await tester.ensureVisible(find.text('Save preview profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save preview profile'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    await tester.pumpAndSettle();
    timeDilation = 1;
    expect(find.text('Rohan, 29'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Five questions lead to an introduction and a chat',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const EverlaneApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find an introduction'));
    await tester.pumpAndSettle();
    expect(find.text('Question 1 of 5'), findsOneWidget);
    for (final option in [
      'A lasting partnership',
      'Coffee and a long walk',
      'Steadily, with clear intent',
      'Kindness',
      'Cosy at home',
    ]) {
      await tester.tap(find.text(option));
      await tester.pump();
    }
    expect(find.text('Finding your introduction…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'You’re looking for a lasting partnership. Here’s someone to begin with.'),
        findsOneWidget);
    expect(find.text('Ananya, 27'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Show another'), 200,
        scrollable: find
            .descendant(
                of: find.byType(IntroductionQuizScreen),
                matching: find.byType(Scrollable))
            .first);
    await tester.ensureVisible(find.text('Show another'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show another'));
    await tester.pumpAndSettle();
    expect(find.text('Tara, 29'), findsOneWidget);
    await tester.ensureVisible(find.text('Retake'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retake'));
    await tester.pumpAndSettle();
    expect(find.text('Question 1 of 5'), findsOneWidget);
    for (final option in [
      'Good company for events and travel',
      'Dinner somewhere new',
      'Spontaneously',
      'Curiosity',
      'Travelling somewhere new',
    ]) {
      await tester.tap(find.text(option));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();
    expect(find.text('Meera, 28'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Start chat'), 200,
        scrollable: find
            .descendant(
                of: find.byType(IntroductionQuizScreen),
                matching: find.byType(Scrollable))
            .first);
    await tester.ensureVisible(find.text('Start chat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start chat'));
    await tester.pumpAndSettle();
    expect(find.text(demoPeople[1].answer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
