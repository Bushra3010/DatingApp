import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everlane/admin.dart';
import 'package:everlane/models.dart';
import 'package:everlane/screens.dart';
import 'package:everlane/theme.dart';
import 'package:everlane/upi.dart';

class _SignedInStore extends PreviewStore {
  @override
  bool get signedIn => true;
}

final _upiOn = AppSettings.fromJson({
  'upi': {'enabled': true, 'vpa': 'everlane@okbank', 'payee_name': 'Everlane'}
});

Future<void> open(WidgetTester tester, PreviewStore store) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
      theme: everlaneTheme(), home: MembershipScreen(store: store)));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Change plan'));
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(find.text(text), 200,
      scrollable: find
          .descendant(
              of: find.byType(MembershipScreen),
              matching: find.byType(Scrollable))
          .first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Choosing Free asks first, and Keep leaves the plan alone',
      (tester) async {
    final store = _SignedInStore()
      ..settings = _upiOn
      ..plan = Plan.platinum;
    await open(tester, store);
    await tapText(tester, 'Choose Free');
    expect(find.text('Switch to Free?'), findsOneWidget);
    expect(find.textContaining('pay ${Plan.platinum.displayPrice} by UPI'),
        findsOneWidget);
    await tester.tap(find.text('Keep Platinum'));
    await tester.pumpAndSettle();
    expect(store.plan, Plan.platinum);

    await tapText(tester, 'Choose Free');
    await tester.tap(find.text('Switch to Free'));
    await tester.pumpAndSettle();
    expect(store.plan, Plan.free);
  });

  testWidgets('From Free, Choose Platinum opens the UPI payment',
      (tester) async {
    final store = _SignedInStore()..settings = _upiOn;
    await tester.pumpWidget(MaterialApp(
        theme: everlaneTheme(), home: MembershipScreen(store: store)));
    await tester.pumpAndSettle();
    await tapText(tester, 'Choose Platinum');
    expect(find.byType(UpiPaySheet), findsOneWidget);
  });

  testWidgets('A paid plan can’t be dropped until it ends', (tester) async {
    final store = _SignedInStore()
      ..settings = _upiOn
      ..plan = Plan.gold
      ..planPaid = true
      ..planUntil = DateTime(2026, 12, 7);
    await open(tester, store);
    expect(find.text('Choose Free'), findsNothing);
    expect(find.textContaining('Your Gold plan runs until'), findsWidgets);
    store.choosePlan(Plan.free);
    expect(store.plan, Plan.gold);
  });
}
