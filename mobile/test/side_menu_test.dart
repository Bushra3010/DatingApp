import 'package:everlane/side_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<int> stackedCards(WidgetTester tester, int likes) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SideMenu(
                name: 'Rohan',
                age: 29,
                location: 'Bengaluru, India',
                items: [
          SideMenuItem(Icons.favorite, 'Likes you · $likes',
              const [Colors.pink, Colors.red], () {},
              badge: likes),
          SideMenuItem(Icons.settings, 'Settings',
              const [Colors.white, Colors.purple], () {}),
        ]))));
    expect(tester.takeException(), isNull);
    return find.byKey(const ValueKey('stack-card-1')).evaluate().length +
        find.byKey(const ValueKey('stack-card-2')).evaluate().length;
  }

  testWidgets('Likes you stacks one card per extra like, up to two',
      (tester) async {
    expect(await stackedCards(tester, 0), 0);
    expect(await stackedCards(tester, 1), 0);
    expect(await stackedCards(tester, 2), 1);
    expect(await stackedCards(tester, 3), 2);
    expect(await stackedCards(tester, 9), 2);
  });
}
