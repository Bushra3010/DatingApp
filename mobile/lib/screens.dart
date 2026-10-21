import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';
import 'hangouts.dart';
import 'introductions.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key, required this.store});
  final PreviewStore store;

  /// No snackbar here: it would cover the Undo button in the action row.
  void pass(BuildContext context, Person person) {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    store.skip(person);
  }

  /// Right swipe: a plain like on the whole profile, without the composer.
  bool swipeLike(BuildContext context, Person person) {
    if (store.outOfLikes) {
      showUpgrade(context, store,
          title: 'You’ve used today’s 8 likes.',
          detail:
              'Get Plus for unlimited likes, or take a breather and come back tomorrow.');
      return false;
    }
    HapticFeedback.lightImpact();
    store.like(person, target: 'profile');
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('You liked ${person.name}')));
    return true;
  }

  void undoPass(BuildContext context) {
    if (!store.canRewind) {
      showUpgrade(context, store,
          title: 'Passed by mistake?',
          detail:
              'Rewind brings back the last profile you passed on. It comes with Plus and Premium.');
      return;
    }
    final person = store.undoLastPass();
    if (person == null) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    showNotice(context, '${person.name} is back');
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
        action: Column(children: [
          FilledButton(
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
          if (!store.paused && store.canUndo) ...[
            const SizedBox(height: 8),
            TextButton.icon(
                onPressed: () => undoPass(context),
                icon: const Icon(Icons.replay_rounded, size: 18),
                label: const Text('Undo last pass')),
          ],
        ]),
      );
    }
    final person = people.first;
    void like() {
      HapticFeedback.lightImpact();
      showLikeComposer(context, store, person, 'photo');
    }

    void details() => Navigator.push(
        context,
        editorialRoute<void>(
            (_) => PersonDetailsScreen(person: person, store: store)));
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
                              color: EverlaneColors.card,
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
                      onMore: () => showSafety(context, store, person),
                      onPrompt: (target) {
                        HapticFeedback.selectionClick();
                        showLikeComposer(context, store, person, target);
                      }),
                ])),
            const SizedBox(height: 22),
            Center(
                child: TextButton.icon(
                    onPressed: details,
                    icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 18),
                    label: Text('Get to know them',
                        style: TextStyle(
                            fontSize: 12, color: EverlaneColors.muted)))),
          ],
        )),
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  PastelAction(
                      icon: Icons.replay_rounded,
                      label: 'Undo last pass',
                      color: EverlaneColors.dark
                          ? EverlaneColors.muted
                          : EverlaneColors.deep,
                      size: 40,
                      onTap: store.canUndo ? () => undoPass(context) : null),
                  PastelAction(
                      icon: Icons.star_rounded,
                      label: 'Like ${person.name}’s prompt',
                      color: EverlaneColors.star,
                      size: 46,
                      onTap: () => showLikeComposer(
                          context, store, person, 'My ideal Sunday')),
                  PastelAction(
                      icon: Icons.close_rounded,
                      label: 'Pass on ${person.name}',
                      color: EverlaneColors.pass,
                      size: 66,
                      onTap: () => pass(context, person)),
                  PastelAction(
                      icon: Icons.favorite_rounded,
                      label: 'Like ${person.name}’s photo',
                      color: EverlaneColors.like,
                      size: 66,
                      onTap: like),
                  PastelAction(
                      icon: Icons.bolt_rounded,
                      label: 'Discovery preferences',
                      color: EverlaneColors.boost,
                      size: 46,
                      onTap: () => showFilters(context, store)),
                ])),
        Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
                store.unlimitedLikes
                    ? 'Unlimited likes · ${store.plan.title}'
                    : '${store.remaining} likes left · Preview',
                style: TextStyle(fontSize: 11, color: EverlaneColors.muted))),
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
      vsync: this, duration: const Duration(milliseconds: 420))
    ..addListener(() => setState(() => dx = animation.value));
  Animation<double> animation = const AlwaysStoppedAnimation(0);
  double dx = 0;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> animateTo(double target) {
    animation = Tween(begin: dx, end: target).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeOutCubic));
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
                // A slight 3D turn, like lifting a magazine page.
                child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, .0012)
                      ..rotateY(-progress * .28)
                      ..rotateZ(progress * .04),
                    child: Stack(children: [
                      widget.child,
                      if (progress > 0)
                        _SwipeStamp(
                            label: 'LIKE',
                            color: EverlaneColors.like,
                            opacity: progress,
                            alignment: Alignment.topLeft),
                      if (progress < 0)
                        _SwipeStamp(
                            label: 'PASS',
                            color: EverlaneColors.pass,
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
                                  color: EverlaneColors.card
                                      .withValues(alpha: .85),
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
      required this.onMore,
      required this.onPrompt});
  final Person person;
  final VoidCallback onOpen, onMore;

  /// Opens the like composer aimed at a photo detail ('photo', 'soundtrack').
  final ValueChanged<String> onPrompt;
  final double photoHeight;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: EverlaneColors.card,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
                color: Color(0x152D2231), blurRadius: 24, offset: Offset(0, 8))
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          GestureDetector(
              onTap: onOpen,
              child: Hero(
                  tag: 'portrait-${person.id}',
                  child: Portrait(person,
                      height: photoHeight,
                      width: double.infinity,
                      radius: 18))),
          if (person.soundtrack.isNotEmpty)
            Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: PhotoPrompt(
                        icon: Icons.music_note_rounded,
                        text:
                            '${person.name}’s soundtrack · ${person.soundtrack}',
                        onTap: () => onPrompt('soundtrack')))),
          Positioned(
              left: 12,
              bottom: 12,
              child: PhotoPrompt(
                  icon: Icons.chat_bubble_outline_rounded,
                  text: 'Ask about this photo',
                  onTap: () => onPrompt('photo'))),
        ]),
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
                    size: 18, color: EverlaneColors.pass)),
          SizedBox(
              width: 34,
              height: 32,
              child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: 'Profile options',
                  onPressed: onMore,
                  icon: Icon(Icons.more_horiz,
                      size: 22, color: EverlaneColors.muted))),
        ]),
        Text(person.job,
            style: TextStyle(color: EverlaneColors.muted, fontSize: 15)),
        const SizedBox(height: 12),
        Row(children: [
          Icon(Icons.location_on_outlined,
              size: 14, color: EverlaneColors.muted),
          const SizedBox(width: 4),
          Expanded(
              child: Text('Bengaluru · ${person.distanceLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: EverlaneColors.muted))),
          const SizedBox(width: 8),
          Icon(person.lookingFor.first.icon,
              size: 14, color: EverlaneColors.star),
          const SizedBox(width: 4),
          Text(person.lookingFor.first.short,
              style: const TextStyle(fontSize: 11)),
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
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Hero(
                                  tag: 'portrait-${person.id}',
                                  child: _Parallax(
                                      child: Portrait(person, radius: 0))))),
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
                      Text('Bengaluru · ${person.distanceLabel}',
                          style: TextStyle(
                              fontSize: 16, color: EverlaneColors.muted)),
                      const SizedBox(height: 16),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final c in person.lookingFor) Tag(c.icon, c.title)
                      ]),
                      if (person.voicePrompt.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        VoicePrompt(person: person),
                      ],
                      const SizedBox(height: 30),
                      const DetailHeading(
                          icon: Icons.person_outline_rounded,
                          title: 'About',
                          color: EverlaneColors.star),
                      const SizedBox(height: 12),
                      Text(
                          '${person.job}. Looking for a lasting connection and someone to share the everyday adventures with.',
                          style: TextStyle(
                              color: EverlaneColors.muted, height: 1.7)),
                      const SizedBox(height: 28),
                      const DetailHeading(
                          icon: Icons.favorite_rounded,
                          title: 'Interests',
                          color: EverlaneColors.like),
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
  if (store.outOfLikes) {
    showUpgrade(context, store,
        title: 'You’ve used today’s 8 likes.',
        detail:
            'Get Plus for unlimited likes, or take a breather and come back tomorrow.');
    return;
  }
  final sent = await showEverlaneSheet<bool>(
      context, _LikeComposer(store: store, person: person, target: target));
  if (sent == true && context.mounted) {
    showNotice(context, 'Like sent to ${person.name} in this preview.');
  }
}

/// Owns its controller so it outlives the sheet's closing animation.
class _LikeComposer extends StatefulWidget {
  const _LikeComposer(
      {required this.store, required this.person, required this.target});
  final PreviewStore store;
  final Person person;
  final String target;
  @override
  State<_LikeComposer> createState() => _LikeComposerState();
}

class _LikeComposerState extends State<_LikeComposer> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final person = widget.person;
    final target = widget.target;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                'You’re liking ${person.name}’s ${target == 'photo' || target == 'soundtrack' ? target : 'answer to “$target”'}.'))
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
      Text('Preview only. Your like won’t be sent to a real person.',
          style: TextStyle(fontSize: 11, color: EverlaneColors.muted)),
    ]);
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

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key, required this.store});
  final PreviewStore store;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(24), children: [
        const Eyebrow('Find your kind of plan'),
        const SizedBox(height: 10),
        Text('Explore', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 10),
        Text('Meet people who are looking for the same thing you are.',
            style: TextStyle(color: EverlaneColors.muted)),
        const SizedBox(height: 24),
        HangoutsBanner(store: store),
        const SizedBox(height: 12),
        IntroductionBanner(store: store),
        const SizedBox(height: 24),
        GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                mainAxisExtent: 196),
            children: [
              for (final c in LookingFor.values)
                _CategoryTile(
                    category: c,
                    count: store.exploring(c).length,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => ExploreCategoryScreen(
                                store: store, category: c))))
            ]),
      ]);
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile(
      {required this.category, required this.count, required this.onTap});
  final LookingFor category;
  final int count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
      color: EverlaneColors.card,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: EverlaneColors.line)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                            color: category.color,
                            borderRadius: BorderRadius.circular(14)),
                        child:
                            Icon(category.icon, color: Colors.white, size: 23)),
                    const Spacer(),
                    Text(category.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15,
                            height: 1.25,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(category.blurb,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11, color: EverlaneColors.muted)),
                    const SizedBox(height: 8),
                    Text(count == 1 ? '1 person' : '$count people',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: category.color)),
                  ]))));
}

class ExploreCategoryScreen extends StatelessWidget {
  const ExploreCategoryScreen(
      {super.key, required this.store, required this.category});
  final PreviewStore store;
  final LookingFor category;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final people = store.exploring(category);
        return Scaffold(
            appBar: AppBar(
                title:
                    Text(category.title, style: const TextStyle(fontSize: 17))),
            body: people.isEmpty
                ? EmptyState(
                    icon: category.icon,
                    title: 'No one here yet.',
                    detail: 'Check back soon, or explore another kind of plan.')
                : ListView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    children: [
                        Text(category.blurb,
                            style: TextStyle(color: EverlaneColors.muted)),
                        const SizedBox(height: 20),
                        for (final p in people)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _ExplorePerson(
                                  person: p,
                                  onTap: () => Navigator.push(
                                      context,
                                      editorialRoute<void>((_) =>
                                          PersonDetailsScreen(
                                              person: p, store: store))))),
                      ]));
      });
}

class _ExplorePerson extends StatelessWidget {
  const _ExplorePerson({required this.person, required this.onTap});
  final Person person;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
      color: EverlaneColors.card,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Portrait(person, height: 96, width: 84, radius: 16),
                const SizedBox(width: 14),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('${person.name}, ${person.age}',
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('${person.job} · ${person.distanceLabel}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: EverlaneColors.muted)),
                      const SizedBox(height: 10),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final c in person.lookingFor) Tag(c.icon, c.short)
                      ]),
                    ])),
              ]))));
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
        Text('A little interest. A lovely place to start.',
            style: TextStyle(color: EverlaneColors.muted)),
        const SizedBox(height: 28),
        if (store.incoming.isNotEmpty && !store.canSeeLikes)
          _HiddenLikes(store: store)
        else if (store.incoming.isEmpty)
          const EmptyState(
              icon: Icons.favorite_border,
              title: 'Room for something good.',
              detail:
                  'You’re all caught up. New likes will find their way here.'),
        if (store.canSeeLikes)
          for (final p in store.incoming)
            Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: Container(
                    decoration: BoxDecoration(
                        color: EverlaneColors.card,
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
                                      if (p.verified) ...[
                                        const SizedBox(width: 7),
                                        const Icon(Icons.verified,
                                            size: 17,
                                            color: EverlaneColors.boost),
                                      ],
                                    ]),
                                    const SizedBox(height: 5),
                                    Text(
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
          Text('YOUR CONNECTIONS',
              style: TextStyle(
                  fontSize: 10, letterSpacing: 2, color: EverlaneColors.muted)),
          const SizedBox(width: 8),
          Text('${store.conversations.length}',
              style: const TextStyle(fontSize: 12, color: EverlaneColors.like))
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
                    style:
                        TextStyle(fontSize: 12, color: EverlaneColors.muted)),
                trailing:
                    Icon(Icons.chevron_right, color: EverlaneColors.muted),
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
                  Icon(Icons.lightbulb_outline, color: EverlaneColors.like),
                  SizedBox(width: 12),
                  Expanded(
                      child: Text(
                          'A good question goes a long way. Ask about something that made you curious.',
                          style: TextStyle(fontSize: 13, height: 1.6)))
                ])),
      ]);
}

class ChatScreen extends StatefulWidget {
  const ChatScreen(
      {super.key, required this.store, required this.chat, this.draft = ''});
  final PreviewStore store;
  final Conversation chat;

  /// Prefilled, unsent text, e.g. when messaging a Hangout host.
  final String draft;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final controller = TextEditingController(text: widget.draft);
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
              const Icon(Icons.verified, size: 16, color: EverlaneColors.boost)
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
                          child: Text(
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
                                              ? EverlaneColors.deep
                                              : EverlaneColors.card,
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
                color: EverlaneColors.card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: EverlaneColors.line)),
            child: Row(children: [
              Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: EverlaneColors.blush),
                  alignment: Alignment.center,
                  child: Text(store.myName.isEmpty ? 'R' : store.myName[0],
                      style: const TextStyle(
                          fontSize: 32, color: EverlaneColors.like))),
              const SizedBox(width: 18),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('${store.myName}, 29',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(store.myJob,
                        style: TextStyle(
                            color: EverlaneColors.muted, fontSize: 12)),
                    const SizedBox(height: 6),
                    const Eyebrow('Preview profile', color: EverlaneColors.like)
                  ])),
              IconButton(
                  tooltip: 'Edit profile',
                  onPressed: () => editProfile(context, store),
                  icon: const Icon(Icons.edit_outlined, size: 21)),
            ])),
        const SizedBox(height: 14),
        _MembershipBanner(store: store),
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
        SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(store.darkMode
                ? Icons.dark_mode_outlined
                : Icons.light_mode_outlined),
            title: const Text('Dark mode'),
            subtitle: const Text('Easier on the eyes at night',
                style: TextStyle(fontSize: 12)),
            value: store.darkMode,
            onChanged: (value) {
              store.darkMode = value;
              store.update();
            }),
        const Divider(height: 1),
        SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.visibility_off_outlined),
            title: Text(store.plan == Plan.free
                ? 'Invisible mode · Plus'
                : 'Invisible mode'),
            subtitle: const Text('Only people you like can see you',
                style: TextStyle(fontSize: 12)),
            value: store.invisible,
            onChanged: (value) {
              if (store.plan == Plan.free) {
                showUpgrade(context, store,
                    title: 'Date on your own terms.',
                    detail:
                        'Invisible mode keeps you out of Discover until you like someone first. It comes with Plus and Premium.');
                return;
              }
              store.invisible = value;
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
            child:
                Icon(Icons.spa_outlined, size: 27, color: EverlaneColors.like)),
        const SizedBox(height: 9),
        Center(
            child: Text('Made for something real.',
                style: TextStyle(fontSize: 17, color: EverlaneColors.muted))),
        const SizedBox(height: 9),
        Center(
            child: Text('Everlane · UI preview 0.1',
                style: TextStyle(fontSize: 10, color: EverlaneColors.muted))),
      ]);
}

Future<void> editProfile(BuildContext context, PreviewStore store) =>
    showEverlaneSheet(context, _EditProfileForm(store: store));

/// Owns its controllers so they outlive the sheet's closing animation.
class _EditProfileForm extends StatefulWidget {
  const _EditProfileForm({required this.store});
  final PreviewStore store;
  @override
  State<_EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends State<_EditProfileForm> {
  late final name = TextEditingController(text: widget.store.myName);
  late final job = TextEditingController(text: widget.store.myJob);
  late final prompt = TextEditingController(text: widget.store.myPrompt);
  final key = GlobalKey<FormState>();

  @override
  void dispose() {
    name.dispose();
    job.dispose();
    prompt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Form(
        key: key,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('A little about you.',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          TextFormField(
              controller: name,
              maxLength: 40,
              decoration: const InputDecoration(labelText: 'First name'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Add your first name' : null),
          const SizedBox(height: 12),
          TextFormField(
              controller: job,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'What do you do?')),
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
        ]));
  }
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
            style: TextStyle(color: EverlaneColors.muted)),
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

/// Clears the plan-change snackbar on the way out, so it can't cover the
/// screen underneath (a chat's send button, say).
Future<void> openMembership(BuildContext context, PreviewStore store) {
  final messenger = ScaffoldMessenger.of(context);
  return Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (_) => MembershipScreen(store: store)))
      .then((_) => messenger.hideCurrentSnackBar());
}

/// Shown when a free member taps a paid feature.
Future<void> showUpgrade(BuildContext context, PreviewStore store,
        {required String title, required String detail}) =>
    showEverlaneSheet(
        context,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  color: EverlaneColors.star,
                  borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.workspace_premium_rounded,
                  color: Colors.white, size: 28)),
          const SizedBox(height: 20),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          Text(detail,
              style: TextStyle(color: EverlaneColors.muted, height: 1.6)),
          const SizedBox(height: 24),
          FilledButton(
              onPressed: () {
                Navigator.pop(context);
                openMembership(context, store);
              },
              child: const Text('See membership')),
          const SizedBox(height: 8),
          Center(
              child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Not now'))),
        ]));

class _MembershipBanner extends StatelessWidget {
  const _MembershipBanner({required this.store});
  final PreviewStore store;
  @override
  Widget build(BuildContext context) {
    final free = store.plan == Plan.free;
    return Material(
        color: free ? EverlaneColors.deep : EverlaneColors.card,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => openMembership(context, store),
            child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: free
                        ? null
                        : Border.all(color: EverlaneColors.star, width: 1.5)),
                child: Row(children: [
                  const Icon(Icons.workspace_premium_rounded,
                      color: EverlaneColors.star, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(
                            free
                                ? 'Upgrade to Plus'
                                : '${store.plan.title} member',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color:
                                    free ? Colors.white : EverlaneColors.plum)),
                        const SizedBox(height: 3),
                        Text(
                            free
                                ? 'Unlimited likes, Rewind and more'
                                : 'Manage your membership',
                            style: TextStyle(
                                fontSize: 12,
                                color: free
                                    ? Colors.white.withValues(alpha: .75)
                                    : EverlaneColors.muted)),
                      ])),
                  Icon(Icons.chevron_right_rounded,
                      color: free ? Colors.white : EverlaneColors.muted),
                ]))));
  }
}

class MembershipScreen extends StatelessWidget {
  const MembershipScreen({super.key, required this.store});
  final PreviewStore store;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
          appBar: AppBar(
              title: const Text('Membership', style: TextStyle(fontSize: 17)),
              actions: [
                Container(
                    margin: const EdgeInsets.only(right: 20),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: EverlaneColors.star)),
                    child: Text('${store.plan.title} member',
                        style: TextStyle(
                            fontSize: 12, color: EverlaneColors.plum))),
              ]),
          body: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                Text('Find your person, faster.',
                    style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 10),
                Text(
                    'Every plan includes verification, report and block. Safety is never behind a paywall.',
                    style: TextStyle(color: EverlaneColors.muted, height: 1.5)),
                const SizedBox(height: 24),
                for (final plan in Plan.values)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _PlanCard(
                          plan: plan,
                          current: store.plan == plan,
                          onChoose: () {
                            store.choosePlan(plan);
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            showNotice(context, 'Welcome to ${plan.title}');
                          })),
                const Center(child: Eyebrow('Preview · no payment is taken')),
              ])));
}

class _PlanCard extends StatelessWidget {
  const _PlanCard(
      {required this.plan, required this.current, required this.onChoose});
  final Plan plan;
  final bool current;
  final VoidCallback onChoose;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
          color: EverlaneColors.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: current ? EverlaneColors.star : EverlaneColors.line,
              width: current ? 1.5 : 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(plan.title,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.6))),
          if (plan == Plan.plus)
            Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: EverlaneColors.blush,
                    borderRadius: BorderRadius.circular(20)),
                child: const Text('Most popular',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: EverlaneColors.like))),
        ]),
        const SizedBox(height: 4),
        Text(plan.price,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: EverlaneColors.star)),
        const SizedBox(height: 14),
        for (final perk in plan.perks)
          Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(Icons.auto_awesome,
                        size: 12, color: EverlaneColors.star)),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(perk,
                        style: TextStyle(
                            fontSize: 14, color: EverlaneColors.muted))),
              ])),
        const SizedBox(height: 10),
        current
            ? OutlinedButton(
                onPressed: null,
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
                child: const Text('Current plan'))
            : FilledButton(
                onPressed: onChoose,
                style: plan == Plan.free
                    ? null
                    : FilledButton.styleFrom(
                        backgroundColor: EverlaneColors.like),
                child: Text('Choose ${plan.title}')),
      ]));
}

/// Moves its child at a slower rate than the page scrolls.
class _Parallax extends StatelessWidget {
  const _Parallax({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final position = Scrollable.maybeOf(context)?.position;
    if (position == null) return child;
    return AnimatedBuilder(
        animation: position,
        builder: (context, child) => Transform.translate(
            offset: Offset(0, position.pixels * .35),
            child: Transform.scale(scale: 1.08, child: child)),
        child: child);
  }
}

/// Free members see that likes are waiting, softly blurred, with one calm
/// invitation rather than a pop-up.
class _HiddenLikes extends StatelessWidget {
  const _HiddenLikes({required this.store});
  final PreviewStore store;
  @override
  Widget build(BuildContext context) {
    final shown = store.incoming.take(3).toList();
    final count = store.incoming.length;
    final mid = (shown.length - 1) / 2;
    return Column(children: [
      SizedBox(
          height: 250,
          child: Stack(alignment: Alignment.center, children: [
            for (var i = shown.length - 1; i >= 0; i--)
              Transform.translate(
                  offset: Offset((i - mid) * 70, i * 6.0),
                  child: Transform.rotate(
                      angle: (i - mid) * .08,
                      child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: ImageFiltered(
                              imageFilter:
                                  ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                              child: Portrait(shown[i],
                                  height: 220, width: 160, radius: 20))))),
          ])),
      const SizedBox(height: 24),
      Text(count == 1 ? 'Someone likes you.' : '$count people like you.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 10),
      Text('See who they are and what caught their eye.',
          textAlign: TextAlign.center,
          style: TextStyle(color: EverlaneColors.muted, height: 1.5)),
      const SizedBox(height: 22),
      OutlinedButton(
          onPressed: () => openMembership(context, store),
          style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              side: BorderSide(color: EverlaneColors.plum),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16))),
          child: Text('Explore incoming connections',
              style: TextStyle(color: EverlaneColors.plum))),
      const SizedBox(height: 24),
    ]);
  }
}
