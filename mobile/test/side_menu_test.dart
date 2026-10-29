import 'package:everlane/side_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Likes you is a single row with its badge, no stacked cards',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SideMenu(
                name: 'Rohan',
                age: 29,
                location: 'Bengaluru, India',
                items: [
          SideMenuItem(Icons.favorite, 'Likes you · 2',
              const [Colors.pink, Colors.red], () {},
              badge: 2),
          SideMenuItem(Icons.settings, 'Settings',
              const [Colors.white, Colors.purple], () {}),
        ]))));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('stack-card-1')), findsNothing);
    expect(find.byKey(const ValueKey('stack-card-2')), findsNothing);
    expect(find.text('2'), findsOneWidget);
  });
}
