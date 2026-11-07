import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everlane/admin.dart';
import 'package:everlane/models.dart';
import 'package:everlane/screens.dart';
import 'package:everlane/theme.dart';
import 'package:everlane/upi.dart';

/// Acts as a signed-in member without a network: every backend call is
/// still skipped (there's no backend), only the UPI checkout is reachable.
class _SignedInStore extends PreviewStore {
  @override
  bool get signedIn => true;
}

final _upiOn = AppSettings.fromJson({
  'upi': {
    'enabled': true,
    'vpa': 'everlane@okbank',
    'payee_name': 'Everlane',
    'note': 'Payments are checked by hand.',
  }
});

void phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> openMembershipScreen(
    WidgetTester tester, PreviewStore store) async {
  await tester.pumpWidget(MaterialApp(
      theme: everlaneTheme(), home: MembershipScreen(store: store)));
  await tester.pumpAndSettle();
}

Future<void> tapChooseGold(WidgetTester tester) async {
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
}

void main() {
  test('UPI is off by default and parsed from app_settings', () {
    expect(const AppSettings().upi.ready, isFalse);
    expect(AppSettings.fromJson({}).upi.enabled, isFalse);
    expect(
        AppSettings.fromJson({
          'upi': {'enabled': true, 'vpa': ' '}
        }).upi.ready,
        isFalse,
        reason: 'no UPI ID, nowhere to pay');
    final upi = _upiOn.upi;
    expect(upi.ready, isTrue);
    expect(upi.vpa, 'everlane@okbank');
    expect(upi.note, 'Payments are checked by hand.');
    final uri = upiPayUri(upi, Plan.gold).toString();
    expect(uri, startsWith('upi://pay?pa=everlane@okbank&pn=Everlane&am=499'));
    expect(uri, contains('cu=INR'));
    expect(uri, contains('tn=Everlane%20Gold'));
  });

  test('The payment note names the member, so the team knows who paid', () {
    expect(upiNote(Plan.platinum, name: 'Pratik', userId: '9c037512-d000-4931'),
        'Everlane Platinum - Pratik (9C0375)');
    expect(upiNote(Plan.gold), 'Everlane Gold');
    final uri = upiPayUri(_upiOn.upi, Plan.gold, name: 'Pratik', userId: '9c037512-d000')
        .toString();
    expect(uri, contains('tn=Everlane%20Gold%20-%20Pratik%20(9C0375)'));
  });

  test('UTRs are 6–35 letters or digits', () {
    expect(validUtr('123456789012'), isTrue);
    expect(validUtr('AXIS1234ab'), isTrue);
    expect(validUtr('12345'), isFalse);
    expect(validUtr('1234 5678'), isFalse);
    expect(validUtr('1' * 36), isFalse);
  });

  testWidgets('With UPI on, choosing a paid plan opens the UPI sheet',
      (tester) async {
    phone(tester);
    final store = _SignedInStore()..settings = _upiOn;
    await openMembershipScreen(tester, store);
    await tapChooseGold(tester);
    expect(find.text('Pay with UPI'), findsOneWidget);
    expect(find.text('everlane@okbank'), findsOneWidget);
    expect(find.text('Payee: Everlane'), findsOneWidget);
    expect(find.text('Pay ₹499 with a UPI app'), findsOneWidget);
    expect(find.text('Payments are checked by hand.'), findsOneWidget);
    // Nothing switches until an admin verifies the payment.
    expect(store.plan, Plan.free);
    expect(find.text('Welcome to Gold'), findsNothing);
  });

  testWidgets('Without an account, choosing a plan still switches locally',
      (tester) async {
    phone(tester);
    final store = PreviewStore()..settings = _upiOn;
    await openMembershipScreen(tester, store);
    await tapChooseGold(tester);
    expect(find.text('Pay with UPI'), findsNothing);
    expect(store.plan, Plan.gold);
  });

  testWidgets('The UTR field hints and checks the reference', (tester) async {
    phone(tester);
    final store = _SignedInStore()..settings = _upiOn;
    await openMembershipScreen(tester, store);
    await tapChooseGold(tester);
    expect(find.text('12-digit number from your payment app'), findsOneWidget);
    FilledButton submit() => tester.widget<FilledButton>(find.ancestor(
        of: find.text('I’ve paid — submit for verification'),
        matching: find.byType(FilledButton)));
    expect(submit().onPressed, isNull);

    final field = find.widgetWithText(TextField, 'UPI reference (UTR)');
    await tester.ensureVisible(field);
    await tester.enterText(field, '1234');
    await tester.pump();
    expect(
        find.text('Use the 6–35 letters or digits shown in your payment app'),
        findsOneWidget);
    expect(submit().onPressed, isNull);

    await tester.enterText(field, '123456789012');
    await tester.pump();
    expect(
        find.text('Use the 6–35 letters or digits shown in your payment app'),
        findsNothing);
    expect(submit().onPressed, isNotNull);
  });

  testWidgets('UPI payments are listed with their status', (tester) async {
    phone(tester);
    final store = _SignedInStore()..settings = _upiOn;
    store.upiPayments.addAll([
      for (final r in [
        {
          'id': 3,
          'plan': 'gold',
          'amount': 499,
          'utr': '111122223333',
          'status': 'pending',
          'reason': '',
          'created_at': '2026-11-06T10:00:00Z',
        },
        {
          'id': 2,
          'plan': 'plus',
          'amount': '249.00',
          'utr': '444455556666',
          'status': 'approved',
          'reason': '',
          'created_at': '2026-10-01T10:00:00Z',
        },
        {
          'id': 1,
          'plan': 'platinum',
          'amount': 899,
          'utr': '777788889999',
          'status': 'rejected',
          'reason': 'We couldn’t find this payment.',
          'created_at': '2026-09-01T10:00:00Z',
        },
      ])
        UpiPayment.fromRow(r)
    ]);
    await openMembershipScreen(tester, store);
    expect(find.text('Your UPI payments'), findsOneWidget);
    expect(find.text('Gold · ₹499'), findsOneWidget);
    expect(find.text('Plus · ₹249'), findsOneWidget);
    expect(find.text('Platinum · ₹899'), findsOneWidget);
    expect(find.textContaining('UTR 111122223333'), findsOneWidget);
    expect(find.text('Waiting for verification'), findsOneWidget);
    expect(find.text('Active — verified'), findsOneWidget);
    expect(find.text('Not verified'), findsOneWidget);
    expect(find.text('We couldn’t find this payment.'), findsOneWidget);
  });

  testWidgets('No payments, no section', (tester) async {
    phone(tester);
    await openMembershipScreen(tester, _SignedInStore()..settings = _upiOn);
    expect(find.text('Your UPI payments'), findsNothing);
  });
}
