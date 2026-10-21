import 'package:flutter/material.dart';
import 'models.dart';
import 'screens.dart';
import 'theme.dart';
import 'widgets.dart';

class _Question {
  const _Question(this.text, this.options);
  final String text;
  final List<String> options;
}

const _questions = [
  _Question('What are you looking for?', [
    'A lasting partnership',
    'A meaningful connection, in no rush',
    'Good company for events and travel',
    'Something open, to see where it goes',
  ]),
  _Question('What does a great first date look like?', [
    'Coffee and a long walk',
    'Dinner somewhere new',
    'An activity, like a class or a game',
    'Drinks and live music',
  ]),
  _Question('How do you like a relationship to move?', [
    'Slowly and deliberately',
    'Steadily, with clear intent',
    'Spontaneously',
  ]),
  _Question('What matters most in a partner?', [
    'Kindness',
    'Ambition',
    'Humour',
    'Curiosity',
  ]),
  _Question('How do you spend a free weekend?', [
    'Out exploring the city',
    'Cosy at home',
    'With friends and family',
    'Travelling somewhere new',
  ]),
];

/// The first answer decides what kind of person to introduce.
const _intentFor = [
  LookingFor.longTerm,
  LookingFor.coffeeDate,
  LookingFor.travelBuddy,
  LookingFor.shortTerm,
];

class IntroductionBanner extends StatelessWidget {
  const IntroductionBanner({super.key, required this.store});
  final PreviewStore store;
  @override
  Widget build(BuildContext context) => Material(
      color: EverlaneColors.card,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => Navigator.push(
              context,
              editorialRoute<void>(
                  (_) => IntroductionQuizScreen(store: store))),
          child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: EverlaneColors.line)),
              child: Row(children: [
                Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                        color: EverlaneColors.like,
                        borderRadius: BorderRadius.circular(15)),
                    child: const Icon(Icons.auto_awesome_rounded,
                        color: Colors.white, size: 24)),
                const SizedBox(width: 16),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('Find an introduction',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Answer five short questions.',
                          style: TextStyle(
                              fontSize: 12, color: EverlaneColors.muted)),
                    ])),
                Icon(Icons.chevron_right_rounded, color: EverlaneColors.muted),
              ]))));
}

class IntroductionQuizScreen extends StatefulWidget {
  const IntroductionQuizScreen({super.key, required this.store});
  final PreviewStore store;
  @override
  State<IntroductionQuizScreen> createState() => _IntroductionQuizScreenState();
}

class _IntroductionQuizScreenState extends State<IntroductionQuizScreen> {
  final answers = <int>[];
  bool finding = false;

  /// Index into [matches] of the person being shown.
  int shown = 0;

  bool get done => answers.length == _questions.length;

  /// People who share the chosen intent first, then everyone else not
  /// passed on or hidden.
  List<Person> get matches {
    final intent = _intentFor[answers.first];
    final people = demoPeople
        .where((p) => !widget.store.passed.contains(p.id))
        .toList()
      ..sort((a, b) => (b.lookingFor.contains(intent) ? 1 : 0)
          .compareTo(a.lookingFor.contains(intent) ? 1 : 0));
    return people;
  }

  Future<void> answer(int option) async {
    setState(() {
      answers.add(option);
      finding = done;
    });
    if (!done) return;
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (mounted) setState(() => finding = false);
  }

  void retake() => setState(() {
        answers.clear();
        shown = 0;
      });

  void startChat(Person person) {
    final store = widget.store;
    final chat = store.chatWith(person);
    // Their prompt answer opens the conversation, as in the introduction.
    if (chat.messages.isEmpty) {
      chat.messages.add(ChatMessage(person.answer));
      store.update();
    }
    Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
            builder: (_) => ChatScreen(store: store, chat: chat)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          children: [
            Text('Introductions',
                style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 8),
            Text(
                'Answer five short questions and meet someone to begin a conversation with.',
                style: TextStyle(color: EverlaneColors.muted, height: 1.5)),
            const SizedBox(height: 20),
            if (!done) ..._question(context),
            if (done && finding)
              Padding(
                  padding: const EdgeInsets.only(top: 80),
                  child: Column(children: [
                    const CircularProgressIndicator(color: EverlaneColors.like),
                    const SizedBox(height: 18),
                    Text('Finding your introduction…',
                        style: TextStyle(color: EverlaneColors.muted)),
                  ])),
            if (done && !finding) ..._result(context),
          ]));

  List<Widget> _question(BuildContext context) {
    final q = _questions[answers.length];
    return [
      ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: TweenAnimationBuilder<double>(
              tween: Tween(end: answers.length / _questions.length),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 4,
                  color: EverlaneColors.like,
                  backgroundColor: EverlaneColors.line))),
      const SizedBox(height: 18),
      Text('Question ${answers.length + 1} of ${_questions.length}',
          style: TextStyle(fontSize: 12, color: EverlaneColors.muted)),
      const SizedBox(height: 10),
      Text(q.text, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 20),
      for (var i = 0; i < q.options.length; i++)
        Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
                color: EverlaneColors.card,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => answer(i),
                    child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 17),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: EverlaneColors.line)),
                        child: Text(q.options[i],
                            style: const TextStyle(fontSize: 15)))))),
    ];
  }

  List<Widget> _result(BuildContext context) {
    final people = matches;
    if (people.isEmpty) {
      return [
        EmptyState(
            icon: Icons.auto_awesome_outlined,
            title: 'No one new right now.',
            detail: 'Check back soon for your next introduction.',
            action:
                OutlinedButton(onPressed: retake, child: const Text('Retake'))),
      ];
    }
    final person = people[shown % people.length];
    final choice = _questions.first.options[answers.first].toLowerCase();
    return [
      Text(
          'You’re looking for ${choice.startsWith('a ') ? choice : 'something $choice'}. Here’s someone to begin with.',
          style: const TextStyle(height: 1.5)),
      const SizedBox(height: 16),
      AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          switchInCurve: Curves.easeOutCubic,
          child: Container(
              key: ValueKey(person.id),
              decoration: BoxDecoration(
                  color: EverlaneColors.card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: EverlaneColors.line)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(children: [
                      Portrait(person,
                          height: 300, width: double.infinity, radius: 24),
                      if (person.verified)
                        Positioned(
                            top: 14,
                            right: 14,
                            child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: .38),
                                    borderRadius: BorderRadius.circular(30)),
                                child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.verified_rounded,
                                          size: 14, color: Colors.white),
                                      SizedBox(width: 5),
                                      Text('Verified',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.white)),
                                    ]))),
                    ]),
                    Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${person.name}, ${person.age}',
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              Text('${person.job} · ${person.distanceLabel}',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: EverlaneColors.muted)),
                              const SizedBox(height: 12),
                              Wrap(spacing: 6, runSpacing: 6, children: [
                                for (final c in person.lookingFor)
                                  Tag(c.icon, c.short)
                              ]),
                              const SizedBox(height: 14),
                              Text('“${person.answer}”',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontStyle: FontStyle.italic,
                                      height: 1.5)),
                            ])),
                  ]))),
      const SizedBox(height: 18),
      FilledButton(
          onPressed: () => startChat(person),
          style: FilledButton.styleFrom(backgroundColor: EverlaneColors.like),
          child: const Text('Start chat')),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
            child: OutlinedButton(
                onPressed:
                    people.length > 1 ? () => setState(() => shown++) : null,
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
                child: const Text('Show another'))),
        const SizedBox(width: 10),
        Expanded(
            child: OutlinedButton(
                onPressed: retake,
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
                child: const Text('Retake'))),
      ]),
    ];
  }
}
