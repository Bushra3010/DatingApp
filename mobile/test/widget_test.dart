import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everlane/main.dart';

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
    expect(find.text('Passed on Meera'), findsOneWidget);
    expect(find.text('Isha, 25'), findsOneWidget);
    await tester.drag(find.text('Isha, 25'), const Offset(40, 0));
    await tester.pumpAndSettle();
    expect(find.text('Isha, 25'), findsOneWidget);
    expect(find.text('7 likes left · Preview'), findsOneWidget);
  });
}
