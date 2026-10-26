import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:flutter_test/flutter_test.dart';
import 'package:everlane/hangouts.dart';
import 'package:everlane/introductions.dart';
import 'package:everlane/main.dart';
import 'package:everlane/models.dart';
import 'package:everlane/photo_picker.dart';
import 'package:everlane/screens.dart';

/// A tiny valid 1x1 PNG, so Image.memory in tests decodes without error.
final Uint8List _fakePhoto = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=');

void main() {
  setUp(() {
    pickPhotoBytes = () async => _fakePhoto;
  });
  testWidgets('Main screens work on a phone and accepting a like opens a chat',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const EverlaneApp(onboarded: true));
    await tester.pumpAndSettle();
    expect(find.text('Ananya, 27'), findsOneWidget);
    await tester.tap(find.text('Likes you'));
    await tester.pumpAndSettle();
    expect(find.text('2 people like you.'), findsOneWidget);
    expect(find.text('Like back & say hello'), findsNothing);
    await tester.tap(find.text('Explore incoming connections'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Choose Gold'), 200,
        scrollable: find
            .descendant(
                of: find.byType(MembershipScreen),
                matching: find.byType(Scrollable))
            .first);
    await tester.ensureVisible(find.text('Choose Gold'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose Gold'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Like back & say hello').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Like back & say hello').first);
    // The match celebration animates hearts forever, so pumpAndSettle would
    // hang here — pump a bounded number of frames instead.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    expect(find.text('It’s a match!'), findsOneWidget);
    await tester.tap(find.text('Start chatting'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
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
    expect(find.text('Rohan, 29'), findsOneWidget);
  });

  testWidgets('Filters and like composer fit a small screen', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const EverlaneApp(onboarded: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Filter profiles'));
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
    await tester.pumpWidget(const EverlaneApp(onboarded: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ananya, 27'));
    await tester.pumpAndSettle();
    expect(find.text('Bengaluru · Nearby'), findsOneWidget);
    await tester.tap(find.byTooltip('Play voice prompt'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byTooltip('Pause voice prompt'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('About'), 200,
        scrollable: find
            .descendant(
                of: find.byType(PersonDetailsScreen),
                matching: find.byType(Scrollable))
            .first);
    expect(find.text('About'), findsOneWidget);
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
    await tester.pumpWidget(const EverlaneApp(onboarded: true));
    await tester.pumpAndSettle();
    await tester.drag(find.text('Ananya, 27'), const Offset(300, 0));
    await tester.pumpAndSettle();
    expect(find.text('You liked Ananya'), findsOneWidget);
    expect(find.text('7 likes left today · Free'), findsOneWidget);
    await tester.drag(find.text('Meera, 28'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text('Isha, 25'), findsOneWidget);
    await tester.drag(find.text('Isha, 25'), const Offset(40, 0));
    await tester.pumpAndSettle();
    expect(find.text('Isha, 25'), findsOneWidget);
    expect(find.text('7 likes left today · Free'), findsOneWidget);
  });

  testWidgets('Explore lists people by what they are looking for',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const EverlaneApp(onboarded: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore').last);
    await tester.pumpAndSettle();
    expect(find.text('Nearby profiles'), findsOneWidget);
    expect(find.text('Crossed paths'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Long-term relationship'), 200,
        scrollable: find.byType(Scrollable).first);
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
    await tester.pumpWidget(const EverlaneApp(onboarded: true));
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
    expect(find.text('25 likes left today · Plus'), findsOneWidget);
    await tester.tap(find.byTooltip('Undo last pass'));
    await tester.pumpAndSettle();
    expect(find.text('Ananya, 27'), findsOneWidget);
    expect(find.text('Ananya is back'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Hangouts are Platinum-only, then let you join and host plans',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const EverlaneApp(onboarded: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hangouts'));
    await tester.pumpAndSettle();
    expect(find.text('Hangouts come with Platinum.'), findsOneWidget);
    await tester.tap(find.text('See membership'));
    await tester.pumpAndSettle();
    final plans = find
        .descendant(
            of: find.byType(MembershipScreen),
            matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(find.text('Choose Platinum'), 200,
        scrollable: plans);
    await tester.ensureVisible(find.text('Choose Platinum'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose Platinum'));
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

  testWidgets('Dark by default, light mode can be switched on in Settings',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const EverlaneApp(onboarded: true));
    await tester.pumpAndSettle();
    Color background() =>
        tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor ??
        Theme.of(tester.element(find.byType(Scaffold).first))
            .scaffoldBackgroundColor;
    expect(background(), const Color(0xFF0D0B12));
    await tester.tap(find.text('You'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Dark mode'), 200,
        scrollable: find.byType(Scrollable).last);
    await tester.ensureVisible(find.text('Dark mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark mode'));
    await tester.pumpAndSettle();
    expect(background(), const Color(0xFFFAF7FF));
    await tester.tap(find.text('Dark mode'));
    await tester.pumpAndSettle();
    expect(background(), const Color(0xFF0D0B12));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Photo prompts invite a reply; Invisible mode is free',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const EverlaneApp(onboarded: true));
    await tester.pumpAndSettle();
    expect(find.text('Bengaluru · Nearby'), findsOneWidget);
    await tester.tap(find.text('Ask about this photo'));
    await tester.pumpAndSettle();
    expect(find.text('You’re liking Ananya’s photo.'), findsOneWidget);
    Navigator.of(tester.element(find.text('You’re liking Ananya’s photo.')))
        .pop();
    await tester.pumpAndSettle();
    // The Discover card shows neither the soundtrack nor the bio.
    expect(find.textContaining('Ananya’s soundtrack'), findsNothing);
    expect(find.textContaining('Designer by day'), findsNothing);
    await tester.tap(find.text('You'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Invisible mode'), 200,
        scrollable: find.byType(Scrollable).last);
    await tester.ensureVisible(find.text('Invisible mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Invisible mode'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<SwitchListTile>(
                find.widgetWithText(SwitchListTile, 'Invisible mode'))
            .value,
        isTrue);
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
    await tester.pumpWidget(const EverlaneApp(onboarded: true));
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
    final editSheet = find
        .descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(find.text('Post profile'), 200,
        scrollable: editSheet);
    await tester.ensureVisible(find.text('Post profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Post profile'));
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
    await tester.pumpWidget(const EverlaneApp(onboarded: true));
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

  testWidgets('Onboarding leads to the quiz and Chemistry on profiles',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const EverlaneApp());
    await tester.pumpAndSettle();
    expect(
        find.text('Less swiping. More meaningful connections.'.toUpperCase()),
        findsOneWidget);
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    // One question per page.
    Future<void> tapText(String text) async {
      await tester.ensureVisible(find.text(text));
      await tester.pumpAndSettle();
      await tester.tap(find.text(text));
      await tester.pumpAndSettle();
    }

    expect(find.text('What’s your first name?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Aarav');
    await tapText('Continue');
    expect(find.text('Select your birth date'), findsOneWidget);
    await tester.tap(find.textContaining('y.o.'));
    await tester.pumpAndSettle();
    expect(find.text('What’s your gender?'), findsOneWidget);
    await tapText('Man');
    await tapText('Continue');
    expect(find.text('Who are you into?'), findsOneWidget);
    await tapText('Women');
    await tapText('Continue');
    await tapText('Continue'); // height
    await tapText('Hindi');
    await tapText('Continue');
    await tapText('Casual');
    await tapText('Continue');
    expect(find.text('What do you enjoy?'), findsOneWidget);
    await tapText('📚  Books');
    await tapText('Continue');
    await tapText('Skip'); // city
    expect(find.text('Add your photos'), findsOneWidget);
    await tapText('Add photo');
    await tapText('Finish');
    expect(find.text('You’re all set, Aarav.'), findsOneWidget);
    await tester.ensureVisible(find.text('Take the compatibility quiz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take the compatibility quiz'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Question 1 of 24'), findsOneWidget);
    await tester.tap(find.text('A long-term committed relationship'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Slowly, building trust first'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('After a few dates'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Very important, with room for compromise'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A few meaningful conversations'));
    await tester.pumpAndSettle();
    // Choose up to 2: a third pick is ignored.
    await tester.tap(find.text('Words of appreciation'));
    await tester.tap(find.text('Quality time and undivided attention'));
    await tester.tap(find.text('Physical affection'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_box_rounded), findsNWidgets(2));
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ananya, 27'));
    await tester.pumpAndSettle();
    final details = find
        .descendant(
            of: find.byType(PersonDetailsScreen),
            matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(find.text('Chemistry'), 200,
        scrollable: details);
    expect(find.text('Preliminary'), findsOneWidget);
    expect(find.text('Continue the quiz'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Onboarding can be skipped in the preview', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const EverlaneApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip to the app (preview)'));
    await tester.pumpAndSettle();
    expect(find.text('Ananya, 27'), findsOneWidget);
  });

  testWidgets('Boosts come with Gold and show when they end', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const EverlaneApp(onboarded: true));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Boost your profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Boost your profile'));
    await tester.pumpAndSettle();
    expect(find.text('Be seen by more people nearby.'), findsOneWidget);
    await tester.tap(find.text('See membership'));
    await tester.pumpAndSettle();
    final plans = find
        .descendant(
            of: find.byType(MembershipScreen),
            matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(find.text('Choose Gold'), 200,
        scrollable: plans);
    await tester.ensureVisible(find.text('Choose Gold'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose Gold'));
    await tester.pumpAndSettle();
    expect(
        find.text('Renews monthly at ₹499 until you cancel. Cancel anytime.'),
        findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Boost your profile'));
    await tester.pumpAndSettle();
    expect(find.text('2 of 2 boosts left this month'), findsOneWidget);
    await tester.tap(find.text('Start a 30-minute boost'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 2 boosts left this month'), findsOneWidget);
    expect(find.text('Boost active'), findsOneWidget);
    expect(find.textContaining('You’re boosted until'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings has Log out and Delete account, even in the preview',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const EverlaneApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip to the app (preview)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('You').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Delete account'), 300,
        scrollable: find.byType(Scrollable).first);
    // Clear of the bottom navigation bar.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -250));
    await tester.pumpAndSettle();
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Preview · not signed in'), findsOneWidget);
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    expect(find.text('Clear preview profile'), findsOneWidget);
    await tester.tap(find.text('Keep my account'));
    await tester.pumpAndSettle();
    expect(find.text('Delete account'), findsOneWidget);
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear preview profile'));
    await tester.pumpAndSettle();
    expect(find.text('Skip to the app (preview)'), findsOneWidget,
        reason: 'back on the welcome screen');
    expect(tester.takeException(), isNull);
  });
}
