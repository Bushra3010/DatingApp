import 'package:flutter/material.dart';
import 'auth.dart';
import 'chemistry.dart';
import 'models.dart';
import 'photo_picker.dart';
import 'question_bank.dart';
import 'screens.dart' show openMembership;
import 'theme.dart';
import 'widgets.dart';

/// One question with single- or multi-select answers. Single-select advances
/// on tap; multi-select shows a Continue button.
class QuestionStep extends StatefulWidget {
  const QuestionStep(
      {super.key,
      required this.question,
      required this.number,
      required this.total,
      required this.initial,
      required this.onAnswer,
      required this.onBack});
  final Question question;
  final int number, total;
  final List<String> initial;

  /// An empty list means skipped.
  final ValueChanged<List<String>> onAnswer;
  final VoidCallback? onBack;
  @override
  State<QuestionStep> createState() => _QuestionStepState();
}

class _QuestionStepState extends State<QuestionStep> {
  late final picked = <String>[...widget.initial];

  Question get q => widget.question;

  void toggle(String value) {
    if (!q.multi) {
      widget.onAnswer([value]);
      return;
    }
    setState(() {
      if (picked.contains(value)) {
        picked.remove(value);
      } else if (q.exclusive.contains(value)) {
        picked
          ..clear()
          ..add(value);
      } else {
        picked.removeWhere(q.exclusive.contains);
        if (q.maxChoices == 0 || picked.length < q.maxChoices) {
          picked.add(value);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final limit = switch (q.maxChoices) {
      1 => null,
      0 => 'Choose any that apply',
      final n => 'Choose up to $n',
    };
    return ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        children: [
          Row(children: [
            if (widget.onBack != null)
              IconButton(
                  tooltip: 'Previous question',
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_rounded))
            else
              const SizedBox(height: 48),
            const Spacer(),
            if (q.optional)
              TextButton(
                  onPressed: () => widget.onAnswer(const []),
                  child: const Text('Skip')),
          ]),
          ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                  tween: Tween(end: (widget.number - 1) / widget.total),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 4,
                      color: EverlaneColors.like,
                      backgroundColor: EverlaneColors.line))),
          const SizedBox(height: 18),
          Text(
              [
                'Question ${widget.number} of ${widget.total}',
                if (q.section.isNotEmpty) q.section,
              ].join(' · '),
              style: TextStyle(fontSize: 12, color: EverlaneColors.muted)),
          const SizedBox(height: 10),
          Text(q.prompt, style: Theme.of(context).textTheme.headlineMedium),
          if (limit != null) ...[
            const SizedBox(height: 8),
            Text(limit,
                style: TextStyle(fontSize: 13, color: EverlaneColors.muted)),
          ],
          const SizedBox(height: 20),
          for (final (value, label) in q.options)
            Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _Option(
                    label: label,
                    selected: picked.contains(value),
                    multi: q.multi,
                    onTap: () => toggle(value))),
          if (q.multi) ...[
            const SizedBox(height: 10),
            FilledButton(
                onPressed: picked.isEmpty && !q.optional
                    ? null
                    : () => widget.onAnswer([...picked]),
                style: FilledButton.styleFrom(
                    backgroundColor: EverlaneColors.like),
                child: const Text('Continue')),
          ],
        ]);
  }
}

class _Option extends StatelessWidget {
  const _Option(
      {required this.label,
      required this.selected,
      required this.multi,
      required this.onTap});
  final String label;
  final bool selected, multi;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
      color: selected ? EverlaneColors.blush : EverlaneColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color:
                          selected ? EverlaneColors.like : EverlaneColors.line,
                      width: selected ? 1.5 : 1)),
              child: Row(children: [
                Expanded(
                    child: Text(label, style: const TextStyle(fontSize: 15))),
                if (multi)
                  Icon(
                      selected
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 20,
                      color: selected
                          ? EverlaneColors.like
                          : EverlaneColors.muted),
              ]))));
}

/// First launch: welcome, sign-up, a one-page profile, then an invitation
/// to the compatibility quiz.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.store});
  final PreviewStore store;
  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  /// 0 welcome, 1 the one-page profile, 2 all set. A member who is already
  /// signed in (back from Google, or a saved session) starts at the profile.
  late int step = widget.store.signedIn ? 1 : 0;

  void go(int next) => setState(() => step = next);

  /// Sign up or log in; a member who already finished their profile goes
  /// straight into the app, everyone else fills in the one-page profile.
  Future<void> account({required bool signUp}) async {
    final store = widget.store;
    final result = await showAuthSheet(context, store, signUp: signUp);
    if (result == null || !mounted) return;
    if (result == AuthResult.signedUp) store.saveProfile();
    if (!store.onboarded && mounted) go(1);
  }

  void takeQuiz() {
    Navigator.push(
        context,
        editorialRoute<void>(
            (_) => CompatibilityQuizScreen(store: widget.store)));
    widget.store.finishOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    if (step == 0) {
      // The welcome is full-bleed; the rest sit in a phone-width column.
      return _Welcome(
          onStart: store.backend == null || store.signedIn
              ? () => go(1)
              : () => account(signUp: true),
          onLogIn: store.backend == null || store.signedIn
              ? null
              : () => account(signUp: false),
          onSkip: store.finishOnboarding);
    }
    final body = step == 1
        ? _ProfileSetup(store: store, onBack: () => go(0), onDone: () => go(2))
        : _AllSet(
            store: store, onQuiz: takeQuiz, onLater: store.finishOnboarding);
    return Scaffold(
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 380),
                        switchInCurve: Curves.easeOutCubic,
                        transitionBuilder: (child, animation) => FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                                position: Tween(
                                        begin: const Offset(.06, 0),
                                        end: Offset.zero)
                                    .animate(animation),
                                child: child)),
                        child:
                            KeyedSubtree(key: ValueKey(step), child: body))))));
  }
}

/// First screen: a fanned stack of real-looking profile cards over soft
/// purple and pink light, the promise, and the way in.
class _Welcome extends StatelessWidget {
  const _Welcome(
      {required this.onStart, required this.onSkip, required this.onLogIn});
  final VoidCallback onStart, onSkip;

  /// Null when there's no account backend (tests, offline).
  final VoidCallback? onLogIn;

  Widget _card(Person p, double angle, double scale) => Transform.rotate(
      angle: angle,
      child: Transform.scale(
          scale: scale,
          child: DecoratedBox(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: .14), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: .45),
                        blurRadius: 30,
                        offset: const Offset(0, 16))
                  ]),
              child: Portrait(p, width: 168, height: 232, radius: 26))));

  Widget _chip(IconData icon, String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: EverlaneColors.card.withValues(alpha: .92),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: EverlaneColors.line),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: .35),
                blurRadius: 16,
                offset: const Offset(0, 6))
          ]),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
      ]));

  Widget _trust(IconData icon, String text) => Expanded(
          child: Column(children: [
        Icon(icon, size: 20, color: EverlaneColors.lavender),
        const SizedBox(height: 6),
        Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: EverlaneColors.muted)),
      ]));

  @override
  Widget build(BuildContext context) => Scaffold(
      body: Stack(children: [
        // Soft glows behind the cards.
        Positioned(
            top: -120,
            left: -80,
            child: _glow(EverlaneColors.gradientStart, 360)),
        Positioned(
            top: 40, right: -120, child: _glow(EverlaneColors.gradientEnd, 320)),
        SafeArea(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: LayoutBuilder(builder: (context, c) {
                      final tall = c.maxHeight > 700;
                      return Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                          child: Column(children: [
                            const SizedBox(height: 8),
                            ShaderMask(
                                shaderCallback: (b) =>
                                    EverlaneColors.textGradient.createShader(b),
                                child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10),
                                    child: Text('Everlane',
                                        style: EverlaneFonts.logo(
                                            size: 34, color: Colors.white)))),
                            Expanded(
                                child: FittedBox(
                                    child: SizedBox(
                                        width: 360,
                                        height: 330,
                                        child: Stack(
                                            alignment: Alignment.center,
                                            clipBehavior: Clip.none,
                                            children: [
                                              Positioned(
                                                  left: 0,
                                                  top: 40,
                                                  child: _card(
                                                      demoPeople[2], -.16, .9)),
                                              Positioned(
                                                  right: 0,
                                                  top: 40,
                                                  child: _card(
                                                      demoPeople[1], .16, .9)),
                                              _card(demoPeople[0], 0, 1),
                                              Positioned(
                                                  left: 6,
                                                  bottom: 18,
                                                  child: _chip(
                                                      Icons.verified_rounded,
                                                      'Verified profiles',
                                                      const Color(0xFF60A5FA))),
                                              Positioned(
                                                  right: 2,
                                                  top: 10,
                                                  child: _chip(
                                                      Icons.favorite_rounded,
                                                      'It’s a match!',
                                                      EverlaneColors.like)),
                                            ])))),
                            const Eyebrow(
                                'Less swiping. More meaningful connections.',
                                color: EverlaneColors.like,
                                textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            Text('Find someone worth\nstaying for.',
                                textAlign: TextAlign.center,
                                style: EverlaneFonts.playfair(
                                    size: tall ? 32 : 27,
                                    weight: FontWeight.w600,
                                    height: 1.15,
                                    color: EverlaneColors.plum)),
                            const SizedBox(height: 10),
                            Text(
                                'Real profiles, thoughtful matches and conversations that go somewhere.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: EverlaneColors.muted, height: 1.5)),
                            SizedBox(height: tall ? 20 : 14),
                            Row(children: [
                              _trust(Icons.verified_user_outlined,
                                  'Verified\nprofiles'),
                              _trust(Icons.lock_outline_rounded,
                                  'Private\nby design'),
                              _trust(Icons.favorite_border_rounded,
                                  'Made for\nsomething real'),
                            ]),
                            SizedBox(height: tall ? 22 : 14),
                            GradientButton(
                                label: 'Get started', onTap: onStart),
                            if (onLogIn != null) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                      onPressed: onLogIn,
                                      style: OutlinedButton.styleFrom(
                                          minimumSize: const Size(0, 52),
                                          side: BorderSide(
                                              color: EverlaneColors.deep
                                                  .withValues(alpha: .7))),
                                      child: const Text(
                                          'I already have an account'))),
                            ],
                            TextButton(
                                onPressed: onSkip,
                                child: const Text('Skip to the app (preview)')),
                          ]));
                    })))),
      ]));

  Widget _glow(Color color, double size) => IgnorePointer(
      child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                color.withValues(alpha: .35),
                color.withValues(alpha: 0),
              ]))));
}

/// Everything sign-up needs, on one page: name, date of birth, gender, who
/// you'd like to meet, height, languages, what you're looking for and at
/// least one photo.
class _ProfileSetup extends StatefulWidget {
  const _ProfileSetup(
      {required this.store, required this.onBack, required this.onDone});
  final PreviewStore store;
  final VoidCallback onBack, onDone;
  @override
  State<_ProfileSetup> createState() => _ProfileSetupState();
}

class _ProfileSetupState extends State<_ProfileSetup> {
  late final name = TextEditingController(text: widget.store.myName);
  late final city = TextEditingController(text: widget.store.myCity);
  late DateTime? birthday = widget.store.myBirthday;
  late String gender = widget.store.myGender;
  late String interested = widget.store.interestedIn;
  late double height = (widget.store.myHeightCm ?? 165).toDouble();
  late final languages = <String>{...widget.store.myLanguages};
  late String lookingFor = widget.store.myLookingFor;
  bool picking = false;
  String? photoError;

  static const _interestedLabels = {
    'Men': 'Men',
    'Women': 'Women',
    'Everyone': 'Something else',
  };

  @override
  void dispose() {
    name.dispose();
    city.dispose();
    super.dispose();
  }

  int? get age {
    final b = birthday;
    if (b == null) return null;
    final now = DateTime.now();
    final passed =
        now.month > b.month || (now.month == b.month && now.day >= b.day);
    return now.year - b.year - (passed ? 0 : 1);
  }

  /// What's still missing, in the order it appears on the page.
  List<String> get missing => [
        if (name.text.trim().isEmpty) 'your name',
        if ((age ?? 0) < 18) 'your date of birth',
        if (gender.isEmpty) 'your gender',
        if (interested.isEmpty) 'who you’d like to meet',
        if (lookingFor.isEmpty) 'what you’re looking for',
        if (!widget.store.hasPhoto) 'a photo',
      ];

  Future<void> pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
        context: context,
        initialDate: birthday ?? DateTime(now.year - 25, now.month, now.day),
        firstDate: DateTime(now.year - 100),
        lastDate: now,
        helpText: 'Date of birth');
    if (picked != null) setState(() => birthday = picked);
  }

  Future<void> pickPhoto() async {
    setState(() {
      picking = true;
      photoError = null;
    });
    try {
      final bytes = await pickPhotoBytes();
      if (bytes != null) widget.store.addPhoto(bytes);
    } catch (_) {
      photoError = 'Couldn’t open your photos. Try again.';
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  void save() {
    final store = widget.store
      ..myName = name.text.trim()
      ..myCity = city.text.trim()
      ..myBirthday = birthday
      ..myGender = gender
      ..interestedIn = interested
      ..myHeightCm = height.round()
      ..myLookingFor = lookingFor;
    store.myLanguages
      ..clear()
      ..addAll(languages);
    store.update();
    store.saveProfile();
    widget.onDone();
  }

  Widget heading(String text, {String? hint}) => Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700))),
        if (hint != null)
          Text(hint,
              style: TextStyle(fontSize: 12, color: EverlaneColors.muted)),
      ]));

  Widget choice(String label, bool selected, VoidCallback onTap) => ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: EverlaneColors.deep,
      backgroundColor: EverlaneColors.card,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      side: BorderSide(
          color: selected ? EverlaneColors.deep : EverlaneColors.line),
      labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : EverlaneColors.plum),
      onSelected: (_) => setState(onTap));

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final a = age;
    final b = birthday;
    final todo = missing;
    const required = 6;
    return ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 32), children: [
      Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
              tooltip: 'Back',
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_rounded))),
      Text('Create your profile',
          style: Theme.of(context).textTheme.headlineLarge),
      const SizedBox(height: 8),
      Text('Just the essentials — it takes about a minute.',
          style: TextStyle(color: EverlaneColors.muted)),
      const SizedBox(height: 14),
      ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
              tween: Tween(end: (required - todo.length) / required),
              duration: const Duration(milliseconds: 300),
              builder: (context, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 5,
                  color: EverlaneColors.like,
                  backgroundColor: EverlaneColors.line))),
      heading('What’s your name?'),
      TextField(
          controller: name,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
              labelText: 'First name', counterText: '')),
      heading('Your date of birth'),
      OutlinedButton.icon(
          onPressed: pickBirthday,
          icon: const Icon(Icons.cake_outlined),
          style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              alignment: Alignment.centerLeft,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16))),
          label: Text(b == null
              ? 'Date of birth'
              : '${b.day}/${b.month}/${b.year} · $a years old')),
      Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
              a != null && a < 18
                  ? 'Everlane is for adults aged 18 and over.'
                  : 'Only your age is shown, never your birthday.',
              style: TextStyle(
                  fontSize: 12,
                  color: a != null && a < 18
                      ? EverlaneColors.like
                      : EverlaneColors.muted))),
      heading('Your gender'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final g in ['Woman', 'Man', 'Non-binary'])
          choice(g, gender == g, () => gender = g),
      ]),
      heading('Looking for'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final MapEntry(key: value, value: label)
            in _interestedLabels.entries)
          choice(label, interested == value, () => interested = value),
      ]),
      heading('What’s your height?', hint: heightLabel(height.round())),
      SliderTheme(
          data: SliderTheme.of(context).copyWith(
              activeTrackColor: EverlaneColors.deep,
              thumbColor: Colors.white,
              inactiveTrackColor: EverlaneColors.line),
          child: Slider(
              value: height,
              min: 140,
              max: 210,
              divisions: 70,
              label: heightLabel(height.round()),
              onChanged: (v) => setState(() => height = v))),
      heading('Languages you speak', hint: 'Optional'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final l in PreviewStore.languageOptions)
          FilterChip(
              label: Text(l),
              selected: languages.contains(l),
              showCheckmark: false,
              selectedColor: EverlaneColors.deep,
              backgroundColor: EverlaneColors.card,
              side: BorderSide(
                  color: languages.contains(l)
                      ? EverlaneColors.deep
                      : EverlaneColors.line),
              labelStyle: TextStyle(
                  color: languages.contains(l)
                      ? Colors.white
                      : EverlaneColors.plum),
              onSelected: (on) =>
                  setState(() => on ? languages.add(l) : languages.remove(l))),
      ]),
      heading('What are you looking for?'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final o in PreviewStore.lookingForOptions)
          choice(o, lookingFor == o, () => lookingFor = o),
      ]),
      heading('Where are you based?', hint: 'Optional'),
      TextField(
          controller: city,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
              labelText: 'City or area',
              prefixIcon: Icon(Icons.location_on_outlined))),
      heading('Add your photos',
          hint: '${store.myPhotos.length}/${PreviewStore.maxPhotos} · at least 1'),
      Wrap(spacing: 12, runSpacing: 12, children: [
        for (var i = 0; i < store.myPhotos.length; i++)
          PhotoTile(
              bytes: store.myPhotos[i],
              isMain: i == 0,
              onSetMain: store.myPhotos.length > 1 && i != 0
                  ? () => setState(() => store.setMainPhoto(i))
                  : null,
              onRemove: () => setState(() => store.removePhoto(i))),
        if (store.canAddPhoto) AddPhotoTile(busy: picking, onTap: pickPhoto),
      ]),
      if (photoError != null)
        Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(photoError!,
                style: const TextStyle(color: EverlaneColors.like))),
      const SizedBox(height: 30),
      GradientButton(label: 'Continue', onTap: todo.isEmpty ? save : null),
      const SizedBox(height: 10),
      Text(
          todo.isEmpty
              ? 'Looking good — you can add a bio and interests later.'
              : 'Add ${todo.join(', ')} to continue.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: EverlaneColors.muted)),
    ]);
  }
}

class _AllSet extends StatelessWidget {
  const _AllSet(
      {required this.store, required this.onQuiz, required this.onLater});
  final PreviewStore store;
  final VoidCallback onQuiz, onLater;

  Widget item(bool done, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 20,
            color: done ? EverlaneColors.boost : EverlaneColors.muted),
        const SizedBox(width: 12),
        Expanded(
            child: Text(text,
                style: TextStyle(
                    color: done ? EverlaneColors.plum : EverlaneColors.muted))),
      ]));

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.fromLTRB(28, 40, 28, 32), children: [
        Text('You’re all set, ${store.myName}.',
            style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 10),
        Text('Your profile so far:',
            style: TextStyle(color: EverlaneColors.muted)),
        const SizedBox(height: 18),
        item(true, 'Name and date of birth'),
        item(true, 'Gender and who you’d like to meet'),
        item(store.myHeightCm != null, 'Height'),
        item(store.myLanguages.isNotEmpty, 'Languages · optional'),
        item(true, 'Looking for: ${store.myLookingFor}'),
        item(store.hasPhoto,
            '${store.myPhotos.length} photo${store.myPhotos.length == 1 ? '' : 's'}'),
        item(false, 'A bio and your interests · add from your profile'),
        const SizedBox(height: 24),
        Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: EverlaneColors.blush,
                borderRadius: BorderRadius.circular(20)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Go a little deeper',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                  'The Everlane Compatibility Quiz has 24 questions and takes about five minutes. It powers your Chemistry with each person.',
                  style: TextStyle(color: EverlaneColors.muted, height: 1.5)),
            ])),
        const SizedBox(height: 22),
        FilledButton(
            onPressed: onQuiz,
            style: FilledButton.styleFrom(backgroundColor: EverlaneColors.like),
            child: const Text('Take the compatibility quiz')),
        const SizedBox(height: 8),
        Center(
            child: TextButton(
                onPressed: onLater, child: const Text('Maybe later'))),
      ]);
}

class CompatibilityQuizScreen extends StatefulWidget {
  const CompatibilityQuizScreen({super.key, required this.store});
  final PreviewStore store;
  @override
  State<CompatibilityQuizScreen> createState() =>
      _CompatibilityQuizScreenState();
}

class _CompatibilityQuizScreenState extends State<CompatibilityQuizScreen> {
  /// Starts at the first unanswered question; past the end is the summary.
  late int index = _firstUnanswered();

  int _firstUnanswered() {
    final i = compatibilityQuestions
        .indexWhere((q) => !widget.store.quizAnswers.containsKey(q.id));
    return i < 0 ? compatibilityQuestions.length : i;
  }

  Future<void> deleteAnswers() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Delete your quiz answers?'),
                content: const Text(
                    'Your Chemistry with everyone will be removed. You can take the quiz again anytime.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete')),
                ]));
    if (confirmed != true || !mounted) return;
    widget.store.deleteQuizAnswers();
    setState(() => index = 0);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final total = compatibilityQuestions.length;
    return Scaffold(
        appBar: AppBar(
            title: const Text('Compatibility quiz',
                style: TextStyle(fontSize: 17))),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: index >= total
                    ? _summary(context, store, total)
                    : QuestionStep(
                        key: ValueKey(compatibilityQuestions[index].id),
                        question: compatibilityQuestions[index],
                        number: index + 1,
                        total: total,
                        initial: store.quizAnswers[
                                compatibilityQuestions[index].id] ??
                            const [],
                        onBack:
                            index == 0 ? null : () => setState(() => index--),
                        onAnswer: (values) {
                          store.answerQuiz(
                              compatibilityQuestions[index].id, values);
                          setState(() => index++);
                        }))));
  }

  Widget _summary(BuildContext context, PreviewStore store, int total) =>
      ListView(padding: const EdgeInsets.fromLTRB(24, 12, 24, 32), children: [
        Text(
            store.quizAnswered >= Chemistry.minAnswers
                ? 'Thank you.'
                : 'Saved for now.',
            style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 10),
        Text('You answered ${store.quizAnswered} of $total questions.',
            style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 6),
        if (store.quizAnswered < Chemistry.minAnswers)
          Text(
              'Answer at least ${Chemistry.minAnswers} for a full Chemistry score. Until then you’ll see a preliminary view.',
              style: TextStyle(color: EverlaneColors.muted, height: 1.5)),
        const SizedBox(height: 22),
        Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: EverlaneColors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: EverlaneColors.line)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.lock_outline_rounded,
                  size: 20, color: EverlaneColors.boost),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(
                      'Your answers are private. People only see what you have in common and the topics you see differently, never your individual answers.',
                      style:
                          TextStyle(color: EverlaneColors.muted, height: 1.5))),
            ])),
        const SizedBox(height: 24),
        FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(backgroundColor: EverlaneColors.like),
            child: const Text('Done')),
        const SizedBox(height: 10),
        OutlinedButton(
            onPressed: () => setState(() => index = 0),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16))),
            child: const Text('Review my answers')),
        if (store.quizAnswers.isNotEmpty)
          Center(
              child: TextButton(
                  onPressed: deleteAnswers,
                  child: Text('Delete my answers',
                      style: TextStyle(color: EverlaneColors.muted)))),
      ]);
}

/// Profile card showing quiz progress.
class QuizCard extends StatelessWidget {
  const QuizCard({super.key, required this.store});
  final PreviewStore store;
  @override
  Widget build(BuildContext context) {
    final total = compatibilityQuestions.length;
    return Material(
        color: EverlaneColors.card,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.push(
                context,
                editorialRoute<void>(
                    (_) => CompatibilityQuizScreen(store: store))),
            child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: EverlaneColors.line)),
                child: Row(children: [
                  SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                          value: store.quizAnswered / total,
                          strokeWidth: 4,
                          color: EverlaneColors.like,
                          backgroundColor: EverlaneColors.line)),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text('Compatibility quiz',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text('${store.quizAnswered} of $total answered',
                            style: TextStyle(
                                fontSize: 12, color: EverlaneColors.muted)),
                      ])),
                  Icon(Icons.chevron_right_rounded,
                      color: EverlaneColors.muted),
                ]))));
  }
}

/// Chemistry on a profile: the main reasons behind it, never a promise.
class ChemistryCard extends StatelessWidget {
  const ChemistryCard({super.key, required this.store, required this.person});
  final PreviewStore store;
  final Person person;

  void openQuiz(BuildContext context) => Navigator.push(context,
      editorialRoute<void>((_) => CompatibilityQuizScreen(store: store)));

  @override
  Widget build(BuildContext context) {
    final c = store.chemistryWith(person);
    final heading = Row(children: [
      const Icon(Icons.auto_awesome_rounded,
          size: 18, color: EverlaneColors.like),
      const SizedBox(width: 8),
      const Expanded(
          child: Text('Chemistry',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
      const SizedBox(width: 8),
      if (c != null)
        Text(
            c.filteredBy != null
                ? 'Not a match'
                : c.score == null
                    ? 'Preliminary'
                    : '${c.score}%',
            style: TextStyle(
                fontSize: c.score == null ? 14 : 22,
                fontWeight: FontWeight.w700,
                color: c.score == null
                    ? EverlaneColors.muted
                    : EverlaneColors.like)),
    ]);
    final children = <Widget>[heading, const SizedBox(height: 12)];
    if (c == null) {
      children.addAll([
        Text(
            'Take the compatibility quiz to see what you and ${person.name} share, and where you differ.',
            style: TextStyle(color: EverlaneColors.muted, height: 1.5)),
        const SizedBox(height: 14),
        OutlinedButton(
            onPressed: () => openQuiz(context),
            child: const Text('Take the quiz')),
      ]);
    } else if (c.filteredBy != null) {
      children.add(Text(
          '${c.filteredBy} One of you marked shared intentions as a dealbreaker, so we won’t score this match.',
          style: TextStyle(color: EverlaneColors.muted, height: 1.5)));
    } else {
      if (c.intentMismatch) {
        children.add(_note(Icons.info_outline_rounded,
            'You’re looking for different things. Worth talking about early.'));
      }
      if (c.preliminary) {
        children.add(_note(Icons.hourglass_empty_rounded,
            'A preliminary view. Answer at least ${Chemistry.minAnswers} questions for a full picture.'));
      }
      if (c.shared.isNotEmpty) {
        children.addAll([
          const SizedBox(height: 4),
          const Eyebrow('What you share'),
          const SizedBox(height: 8),
          for (final (topic, label) in c.shared.take(3))
            Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text.rich(TextSpan(children: [
                  TextSpan(
                      text: '$topic · ',
                      style: TextStyle(color: EverlaneColors.muted)),
                  TextSpan(text: label),
                ]))),
        ]);
      }
      if (c.differences.isNotEmpty && !store.fullerChemistry) {
        children.add(Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
                onPressed: () => openMembership(context, store),
                icon: const Icon(Icons.lock_outline_rounded, size: 16),
                label: const Text('See where you differ with Plus'))));
      }
      if (c.differences.isNotEmpty && store.fullerChemistry) {
        children.addAll([
          const SizedBox(height: 10),
          const Eyebrow('Worth talking about'),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final topic in c.differences.take(3))
              Tag(Icons.forum_outlined, topic)
          ]),
        ]);
      }
      if (store.detailedChemistry && !c.preliminary && c.areas.isNotEmpty) {
        children.addAll([
          const SizedBox(height: 14),
          const Eyebrow('Area by area'),
          const SizedBox(height: 10),
          for (final MapEntry(key: area, value: percent) in c.areas.entries)
            Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(area.label,
                                style: const TextStyle(fontSize: 13))),
                        Text('$percent%',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 4),
                      ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                              value: percent / 100,
                              minHeight: 5,
                              color: EverlaneColors.like,
                              backgroundColor: EverlaneColors.line)),
                    ])),
        ]);
      }
      if (c.preliminary) {
        children.addAll([
          const SizedBox(height: 12),
          OutlinedButton(
              onPressed: () => openQuiz(context),
              child: const Text('Continue the quiz')),
        ]);
      }
    }
    children.addAll([
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
            child: Text('A conversation starter, not a prediction.',
                style: TextStyle(fontSize: 11, color: EverlaneColors.muted))),
        TextButton(
            onPressed: () => _explain(context),
            child: const Text('How it works', style: TextStyle(fontSize: 12))),
      ]),
    ]);
    return Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
        decoration: BoxDecoration(
            color: EverlaneColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: EverlaneColors.line)),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children));
  }

  Widget _note(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: EverlaneColors.star),
        const SizedBox(width: 8),
        Expanded(
            child:
                Text(text, style: const TextStyle(fontSize: 13, height: 1.4))),
      ]));

  void _explain(BuildContext context) => showEverlaneSheet(
      context,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('How Chemistry works',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 14),
        Text(
            'We compare the quiz answers you both gave. Each area counts for a share of the score:',
            style: TextStyle(color: EverlaneColors.muted, height: 1.5)),
        const SizedBox(height: 12),
        for (final d in Dimension.values)
          Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Expanded(child: Text(d.label)),
                Text('${d.weight}%',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ])),
        const SizedBox(height: 12),
        Text(
            'Dealbreakers are checked first. Wanting different things is never hidden by a high score. With too few answers you’ll see a preliminary view instead of a number. These weights are a starting point we keep testing; Chemistry helps you start a conversation, it can’t predict a relationship.',
            style: TextStyle(color: EverlaneColors.muted, height: 1.5)),
        const SizedBox(height: 12),
      ]));
}
