import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

enum AuthResult { signedUp, loggedIn }

/// Email + password sign-up or log-in. Logging in also loads the member's
/// saved profile before the sheet closes.
Future<AuthResult?> showAuthSheet(BuildContext context, PreviewStore store,
        {required bool signUp}) =>
    showEverlaneSheet<AuthResult>(
        context, _AuthForm(store: store, signUp: signUp));

class _AuthForm extends StatefulWidget {
  const _AuthForm({required this.store, required this.signUp});
  final PreviewStore store;
  final bool signUp;
  @override
  State<_AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<_AuthForm> {
  late bool signUp = widget.signUp;
  final email = TextEditingController();
  final password = TextEditingController();
  bool busy = false, hidden = true;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final e = email.text.trim(), p = password.text;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) {
      setState(() => error = 'Enter a valid email address.');
      return;
    }
    if (p.length < 6) {
      setState(() => error = 'Use at least 6 characters for your password.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    final backend = widget.store.backend!;
    try {
      if (signUp) {
        await backend.signUp(e, p);
      } else {
        await backend.logIn(e, p);
        await widget.store.loadProfile();
      }
      if (mounted) {
        Navigator.pop(
            context, signUp ? AuthResult.signedUp : AuthResult.loggedIn);
      }
    } on AuthException catch (err) {
      if (mounted) setState(() => error = err.message);
    } catch (_) {
      if (mounted) {
        setState(() => error =
            'Something went wrong. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(signUp ? 'Create your account' : 'Welcome back',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
            signUp
                ? 'Your profile and photos are saved to your account.'
                : 'Log in to pick up where you left off.',
            style: TextStyle(color: EverlaneColors.muted, height: 1.5)),
        const SizedBox(height: 22),
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
            onSubmitted: (_) => busy ? null : submit(),
            decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                    tooltip: hidden ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => hidden = !hidden),
                    icon: Icon(hidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined)))),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!,
              style: const TextStyle(color: EverlaneColors.like, height: 1.4)),
        ],
        const SizedBox(height: 22),
        GradientButton(
            label: busy
                ? 'Please wait…'
                : signUp
                    ? 'Create account'
                    : 'Log in',
            onTap: busy ? null : submit),
        const SizedBox(height: 8),
        Center(
            child: TextButton(
                onPressed: busy
                    ? null
                    : () => setState(() {
                          signUp = !signUp;
                          error = null;
                        }),
                child: Text(signUp
                    ? 'Already have an account? Log in'
                    : 'New here? Create an account'))),
      ]);
}
