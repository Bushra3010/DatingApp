import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

enum AuthResult { signedUp, loggedIn }

/// Phone (SMS code) sign-in is hidden for now; set to true to bring it back.
const phoneSignIn = false;

/// Sign up or log in with Google, a phone number (SMS code) or email.
/// Logging in loads the member's saved profile before the sheet closes.
Future<AuthResult?> showAuthSheet(BuildContext context, PreviewStore store,
        {required bool signUp}) =>
    showEverlaneSheet<AuthResult>(
        context, _AuthFlow(store: store, signUp: signUp));

enum _Step { options, phone, code, email }

class _AuthFlow extends StatefulWidget {
  const _AuthFlow({required this.store, required this.signUp});
  final PreviewStore store;
  final bool signUp;
  @override
  State<_AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<_AuthFlow> {
  late bool signUp = widget.signUp;
  var step = _Step.options;
  final phone = TextEditingController();
  final code = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false, hidden = true;
  String? error;

  @override
  void dispose() {
    phone.dispose();
    code.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  String get e164 => '+91${phone.text.replaceAll(RegExp(r'\D'), '')}';

  void go(_Step next) => setState(() {
        step = next;
        error = null;
      });

  /// Runs an auth call with a busy state and a readable error.
  Future<void> run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } on AuthException catch (err) {
      if (mounted) setState(() => error = _friendly(err.message));
    } catch (_) {
      if (mounted) {
        setState(() => error =
            'Something went wrong. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  static String _friendly(String message) {
    final m = message.toLowerCase();
    if (m.contains('provider is not enabled') ||
        m.contains('unsupported provider') ||
        m.contains('phone provider') ||
        m.contains('sms')) {
      return 'This sign-in option isn’t switched on yet. Please use email for now.';    }
    return message;
  }

  /// Signed in: a returning member's profile is loaded; a new one starts
  /// blank.
  Future<void> done() async {
    final store = widget.store;
    final existing = await store.loadProfile();
    if (!mounted) return;
    Navigator.pop(context,
        existing || store.myName.isNotEmpty ? AuthResult.loggedIn : AuthResult.signedUp);
  }

  ProfileBackendCalls get b => ProfileBackendCalls(widget.store);

  @override
  Widget build(BuildContext context) => AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: switch (step) {
        _Step.options => _options(context),
        _Step.phone => _phone(context),
        _Step.code => _code(context),
        _Step.email => _email(context),
      });

  Widget _title(String title, String subtitle) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(subtitle,
                style: TextStyle(color: EverlaneColors.muted, height: 1.5)),
            const SizedBox(height: 22),
          ]);

  Widget _error() => error == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(error!,
              style: const TextStyle(color: EverlaneColors.like, height: 1.4)));

  Widget _back() => Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
          onPressed: busy ? null : () => go(_Step.options),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Other ways to continue')));

  Widget _options(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _title(signUp ? 'Create your account' : 'Welcome back',
            'Pick how you’d like to continue. Your profile and photos are saved to your account.'),
        _ProviderButton(
            label: 'Continue with Google',
            leading: const _GoogleMark(),
            light: true,
            onTap: busy ? null : () => run(b.google)),
        if (phoneSignIn) ...[
          const SizedBox(height: 12),
          _ProviderButton(
              label: 'Continue with phone number',
              leading: const Icon(Icons.phone_iphone_rounded,
                  color: Colors.white, size: 22),
              onTap: busy ? null : () => go(_Step.phone)),
        ],
        _error(),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: Divider(color: EverlaneColors.line)),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('or',
                  style: TextStyle(fontSize: 12, color: EverlaneColors.muted))),
          Expanded(child: Divider(color: EverlaneColors.line)),
        ]),
        const SizedBox(height: 6),
        TextButton.icon(
            onPressed: busy ? null : () => go(_Step.email),
            icon: const Icon(Icons.mail_outline_rounded, size: 18),
            label: const Text('Use email instead')),
        const SizedBox(height: 6),
        Text(
            'By continuing you agree to treat everyone with kindness and respect.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: EverlaneColors.muted)),
      ]);

  Widget _phone(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _back(),
        _title('Your phone number',
            'We’ll text you a 6-digit code. Your number is never shown on your profile.'),
        TextField(
            controller: phone,
            autofocus: true,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumberNational],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10)
            ],
            decoration: const InputDecoration(
                labelText: 'Mobile number',
                prefixText: '+91  ',
                prefixIcon: Icon(Icons.phone_iphone_rounded))),
        _error(),
        const SizedBox(height: 20),
        GradientButton(
            label: busy ? 'Sending…' : 'Send code',
            onTap: busy
                ? null
                : () {
                    if (phone.text.length != 10) {
                      setState(() =>
                          error = 'Enter your 10-digit mobile number.');
                      return;
                    }
                    run(() async {
                      await b.sendCode(e164);
                      if (mounted) go(_Step.code);
                    });
                  }),
      ]);

  Widget _code(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
                onPressed: busy ? null : () => go(_Step.phone),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Change number'))),
        _title('Enter the code', 'Sent to $e164.'),
        TextField(
            controller: code,
            autofocus: true,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 10),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6)
            ],
            decoration: const InputDecoration(hintText: '••••••')),
        _error(),
        const SizedBox(height: 20),
        GradientButton(
            label: busy ? 'Checking…' : 'Verify',
            onTap: busy
                ? null
                : () {
                    if (code.text.length != 6) {
                      setState(() => error = 'Enter the 6-digit code.');
                      return;
                    }
                    run(() async {
                      await b.verifyCode(e164, code.text);
                      await done();
                    });
                  }),
        TextButton(
            onPressed: busy ? null : () => run(() => b.sendCode(e164)),
            child: const Text('Send a new code')),
      ]);

  Widget _email(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _back(),
        _title(signUp ? 'Sign up with email' : 'Log in with email',
            signUp
                ? 'Use at least 6 characters for your password.'
                : 'Pick up where you left off.'),
        TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline_rounded))),
        const SizedBox(height: 12),
        TextField(
            controller: password,
            obscureText: hidden,
            autofillHints: [
              signUp ? AutofillHints.newPassword : AutofillHints.password
            ],
            decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                    tooltip: hidden ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => hidden = !hidden),
                    icon: Icon(hidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined)))),
        _error(),
        const SizedBox(height: 20),
        GradientButton(
            label: busy
                ? 'Please wait…'
                : signUp
                    ? 'Create account'
                    : 'Log in',
            onTap: busy
                ? null
                : () {
                    final e = email.text.trim();
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) {
                      setState(() => error = 'Enter a valid email address.');
                      return;
                    }
                    if (password.text.length < 6) {
                      setState(() => error =
                          'Use at least 6 characters for your password.');
                      return;
                    }
                    run(() async {
                      if (signUp) {
                        await b.emailSignUp(e, password.text);
                      } else {
                        await b.emailLogIn(e, password.text);
                      }
                      await done();
                    });
                  }),
        TextButton(
            onPressed: busy ? null : () => setState(() => signUp = !signUp),
            child: Text(signUp
                ? 'Already have an account? Log in'
                : 'New here? Create an account')),
      ]);
}

/// The store's backend calls used by the auth sheet.
class ProfileBackendCalls {
  ProfileBackendCalls(this.store);
  final PreviewStore store;
  Future<void> google() => store.backend!.continueWithGoogle();
  Future<void> sendCode(String phone) => store.backend!.sendPhoneCode(phone);
  Future<void> verifyCode(String phone, String code) =>
      store.backend!.verifyPhoneCode(phone, code);
  Future<void> emailSignUp(String e, String p) => store.backend!.signUp(e, p);
  Future<void> emailLogIn(String e, String p) => store.backend!.logIn(e, p);
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton(
      {required this.label,
      required this.leading,
      required this.onTap,
      this.light = false});
  final String label;
  final Widget leading;
  final VoidCallback? onTap;
  final bool light;
  @override
  Widget build(BuildContext context) => Opacity(
      opacity: onTap == null ? .5 : 1,
      child: Material(
          color: light ? Colors.white : EverlaneColors.card,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: light
                  ? BorderSide.none
                  : BorderSide(color: EverlaneColors.line)),
          child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: SizedBox(
                  height: 56,
                  child: Row(children: [
                    const SizedBox(width: 18),
                    SizedBox(width: 24, child: Center(child: leading)),
                    Expanded(
                        child: Text(label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: light
                                    ? const Color(0xFF1F1F1F)
                                    : Colors.white))),
                    const SizedBox(width: 42),
                  ])))));
}

/// A simple four-colour "G" mark, drawn in text so no image asset is needed.
class _GoogleMark extends StatelessWidget {
  const _GoogleMark();
  @override
  Widget build(BuildContext context) => ShaderMask(
      shaderCallback: (bounds) => const SweepGradient(colors: [
            Color(0xFFEA4335),
            Color(0xFFFBBC05),
            Color(0xFF34A853),
            Color(0xFF4285F4),
            Color(0xFFEA4335),
          ]).createShader(bounds),
      child: const Text('G',
          style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)));
}
