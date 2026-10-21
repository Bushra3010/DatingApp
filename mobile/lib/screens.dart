import 'package:flutter/material.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key, required this.store});
  final PreviewStore store;

  void pass(BuildContext context, Person person) {
    store.skip(person);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Passed on ${person.name}'),
      action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () => store.undo(person)),
    ));
  }

  /// Right swipe: a plain like on the whole profile, without the composer.
  bool swipeLike(BuildContext context, Person person) {
    if (store.remaining <= 0) {
      showNotice(
          context, 'You’ve used your 8 preview likes. Take a little breather.');
      return false;
    }
    store.like(person, target: 'profile');
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('You liked ${person.name}')));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final people = store.discover;
    if (people.isEmpty) {
      return EmptyState(
        icon: Icons.wb_sunny_outlined,
        title: store.paused ? 'Take your time.' : 'You’re all caught up.',
        detail: store.paused
            ? 'Your profile is paused. Your conversations are still here.'
            : 'Try widening your preferences to meet more people.',
        action: FilledButton(
            onPressed: () {
              if (store.paused) {
                store.paused = false;
                store.update();
              } else {
                showFilters(context, store);
              }
            },
            child: Text(
                store.paused ? 'Resume discovering' : 'Adjust preferences')),
      );
    }
    final person = people.first;
    void like() => showLikeComposer(context, store, person, 'photo');
    void details() => Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => PersonDetailsScreen(person: person, store: store)));
    return LayoutBuilder(builder: (context, constraints) {
      final photoHeight =
          (constraints.maxHeight - 280).clamp(140.0, constraints.maxWidth - 72);
      return Column(children: [
        Expanded(
            child: ListView(
          key: ValueKey(person.id),
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
          children: [
            SwipeCard(
                key: ValueKey('swipe-${person.id}'),
                onLike: () => swipeLike(context, person),
                onPass: () => pass(context, person),
                child: Stack(clipBehavior: Clip.none, children: [
                  Positioned.fill(
                      top: 18,
                      bottom: -12,
                      left: 13,
                      right: 13,
                      child: DecoratedBox(
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: const [
                            BoxShadow(
                                color: Color(0x0C29202B),
                                blurRadius: 18,
                                offset: Offset(0, 12))
                          ]))),
                  _PersonCard(
                      photoHeight: photoHeight,
                      person: person,
                      onOpen: details,
                      onMore: () => showSafety(context, store, person)),
                ])),
            const SizedBox(height: 22),
            Center(
                child: TextButton.icon(
                    onPressed: details,
                    icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 18),
                    label: const Text('Get to know them',
                        style: TextStyle(
                            fontSize: 12, color: EverlaneColors.muted)))),
          ],
        )),
        Padding(
            padding: const EdgeInsets.fromLTRB(30, 16, 30, 16),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  PastelAction(
                      icon: Icons.star_rounded,
                      label: 'Like ${person.name}’s prompt',
                      color: EverlaneColors.red,
                      size: 49,
                      onTap: () => showLikeComposer(
                          context, store, person, 'My ideal Sunday')),
                  PastelAction(
                      icon: Icons.close_rounded,
                      label: 'Pass on ${person.name}',
                      color: EverlaneColors.blue,
                      size: 72,
                      onTap: () => pass(context, person)),
                  PastelAction(
                      icon: Icons.favorite_rounded,
                      label: 'Like ${person.name}’s photo',
                      color: EverlaneColors.purple,
                      size: 72,
                      onTap: like),
                  PastelAction(
                      icon: Icons.bolt_rounded,
                      label: 'Discovery preferences',
                      color: EverlaneColors.lime,
                      size: 49,
                      onTap: () => showFilters(context, store)),
                ])),
        Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text('${store.remaining} likes left · Preview',
                style: const TextStyle(
                    fontSize: 11, color: EverlaneColors.muted))),
      ]);
    });
  }
}

/// Drag the card right to like or left to pass. Short drags spring back.
class SwipeCard extends StatefulWidget {
  const SwipeCard(
      {super.key,
      required this.child,
      required this.onLike,
      required this.onPass});
  final Widget child;

  /// Returns false when the like is refused, which springs the card back.
  final bool Function() onLike;
  final VoidCallback onPass;
  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 220))
    ..addListener(() => setState(() => dx = animation.value));
  Animation<double> animation = const AlwaysStoppedAnimation(0);
  double dx = 0;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> animateTo(double target) {
    animation = Tween(begin: dx, end: target)
        .animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));
    return controller.forward(from: 0);
  }

  Future<void> release(double width, double velocity) async {
    final right = dx > width * .3 || velocity > 800;
    final left = dx < -width * .3 || velocity < -800;
    if (!right && !left) return animateTo(0);
    await animateTo((right ? 1.5 : -1.5) * width);
    if (!mounted) return;
    if (right) {
      if (!widget.onLike()) await animateTo(0);
    } else {
      widget.onPass();
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final progress = (dx / (c.maxWidth * .3)).clamp(-1.0, 1.0);
        return GestureDetector(
            onHorizontalDragStart: (_) => controller.stop(),
            onHorizontalDragUpdate: (d) => setState(() => dx += d.delta.dx),
            onHorizontalDragEnd: (d) =>
                release(c.maxWidth, d.velocity.pixelsPerSecond.dx),
            child: Transform.translate(
                offset: Offset(dx, 0),
                child: Transform.rotate(
                    angle: progress * .12,
                    child: Stack(children: [
                      widget.child,
                      if (progress > 0)
                        _SwipeStamp(
                            label: 'LIKE',
                            color: EverlaneColors.purple,
                            opacity: progress,
                            alignment: Alignment.topLeft),
                      if (progress < 0)
                        _SwipeStamp(
                            label: 'PASS',
                            color: EverlaneColors.blue,
                            opacity: -progress,
                            alignment: Alignment.topRight),
                    ]))));
      });
}

class _SwipeStamp extends StatelessWidget {
  const _SwipeStamp(
      {required this.label,
      required this.color,
      required this.opacity,
      required this.alignment});
  final String label;
  final Color color;
  final double opacity;
  final Alignment alignment;
  @override
  Widget build(BuildContext context) => Positioned.fill(
      child: IgnorePointer(
          child: Padding(
              padding: const EdgeInsets.all(30),
              child: Align(
                  alignment: alignment,
                  child: Opacity(
                      opacity: opacity,
                      child: Transform.rotate(
                          angle: alignment == Alignment.topLeft ? -.25 : .25,
                          child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: .85),
                                  border: Border.all(color: color, width: 3),
                                  borderRadius: BorderRadius.circular(10)),
                              child: Text(label,
                                  style: TextStyle(
                                      color: color,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2)))))))));
}

class _PersonCard extends StatelessWidget {
  const _PersonCard(
      {required this.person,
      required this.photoHeight,
      required this.onOpen,
      required this.onMore});
  final Person person;
  final VoidCallback onOpen, onMore;
  final double photoHeight;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
                color: Color(0x152D2231), blurRadius: 24, offset: Offset(0, 8))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
            onTap: onOpen,
            child: Portrait(person,
                height: photoHeight, width: double.infinity, radius: 18)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
              child: GestureDetector(
                  onTap: onOpen,
                  child: Text('${person.name}, ${person.age}',
                      style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.6)))),
          if (person.verified)
            const Tooltip(
                message: 'Selfie verified',
                child: Icon(Icons.verified_rounded,
                    size: 18, color: EverlaneColors.blue)),
          SizedBox(
              width: 34,
              height: 32,
              child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: 'Profile options',
                  onPressed: onMore,
                  icon: const Icon(Icons.more_horiz,
                      size: 22, color: EverlaneColors.muted))),
        ]),
        Text(person.job,
            style: const TextStyle(color: EverlaneColors.muted, fontSize: 15)),
        const SizedBox(height: 12),
        Row(children: [
          const Icon(Icons.location_on_outlined,
              size: 14, color: EverlaneColors.muted),
          const SizedBox(width: 4),
          Expanded(
              child: Text('Bengaluru · ${person.distance} km away',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: EverlaneColors.muted))),
          const SizedBox(width: 8),
          const Icon(Icons.favorite_rounded,
              size: 14, color: EverlaneColors.red),
          const SizedBox(width: 4),
          const Text('Relationship', style: TextStyle(fontSize: 11)),
        ]),
        const SizedBox(height: 10),
      ]));
}

class PersonDetailsScreen extends StatelessWidget {
  const PersonDetailsScreen(
      {super.key, required this.person, required this.store});
  final Person person;
  final PreviewStore store;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('Discover', style: TextStyle(fontSize: 17)),
            actions: [
              IconButton(
                  tooltip: 'Profile options',
                  onPressed: () => showSafety(context, store, person),
                  icon: const Icon(Icons.more_horiz)),
              const SizedBox(width: 12)
            ]),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
                    children: [
                      AspectRatio(
                          aspectRatio: 1.05,
                          child: Portrait(person, radius: 22)),
                      const SizedBox(height: 22),
                      Row(children: [
                        Expanded(
                            child: Text('${person.name}, ${person.age}',
                                style: Theme.of(context).textTheme.titleLarge)),
                        RoundButton(
                            icon: Icons.favorite_border_rounded,
                            label: 'Like ${person.name}’s photo',
                            onTap: () => showLikeComposer(
                                context, store, person, 'photo'))
                      ]),
                      Text('Bengaluru, India',
                          style: const TextStyle(
                              fontSize: 16, color: EverlaneColors.muted)),
                      const SizedBox(height: 30),
                      const DetailHeading(
                          icon: Icons.person_outline_rounded,
                          title: 'About',
                          color: Color(0xFFEFB91E)),
                      const SizedBox(height: 12),
                      Text(
                          '${person.job}. Looking for a lasting connection and someone to share the everyday adventures with.',
                          style: const TextStyle(
                              color: EverlaneColors.muted, height: 1.7)),
                      const SizedBox(height: 28),
                      const DetailHeading(
                          icon: Icons.favorite_rounded,
                          title: 'Interests',
                          color: EverlaneColors.red),
                      const SizedBox(height: 16),
                      const Wrap(spacing: 10, runSpacing: 10, children: [
                        Tag(Icons.music_note_outlined, 'Music'),
                        Tag(Icons.coffee_outlined, 'Coffee'),
                        Tag(Icons.menu_book_outlined, 'Books'),
                        Tag(Icons.pets_outlined, 'Dogs'),
                        Tag(Icons.explore_outlined, 'Exploring'),
                        Tag(Icons.restaurant_outlined, 'Good food')
                      ]),
                      const SizedBox(height: 28),
                      Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                              color: EverlaneColors.blush,
                              borderRadius: BorderRadius.circular(20)),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('My ideal Sunday',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 12),
                                Text(person.answer,
                                    style: const TextStyle(
                                        fontSize: 20, height: 1.5)),
                                Align(
                                    alignment: Alignment.centerRight,
                                    child: RoundButton(
                                        icon: Icons.favorite_border,
                                        label: 'Like this prompt',
                                        onTap: () => showLikeComposer(context,
                                            store, person, 'My ideal Sunday'))),
                              ])),
                    ]))),
      );
}

class DetailHeading extends StatelessWidget {
  const DetailHeading(
      {super.key,
      required this.icon,
      required this.title,
      required this.color});
  final IconData icon;
  final String title;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: Colors.white, size: 17)),
        const SizedBox(width: 9),
        Text(title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ]);
}

Future<void> showLikeComposer(BuildContext context, PreviewStore store,
    Person person, String target) async {
  if (store.remaining <= 0) {
    showNotice(
        context, 'You’ve used your 8 preview likes. Take a little breather.');
    return;
  }
  final controller = TextEditingController();
  final sent = await showEverlaneSheet<bool>(
      context,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Eyebrow('Make the first move'),
        const SizedBox(height: 12),
        Text('A little more than a like.',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 18),
        Row(children: [
          Portrait(person, height: 62, width: 54, radius: 10),
          const SizedBox(width: 14),
          Expanded(
              child: Text(
                  'You’re liking ${person.name}’s ${target == 'photo' ? 'photo' : 'answer to “$target”'}.'))
        ]),
        const SizedBox(height: 20),
        TextField(
            controller: controller,
            maxLength: 150,
            maxLines: 3,
            autofocus: true,
            decoration: const InputDecoration(
                hintText:
                    'What caught your attention?\nAdd a comment (optional).')),
        const SizedBox(height: 14),
        FilledButton(
            onPressed: () {
              store.like(person, target: target, comment: controller.text);
              Navigator.pop(context, true);
            },
            child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 18),
                  SizedBox(width: 8),
                  Text('Send like')
                ])),
        const SizedBox(height: 12),
        const Text('Preview only. Your like won’t be sent to a real person.',
            style: TextStyle(fontSize: 11, color: EverlaneColors.muted)),
      ]));
  // Wait for the sheet's reverse transition before disposing its field controller.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  controller.dispose();
  if (sent == true && context.mounted) {
    showNotice(context, 'Like sent to ${person.name} in this preview.');
  }
}

Future<void> showFilters(BuildContext context, PreviewStore store) async {
  var ages = store.ages;
  var distance = store.distance;
  var verified = store.verifiedOnly;
  await showEverlaneSheet(
      context,
      StatefulBuilder(
          builder: (context, setState) =>
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Eyebrow('Your kind of connection'),
                const SizedBox(height: 10),
                Text('Widen your circle.\nOr make it a little closer.',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 28),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(child: Text('Age range')),
                      Text('${ages.start.round()}–${ages.end.round()}',
                          style: const TextStyle(fontWeight: FontWeight.w600))
                    ]),
                RangeSlider(
                    values: ages,
                    min: 18,
                    max: 60,
                    divisions: 42,
                    labels: RangeLabels(
                        '${ages.start.round()}', '${ages.end.round()}'),
                    onChanged: (value) => setState(() => ages = value)),
                const SizedBox(height: 18),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(child: Text('Maximum distance')),
                      Text('${distance.round()} km',
                          style: const TextStyle(fontWeight: FontWeight.w600))
                    ]),
                Slider(
                    value: distance,
                    min: 1,
                    max: 100,
                    divisions: 99,
                    label: '${distance.round()} km',
                    onChanged: (value) => setState(() => distance = value)),
                SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Selfie-verified profiles'),
                    subtitle: const Text('A little extra peace of mind'),
                    value: verified,
                    onChanged: (value) => setState(() => verified = value)),
                const SizedBox(height: 22),
                FilledButton(
                    onPressed: () {
                      store.ages = ages;
                      store.distance = distance;
                      store.verifiedOnly = verified;
                      store.update();
                      Navigator.pop(context);
                    },
                    child: const Text('Show my people')),
                Center(
                    child: TextButton(
                        onPressed: () => setState(() {
                              ages = const RangeValues(24, 32);
                              distance = 25;
                              verified = false;
                            }),
                        child: const Text('Reset preferences'))),
              ])));
}

class LikesScreen extends StatelessWidget {
  const LikesScreen({super.key, required this.store});
  final PreviewStore store;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(24), children: [
        const Eyebrow('The feeling could be mutual'),
        const SizedBox(height: 10),
        Text('Likes you', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 10),
        const Text('A little interest. A lovely place to start.',
            style: TextStyle(color: EverlaneColors.muted)),
        const SizedBox(height: 28),
        if (store.incoming.isEmpty)
          const EmptyState(
              icon: Icons.favorite_border,
              title: 'Room for something good.',
              detail:
                  'You’re all caught up. New likes will find their way here.'),
        for (final p in store.incoming)
          Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Container(
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: EverlaneColors.line)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Portrait(p, height: 240, width: double.infinity),
                        Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Text('${p.name}, ${p.age}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge),
                                    const SizedBox(width: 7),
                                    const Icon(Icons.verified,
                                        size: 17, color: EverlaneColors.green)
                                  ]),
                                  const SizedBox(height: 5),
                                  const Text(
                                      'Liked your answer to “My ideal Sunday”',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: EverlaneColors.muted)),
                                  const SizedBox(height: 16),
                                  const Text(
                                      '“I know just the place. Coffee and a bookstore sounds like a pretty perfect start.”',
                                      style: TextStyle(
                                          fontSize: 20, height: 1.45)),
                                  const SizedBox(height: 20),
                                  Row(children: [
                                    RoundButton(
                                        icon: Icons.close,
                                        label: 'Remove ${p.name}’s like',
                                        onTap: () => store.removeLike(p)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: FilledButton(
                                            onPressed: () {
                                              final chat = store.match(p);
                                              Navigator.push(
                                                  context,
                                                  MaterialPageRoute<void>(
                                                      builder: (_) =>
                                                          ChatScreen(
                                                              store: store,
                                                              chat: chat)));
                                            },
                                            child: const Text(
                                                'Like back & say hello')))
                                  ]),
                                ])),
                      ]))),
        const Center(child: Eyebrow('Demo likes · UI preview')),
      ]);
}

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key, required this.store});
  final PreviewStore store;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(24), children: [
        const Eyebrow('Less small talk. More possibility.'),
        const SizedBox(height: 10),
        Text('Messages', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 28),
        Row(children: [
          const Text('YOUR CONNECTIONS',
              style: TextStyle(
                  fontSize: 10, letterSpacing: 2, color: EverlaneColors.muted)),
          const SizedBox(width: 8),
          Text('${store.conversations.length}',
              style: const TextStyle(fontSize: 12, color: EverlaneColors.coral))
        ]),
        const SizedBox(height: 16),
        if (store.conversations.isEmpty)
          const EmptyState(
              icon: Icons.chat_bubble_outline,
              title: 'Your next hello is out there.',
              detail:
                  'When a like becomes mutual, your conversation begins here.'),
        for (final chat in store.conversations)
          Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                leading:
                    Portrait(chat.person, height: 62, width: 62, radius: 31),
                title: Text(chat.person.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                    chat.messages.isEmpty
                        ? 'Start with a little hello'
                        : chat.messages.last.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: EverlaneColors.muted)),
                trailing: const Icon(Icons.chevron_right,
                    color: EverlaneColors.muted),
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => ChatScreen(store: store, chat: chat))),
              )),
        const SizedBox(height: 30),
        Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: EverlaneColors.blush,
                borderRadius: BorderRadius.circular(18)),
            child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, color: EverlaneColors.coral),
                  SizedBox(width: 12),
                  Expanded(
                      child: Text(
                          'A good question goes a long way. Ask about something that made you curious.',
                          style: TextStyle(fontSize: 13, height: 1.6)))
                ])),
      ]);
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.store, required this.chat});
  final PreviewStore store;
  final Conversation chat;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final controller = TextEditingController();
  final scroll = ScrollController();
  void send() {
    if (controller.text.trim().isEmpty) return;
    setState(() {
      widget.store.send(widget.chat, controller.text);
      controller.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Row(children: [
              Portrait(widget.chat.person, height: 38, width: 38, radius: 19),
              const SizedBox(width: 12),
              Text(widget.chat.person.name,
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              const Icon(Icons.verified, size: 16, color: EverlaneColors.green)
            ]),
            actions: [
              IconButton(
                  tooltip: 'Conversation safety',
                  onPressed: () => showSafety(
                      context, widget.store, widget.chat.person,
                      chat: widget.chat),
                  icon: const Icon(Icons.shield_outlined))
            ]),
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(children: [
                      Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          color: EverlaneColors.blush,
                          child: const Text(
                              'Demo conversation · Messages stay on this device',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 11, color: EverlaneColors.muted))),
                      Expanded(
                          child: ListView(
                              controller: scroll,
                              padding: const EdgeInsets.all(22),
                              children: [
                            const Padding(
                                padding: EdgeInsets.symmetric(vertical: 22),
                                child: Center(
                                    child: Eyebrow(
                                        'Every good story starts somewhere'))),
                            for (final message in widget.chat.messages)
                              Align(
                                  alignment: message.mine
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Container(
                                      constraints:
                                          const BoxConstraints(maxWidth: 300),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 18, vertical: 14),
                                      decoration: BoxDecoration(
                                          color: message.mine
                                              ? EverlaneColors.plum
                                              : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(18)),
                                      child: Text(message.text,
                                          style: TextStyle(
                                              color: message.mine
                                                  ? Colors.white
                                                  : EverlaneColors.plum,
                                              height: 1.5)))),
                          ])),
                      Padding(
                          padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                    child: TextField(
                                        controller: controller,
                                        minLines: 1,
                                        maxLines: 4,
                                        maxLength: 2000,
                                        decoration: const InputDecoration(
                                            hintText: 'A little hello…',
                                            counterText: ''),
                                        onSubmitted: (_) => send())),
                                const SizedBox(width: 10),
                                RoundButton(
                                    icon: Icons.arrow_upward_rounded,
                                    label: 'Send message',
                                    filled: true,
                                    onTap: send)
                              ])),
                    ])))),
      );
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.store});
  final PreviewStore store;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(24), children: [
        const Eyebrow('Unmistakably, wonderfully you'),
        const SizedBox(height: 10),
        Text('My profile', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 26),
        Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: EverlaneColors.line)),
            child: Row(children: [
              Container(
                  width: 70,
                  height: 70,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: EverlaneColors.blush),
                  alignment: Alignment.center,
                  child: Text(store.myName.isEmpty ? 'R' : store.myName[0],
                      style: const TextStyle(
                          fontSize: 32, color: EverlaneColors.coral))),
              const SizedBox(width: 18),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('${store.myName}, 29',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(store.myJob,
                        style: const TextStyle(
                            color: EverlaneColors.muted, fontSize: 12)),
                    const SizedBox(height: 6),
                    const Eyebrow('Preview profile',
                        color: EverlaneColors.coral)
                  ])),
              IconButton(
                  tooltip: 'Edit profile',
                  onPressed: () => editProfile(context, store),
                  icon: const Icon(Icons.edit_outlined, size: 21)),
            ])),
        const SizedBox(height: 20),
        Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
                color: EverlaneColors.blush,
                borderRadius: BorderRadius.circular(20)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Eyebrow('My ideal Sunday'),
              const SizedBox(height: 12),
              Text(store.myPrompt,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontSize: 24, height: 1.4))
            ])),
        const SizedBox(height: 24),
        const Eyebrow('Make yourself at home'),
        const SizedBox(height: 12),
        ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.tune),
            title: const Text('Dating preferences'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showFilters(context, store)),
        const Divider(height: 1),
        SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.pause_circle_outline),
            title: const Text('Take a pause'),
            subtitle: const Text('Keep your chats. Take some time.',
                style: TextStyle(fontSize: 12)),
            value: store.paused,
            onChanged: (value) {
              store.paused = value;
              store.update();
            }),
        const Divider(height: 1),
        SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.notifications_none),
            title: const Text('Notifications'),
            subtitle: const Text('Preview preference only',
                style: TextStyle(fontSize: 12)),
            value: store.notifications,
            onChanged: (value) {
              store.notifications = value;
              store.update();
            }),
        const Divider(height: 1),
        ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.shield_outlined),
            title: const Text('A safer space'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showEverlaneSheet(
                context,
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Your comfort comes first.',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 18),
                  const Text(
                      'Meet in a public place. Let someone you trust know your plans. Keep personal and financial information private.\n\nYou can report or block a profile from its menu, or find safety options at the top of a conversation.'),
                  const SizedBox(height: 20)
                ]))),
        const SizedBox(height: 28),
        const Center(
            child: Icon(Icons.spa_outlined,
                size: 27, color: EverlaneColors.coral)),
        const SizedBox(height: 9),
        const Center(
            child: Text('Made for something real.',
                style: TextStyle(fontSize: 17, color: EverlaneColors.muted))),
        const SizedBox(height: 9),
        const Center(
            child: Text('Everlane · UI preview 0.1',
                style: TextStyle(fontSize: 10, color: EverlaneColors.muted))),
      ]);
}

Future<void> editProfile(BuildContext context, PreviewStore store) async {
  final name = TextEditingController(text: store.myName);
  final job = TextEditingController(text: store.myJob);
  final prompt = TextEditingController(text: store.myPrompt);
  final key = GlobalKey<FormState>();
  await showEverlaneSheet(
      context,
      Form(
          key: key,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('A little about you.',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),
            TextFormField(
                controller: name,
                maxLength: 40,
                decoration: const InputDecoration(labelText: 'First name'),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Add your first name'
                    : null),
            const SizedBox(height: 12),
            TextFormField(
                controller: job,
                maxLength: 80,
                decoration:
                    const InputDecoration(labelText: 'What do you do?')),
            const SizedBox(height: 12),
            TextFormField(
                controller: prompt,
                maxLength: 250,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'My ideal Sunday'),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Tell us a little about your Sunday'
                    : null),
            const SizedBox(height: 18),
            FilledButton(
                onPressed: () {
                  if (!key.currentState!.validate()) return;
                  store.myName = name.text.trim();
                  store.myJob = job.text.trim();
                  store.myPrompt = prompt.text.trim();
                  store.update();
                  Navigator.pop(context);
                },
                child: const Text('Save preview profile')),
          ])));
  await Future<void>.delayed(const Duration(milliseconds: 300));
  name.dispose();
  job.dispose();
  prompt.dispose();
}

Future<void> showSafety(BuildContext context, PreviewStore store, Person person,
    {Conversation? chat}) async {
  final action = await showEverlaneSheet<String>(
      context,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Your space. Your choice.',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text('Manage your connection with ${person.name}.',
            style: const TextStyle(color: EverlaneColors.muted)),
        const SizedBox(height: 20),
        ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Report profile'),
            onTap: () => Navigator.pop(context, 'report')),
        ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.block_outlined),
            title: const Text('Block profile'),
            onTap: () => Navigator.pop(context, 'block')),
        if (chat != null)
          ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_remove_outlined),
              title: const Text('Unmatch'),
              onTap: () => Navigator.pop(context, 'unmatch')),
      ]));
  if (action == null || !context.mounted) return;
  String? reason;
  if (action == 'report') {
    reason = await showEverlaneSheet<String>(
        context,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('What happened?',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          const Text(
              'This preview hides the profile locally. It does not submit a report to a moderation team.'),
          for (final r in [
            'Fake or misleading profile',
            'Inappropriate content',
            'Harassment or unsafe behaviour',
            'Something else'
          ])
            ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(r),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(context, r))
        ]));
    if (reason == null || !context.mounted) return;
  }
  if (action != 'report') {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(action == 'unmatch'
                    ? 'End this connection?'
                    : 'Block ${person.name}?'),
                content: const Text(
                    'This will remove the profile and any conversation from this preview.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep connection')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Remove'))
                ]));
    if (confirmed != true || !context.mounted) return;
  }
  store.passed.add(person.id);
  store.incoming.removeWhere((p) => p.id == person.id);
  store.conversations.removeWhere((c) => c.person.id == person.id);
  store.update();
  if (chat != null) Navigator.pop(context);
  showNotice(
      context,
      action == 'report'
          ? 'Profile hidden in preview. No report was submitted.'
          : 'Connection removed from this preview.');
}
