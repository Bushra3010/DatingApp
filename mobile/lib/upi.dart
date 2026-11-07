// Paying for a plan by UPI: the member pays the team's UPI ID from any UPI
// app, then sends the reference (UTR) so an admin can verify it. The plan
// only turns on once a payment is approved (see `submit_upi_payment()`).

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'admin.dart';
import 'backend.dart' show errorMessage;
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

/// Letters and digits, 6–35 long, as UPI apps show the reference.
final _utrPattern = RegExp(r'^[A-Za-z0-9]{6,35}$');

bool validUtr(String utr) => _utrPattern.hasMatch(utr.trim());

/// The `upi://pay` link UPI apps open with everything filled in.
Uri upiPayUri(UpiSettings upi, Plan plan) {
  String enc(String v) => Uri.encodeComponent(v).replaceAll('%40', '@');
  return Uri.parse('upi://pay?pa=${enc(upi.vpa)}&pn=${enc(upi.payee)}'
      '&am=${formatAmount(planAmount(plan))}&cu=INR'
      '&tn=${enc('Everlane ${plan.title}')}');
}

/// Opens the "Pay with UPI" sheet for [plan]; on a successful submission,
/// says what happens next. Never switches the plan itself.
Future<void> payWithUpi(
    BuildContext context, PreviewStore store, Plan plan) async {
  final sent = await showEverlaneSheet<bool>(
      context, UpiPaySheet(store: store, plan: plan));
  if (sent == true && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          duration: const Duration(seconds: 6),
          content: Text(
              'Thanks! We’ll verify your payment and turn on ${plan.title}, usually within a few hours.')));
  }
}

class UpiPaySheet extends StatefulWidget {
  const UpiPaySheet({super.key, required this.store, required this.plan});
  final PreviewStore store;
  final Plan plan;
  @override
  State<UpiPaySheet> createState() => _UpiPaySheetState();
}

class _UpiPaySheetState extends State<UpiPaySheet> {
  final utr = TextEditingController();
  final note = TextEditingController();
  bool busy = false, copied = false;
  String? error;

  /// Shown when no UPI app could be opened (web, desktop, none installed).
  String? openHint;

  UpiSettings get upi => widget.store.settings.upi;
  Plan get plan => widget.plan;
  String get price => '₹${formatAmount(planAmount(plan))}';

  @override
  void dispose() {
    utr.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> copy() async {
    await Clipboard.setData(ClipboardData(text: upi.vpa));
    if (mounted) setState(() => copied = true);
  }

  /// On a phone (the app, or the website in a phone's browser) the
  /// `upi://pay` link opens GPay, PhonePe, Paytm or any UPI app with the
  /// amount filled in. On a computer, scan the QR code with your phone.
  bool get onPhone =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> openUpiApp() async {
    var opened = false;
    if (onPhone) {
      try {
        opened = await launchUrl(upiPayUri(upi, plan),
            mode: LaunchMode.externalApplication,
            // In a phone's browser, hand the link to the system so it can
            // offer the installed UPI apps (a new tab would be blocked).
            webOnlyWindowName: '_self');
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => openHint = !onPhone
        ? 'On a computer? Scan the QR code below with any UPI app on your phone.'
        : opened && !kIsWeb
            ? null
            : 'If no UPI app opened, scan the QR code or pay ${upi.vpa} from your UPI app.');
  }

  Future<void> submit() async {
    if (!validUtr(utr.text) || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.submitUpiPayment(plan, utr.text, note: note.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        busy = false;
        error = errorMessage(e,
            'Couldn’t submit your payment. Check your connection and try again.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(color: EverlaneColors.muted, height: 1.5);
    final typed = utr.text.trim();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Pay with UPI', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 6),
      Text.rich(TextSpan(children: [
        TextSpan(
            text: '${plan.title}  ',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        TextSpan(
            text: plan.displayPrice,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: EverlaneColors.star)),
        TextSpan(
            text: '  per month',
            style: TextStyle(fontSize: 13, color: EverlaneColors.muted)),
      ])),
      const SizedBox(height: 18),
      Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          decoration: BoxDecoration(
              color: EverlaneColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: EverlaneColors.line)),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Eyebrow('UPI ID'),
                  const SizedBox(height: 4),
                  SelectableText(upi.vpa,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('Payee: ${upi.payee}',
                      style:
                          TextStyle(fontSize: 12, color: EverlaneColors.muted)),
                ])),
            TextButton.icon(
                onPressed: copy,
                icon: Icon(copied ? Icons.check_rounded : Icons.copy_rounded,
                    size: 18),
                label: Text(copied ? 'Copied' : 'Copy')),
          ])),
      const SizedBox(height: 16),
      GradientButton(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Pay $price with a UPI app',
          onTap: openUpiApp),
      if (openHint != null) ...[
        const SizedBox(height: 8),
        Text(openHint!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: EverlaneColors.muted)),
      ],
      const SizedBox(height: 16),
      // Scan with any UPI app; the amount and note come pre-filled.
      Center(
          child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: QrImageView(
                  data: upiPayUri(upi, plan).toString(),
                  size: 180,
                  backgroundColor: Colors.white,
                  semanticsLabel: 'UPI QR code to pay $price'))),
      const SizedBox(height: 6),
      Center(
          child: Text('Scan with any UPI app to pay $price',
              style: muted.copyWith(fontSize: 12))),
      if (upi.note.isNotEmpty) ...[
        const SizedBox(height: 14),
        Text(upi.note, style: muted.copyWith(fontSize: 13)),
      ],
      const SizedBox(height: 22),
      Text('After paying', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 6),
      Text(
          'Enter the reference from your payment app. We check every payment and turn on ${plan.title} once it’s verified.',
          style: muted.copyWith(fontSize: 13)),
      const SizedBox(height: 12),
      TextField(
          controller: utr,
          enabled: !busy,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
            LengthLimitingTextInputFormatter(35),
          ],
          onChanged: (_) => setState(() => error = null),
          decoration: InputDecoration(
              labelText: 'UPI reference (UTR)',
              // Keeps the hint visible before the field is focused.
              floatingLabelBehavior: FloatingLabelBehavior.always,
              hintText: '12-digit number from your payment app',
              errorText: typed.isEmpty || validUtr(typed)
                  ? null
                  : 'Use the 6–35 letters or digits shown in your payment app')),
      const SizedBox(height: 12),
      TextField(
          controller: note,
          enabled: !busy,
          maxLength: 200,
          decoration: const InputDecoration(
              labelText: 'Note (optional)', counterText: '')),
      if (error != null) ...[
        const SizedBox(height: 8),
        Text(error!,
            style: const TextStyle(color: EverlaneColors.like, fontSize: 13)),
      ],
      const SizedBox(height: 16),
      FilledButton(
          onPressed: busy || !validUtr(typed) ? null : submit,
          child: Text(
              busy ? 'Submitting…' : 'I’ve paid — submit for verification')),
      const SizedBox(height: 8),
      Text('Your plan stays the same until we’ve verified the payment.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: EverlaneColors.muted)),
    ]);
  }
}

/// "Your UPI payments" on the Membership screen; nothing when there are none.
class UpiPaymentsSection extends StatelessWidget {
  const UpiPaymentsSection({super.key, required this.payments});
  final List<UpiPayment> payments;

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) return const SizedBox.shrink();
    return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Your UPI payments',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          for (final p in payments) _PaymentTile(payment: p),
        ]));
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment});
  final UpiPayment payment;

  @override
  Widget build(BuildContext context) {
    final p = payment;
    final (label, color) = p.approved
        ? ('Active — verified', EverlaneColors.boost)
        : p.rejected
            ? ('Not verified', EverlaneColors.like)
            : ('Waiting for verification', EverlaneColors.star);
    return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: EverlaneColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: EverlaneColors.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text('${p.planTitle} · ${p.amountLabel}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700))),
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color))),
          ]),
          const SizedBox(height: 6),
          Text(
              [
                'UTR ${p.utr}',
                shortDate(p.createdAt),
              ].where((x) => x.isNotEmpty).join(' · '),
              style: TextStyle(fontSize: 12, color: EverlaneColors.muted)),
          if (p.rejected && p.reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(p.reason,
                style: TextStyle(fontSize: 13, color: EverlaneColors.body)),
          ],
        ]));
  }
}
