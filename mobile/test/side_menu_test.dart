import 'package:everlane/side_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Rows show a title, a subtitle and the likes count',
      (tester) async {
    var opened = '';
    var edited = false;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SideMenu(
                name: 'Rohan',
                age: 29,
                location: 'Bengaluru, India',
                onEdit: () => edited = true,
                items: [
          SideMenuItem(const Icon(Icons.favorite_border), 'Admirers',
              'People who have liked your profile', Colors.pink,
              () => opened = 'Admirers',
              badge: 2),
          SideMenuItem(const CrownIcon(), 'Everlane Plus',
              'Premium plans and exclusive benefits', Colors.amber,
              () => opened = 'Plus'),
          SideMenuItem(const TwoHeartsIcon(), 'Connections',
              'Your mutual likes and matches', Colors.purple, () {}),
        ]))));
    expect(tester.takeException(), isNull);
    expect(find.text('Rohan, 29'), findsOneWidget);
    expect(find.text('BENGALURU, INDIA'), findsOneWidget);
    expect(find.text('People who have liked your profile'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    await tester.tap(find.text('Everlane Plus'));
    expect(opened, 'Plus');
    await tester.tap(find.byTooltip('Edit profile'));
    expect(edited, isTrue);
  });
}
