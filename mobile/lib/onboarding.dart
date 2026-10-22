import 'dart:typed_data';

import 'package:flutter/material.dart';
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

/// First launch: welcome, profile basics, ten questions, then an invitation
/// to the compatibility quiz.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.store});
  final PreviewStore store;
  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  /// 0 welcome, 1 basics, 2 photo, 3..12 questions, 13 done.
  int step = 0;
  static const _firstQuestion = 3;
  int get _done => _firstQuestion + onboardingQuestions.length;

  void go(int next) => setState(() => step = next);

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
    final Widget body;
    if (step == 0) {
      body = _Welcome(onStart: () => go(1), onSkip: store.finishOnboarding);
    } else if (step == 1) {
      body = _Basics(store: store, onBack: () => go(0), onDone: () => go(2));
    } else if (step == 2) {
      body = _PhotoStep(store: store, onBack: () => go(1), onDone: () => go(3));
    } else if (step < _done) {
      final i = step - _firstQuestion;
      final q = onboardingQuestions[i];
      body = QuestionStep(
          key: ValueKey(q.id),
          question: q,
          number: i + 1,
          total: onboardingQuestions.length,
          initial: store.onboardingAnswers[q.id] ?? const [],
          onBack: () => go(step - 1),
          onAnswer: (values) {
            if (values.isEmpty) {
              store.onboardingAnswers.remove(q.id);
            } else {
              store.onboardingAnswers[q.id] = values;
            }
            go(step + 1);
          });
    } else {
      body = _AllSet(
          store: store, onQuiz: takeQuiz, onLater: store.finishOnboarding);
    }
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

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onStart, required this.onSkip});
  final VoidCallback onStart, onSkip;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
        const Spacer(),
        Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
                gradient: EverlaneColors.premiumGradient,
                shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Icon(Icons.favorite_rounded,
                color: Colors.white, size: 28)),
        const SizedBox(height: 20),
        ShaderMask(
            shaderCallback: (bounds) =>
                EverlaneColors.textGradient.createShader(bounds),
            child: Text('Everlane',
                style: EverlaneFonts.poppins(
                    size: 42,
                    weight: FontWeight.w700,
                    letterSpacing: -1.2,
                    color: Colors.white))),
        const SizedBox(height: 12),
        const Eyebrow('Less swiping. More meaningful connections.',
            color: EverlaneColors.like),
        const SizedBox(height: 18),
        Text(
            'A few thoughtful questions help us introduce you to people you’ll actually want to talk to. It takes about three minutes, and you can skip anything optional.',
            textAlign: TextAlign.center,
            style: TextStyle(color: EverlaneColors.muted, height: 1.6)),
        const Spacer(flex: 2),
        GradientButton(label: 'Get started', onTap: onStart),
        const SizedBox(height: 8),
        Center(
            child: TextButton(
                onPressed: onSkip,
                child: const Text('Skip to the app (preview)'))),
      ]));
}

class _Basics extends StatefulWidget {
  const _Basics(
      {required this.store, required this.onBack, required this.onDone});
  final PreviewStore store;
  final VoidCallback onBack, onDone;
  @override
  State<_Basics> createState() => _BasicsState();
}

class _BasicsState extends State<_Basics> {
  late final name = TextEditingController(text: widget.store.myName);
  late final city = TextEditingController(text: widget.store.myCity);
  late DateTime? birthday = widget.store.myBirthday;
  late String gender = widget.store.myGender;
  late String interested = widget.store.interestedIn;

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

  bool get ready =>
      name.text.trim().isNotEmpty &&
      (age ?? 0) >= 18 &&
      gender.isNotEmpty &&
      interested.isNotEmpty;

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

  void save() {
    final store = widget.store
      ..myName = name.text.trim()
      ..myCity = city.text.trim()
      ..myBirthday = birthday
      ..myGender = gender
      ..interestedIn = interested;
    store.update();
    widget.onDone();
  }

  Widget chips(List<String> options, String value, ValueChanged<String> pick) =>
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final o in options)
          ChoiceChip(
              label: Text(o),
              selected: value == o,
              showCheckmark: false,
              selectedColor: EverlaneColors.like,
              backgroundColor: EverlaneColors.card,
              side: BorderSide(
                  color:
                      value == o ? EverlaneColors.like : EverlaneColors.line),
              labelStyle: TextStyle(
                  color: value == o ? Colors.white : EverlaneColors.plum),
              onSelected: (_) => setState(() => pick(o))),
      ]);

  Widget why(String text) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(text,
          style: TextStyle(fontSize: 12, color: EverlaneColors.muted)));

  @override
  Widget build(BuildContext context) {
    final a = age;
    final b = birthday;
    return ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        children: [
          Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                  tooltip: 'Back',
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_rounded))),
          Text('The basics', style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text('Just enough to set up your profile.',
              style: TextStyle(color: EverlaneColors.muted)),
          const SizedBox(height: 24),
          TextField(
              controller: name,
              maxLength: 40,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'First name')),
          const SizedBox(height: 8),
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
          if (a != null && a < 18)
            Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Everlane is for adults aged 18 and over.',
                    style: TextStyle(fontSize: 12, color: EverlaneColors.like)))
          else
            why('Everlane is for adults. Only your age is shown, never your birthday.'),
          const SizedBox(height: 22),
          const Text('I am a', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          chips(['Woman', 'Man', 'Non-binary'], gender, (v) => gender = v),
          const SizedBox(height: 22),
          const Text('Interested in',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          chips(
              ['Women', 'Men', 'Everyone'], interested, (v) => interested = v),
          why('Used only to decide who you see and who sees you.'),
          const SizedBox(height: 22),
          TextField(
              controller: city,
              decoration: const InputDecoration(labelText: 'City or area')),
          why('We use your approximate area only. Others see “Nearby”, never your exact location.'),
          const SizedBox(height: 28),
          FilledButton(
              onPressed: ready ? save : null,
              style:
                  FilledButton.styleFrom(backgroundColor: EverlaneColors.like),
              child: const Text('Continue')),
        ]);
  }
}

/// At least one photo is required before moving on, same as a real dating
/// app's sign-up. More can be added later from Edit profile.
class _PhotoStep extends StatefulWidget {
  const _PhotoStep(
      {required this.store, required this.onBack, required this.onDone});
  final PreviewStore store;
  final VoidCallback onBack, onDone;
  @override
  State<_PhotoStep> createState() => _PhotoStepState();
}

class _PhotoStepState extends State<_PhotoStep> {
  bool picking = false;
  String? error;

  Future<void> pick() async {
    setState(() {
      picking = true;
      error = null;
    });
    try {
      final bytes = await pickPhotoBytes();
      if (bytes != null) widget.store.addPhoto(bytes);
    } catch (_) {
      error = 'Couldn’t open your photos. Try again.';
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        children: [
          Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                  tooltip: 'Previous question',
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_rounded))),
          Text('Add your photos',
              style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          Text(
              'At least one real photo helps people recognise you. Add more anytime from your profile.',
              style: TextStyle(color: EverlaneColors.muted, height: 1.5)),
          const SizedBox(height: 22),
          Wrap(spacing: 12, runSpacing: 12, children: [
            for (var i = 0; i < store.myPhotos.length; i++)
              _PhotoTile(
                  bytes: store.myPhotos[i],
                  onRemove: () => setState(() => store.removePhoto(i))),
            _AddPhotoTile(busy: picking, onTap: pick),
          ]),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!, style: TextStyle(color: EverlaneColors.like)),
          ],
          const SizedBox(height: 28),
          FilledButton(
              onPressed: store.hasPhoto ? widget.onDone : null,
              style: FilledButton.styleFrom(backgroundColor: EverlaneColors.like),
              child: const Text('Continue')),
          const SizedBox(height: 8),
          Center(
              child: Text(
                  store.hasPhoto
                      ? '${store.myPhotos.length} photo${store.myPhotos.length == 1 ? '' : 's'} added'
                      : 'Add at least one photo to continue',
                  style: TextStyle(fontSize: 12, color: EverlaneColors.muted))),
        ]);
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.bytes, required this.onRemove});
  final Uint8List bytes;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 100,
      height: 100,
      child: Stack(children: [
        ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(bytes,
                width: 100, height: 100, fit: BoxFit.cover,
                errorBuilder: (_, error, stack) => Container(
                    width: 100,
                    height: 100,
                    color: EverlaneColors.blush,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined,
                        color: EverlaneColors.like)))),
        Positioned(
            top: 4,
            right: 4,
            child: Material(
                color: Colors.black.withValues(alpha: .55),
                shape: const CircleBorder(),
                child: IconButton(
                    tooltip: 'Remove photo',
                    iconSize: 16,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    onPressed: onRemove,
                    icon: const Icon(Icons.close_rounded, color: Colors.white)))),
      ]));
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.busy, required this.onTap});
  final bool busy;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
      color: EverlaneColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: busy ? null : onTap,
          child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: EverlaneColors.line)),
              alignment: Alignment.center,
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.add_a_photo_outlined,
                          color: EverlaneColors.like),
                      const SizedBox(height: 6),
                      Text('Add photo',
                          style: TextStyle(
                              fontSize: 11, color: EverlaneColors.muted)),
                    ]))));
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
        item(true, 'First name and date of birth'),
        item(true, 'Gender and who you’re interested in'),
        item(store.myCity.isNotEmpty, 'Approximate area'),
        item(store.hasPhoto, 'At least one photo'),
        item(store.onboardingAnswers.isNotEmpty,
            'Dating intentions and preferences'),
        item(false, 'A bio and your interests · add from your profile'),
        item(false, 'Voice introduction · optional'),
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
