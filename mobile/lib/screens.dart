import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'crossed_paths.dart';
import 'match_celebration.dart';
import 'models.dart';
import 'photo_picker.dart';
import 'theme.dart';
import 'voice.dart';
import 'widgets.dart';
import 'hangouts.dart';
import 'introductions.dart';
import 'onboarding.dart';

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
      showOutOfLikes(context, store);
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
              'Rewind brings back the last profile you passed on. It comes with Plus, Gold and Platinum.');
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
    return Column(children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: SizedBox(
              width: double.infinity,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            Text('Discover',
                style: EverlaneFonts.playfair(
                    size: 30,
                    weight: FontWeight.w700,
                    color: EverlaneColors.plum)),
            const SizedBox(height: 2),
            Text(
                '${people.length} ${people.length == 1 ? 'person matches' : 'people match'} your preferences',
                style: TextStyle(fontSize: 13, color: EverlaneColors.muted)),
          ]))),
      Expanded(
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: SwipeCard(
                  key: ValueKey('swipe-${person.id}'),
                  onLike: () => swipeLike(context, person),
                  onPass: () => pass(context, person),
                  child: _PersonCard(
                      person: person,
                      onOpen: details,
                      onMore: () => showSafety(context, store, person),
                      onPrompt: (target) {
                        HapticFeedback.selectionClick();
                        showLikeComposer(context, store, person, target);
                      })))),
      Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _RoundAction(
                    icon: Icons.replay_rounded,
                    label: 'Undo last pass',
                    color: EverlaneColors.star,
                    size: 48,
                    onTap: store.canUndo ? () => undoPass(context) : null),
                _RoundAction(
                    icon: Icons.close_rounded,
                    label: 'Pass on ${person.name}',
                    color: const Color(0xFFF87171),
                    size: 60,
                    onTap: () => pass(context, person)),
                _RoundAction(
                    icon: Icons.star_rounded,
                    label: 'Like ${person.name}’s prompt',
                    color: const Color(0xFF38BDF8),
                    size: 48,
                    onTap: () => showLikeComposer(
                        context, store, person, 'My ideal Sunday')),
                _RoundAction(
                    icon: Icons.favorite_rounded,
                    label: 'Like ${person.name}’s photo',
                    color: Colors.white,
                    size: 72,
                    hero: true,
                    onTap: like),
                _RoundAction(
                    icon: Icons.bolt_rounded,
                    label: 'Boost your profile',
                    color: EverlaneColors.lavender,
                    size: 48,
                    onTap: () => showBoost(context, store)),
              ])),
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
              [
                '${store.remaining} likes left today',
                if (store.boosting)
                  'Boosting until ${TimeOfDay.fromDateTime(store.boostEndsAt!).format(context)}',
                store.plan.title,
              ].join(' · '),
              style: TextStyle(fontSize: 11, color: EverlaneColors.muted))),
    ]);
  }
}

/// A round action under the Discover card. The [hero] one (like) is the
/// big purple-to-pink gradient button; the rest are dark glassy circles.
class _RoundAction extends StatelessWidget {
  const _RoundAction(
      {required this.icon,
      required this.label,
      required this.color,
      required this.size,
      required this.onTap,
      this.hero = false});
  final IconData icon;
  final String label;
  final Color color;
  final double size;
  final bool hero;

  /// Null shows the button faded and disabled.
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: onTap == null ? .4 : 1,
      child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: hero ? EverlaneColors.premiumGradient : null,
              color: hero ? null : EverlaneColors.card,
              border: hero ? null : Border.all(color: EverlaneColors.line),
              boxShadow: [
                BoxShadow(
                    color: hero
                        ? EverlaneColors.deep.withValues(alpha: .55)
                        : Colors.black.withValues(alpha: .28),
                    blurRadius: hero ? 26 : 14,
                    offset: const Offset(0, 8))
              ]),
          child: IconButton(
              tooltip: label,
              onPressed: onTap,
              icon: Icon(icon, color: color, size: size * .45))));
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
      required this.onOpen,
      required this.onMore,
      required this.onPrompt});
  final Person person;
  final VoidCallback onOpen, onMore;

  /// Opens the like composer aimed at a photo detail ('photo', 'soundtrack').
  final ValueChanged<String> onPrompt;

  Widget _meta(IconData icon, String text) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: Colors.white.withValues(alpha: .85)),
        const SizedBox(width: 5),
        Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13, color: Colors.white.withValues(alpha: .9)))),
      ]);

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        // Short screens drop the extras so the name never runs off the top.
        final compact = c.maxHeight < 400;
        return DecoratedBox(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                      color: EverlaneColors.deep.withValues(alpha: .28),
                      blurRadius: 30,
                      offset: const Offset(0, 14))
                ]),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Stack(fit: StackFit.expand, children: [
                  GestureDetector(
                      onTap: onOpen,
                      child: Hero(
                          tag: 'portrait-${person.id}',
                          child: Portrait(person, radius: 0))),
                  const IgnorePointer(
                      child: DecoratedBox(
                          decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  stops: [0, .28, .5, 1],
                                  colors: [
                        Color(0x73000000),
                        Color(0x00000000),
                        Color(0x26000000),
                        Color(0xF50B0812),
                      ])))),
                  Positioned(
                      top: 14,
                      left: 14,
                      right: 10,
                      child: Row(children: [
                        if (person.activeNow)
                          const _GlassPill(
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                            DecoratedBox(
                                decoration: BoxDecoration(
                                    color: Color(0xFF22C55E),
                                    shape: BoxShape.circle),
                                child: SizedBox(width: 8, height: 8)),
                            SizedBox(width: 7),
                            Text('Active now',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600)),
                          ])),
                        const Spacer(),
                        Material(
                            color: Colors.black.withValues(alpha: .35),
                            shape: const CircleBorder(),
                            child: IconButton(
                                tooltip: 'Profile options',
                                onPressed: onMore,
                                icon: const Icon(Icons.more_horiz,
                                    color: Colors.white, size: 22))),
                      ])),
                  Positioned(
                      left: 18,
                      right: 18,
                      bottom: 18,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (person.soundtrack.isNotEmpty && !compact) ...[
                              PhotoPrompt(
                                  icon: Icons.music_note_rounded,
                                  text:
                                      '${person.name}’s soundtrack · ${person.soundtrack}',
                                  onTap: () => onPrompt('soundtrack')),
                              const SizedBox(height: 8),
                            ],
                            PhotoPrompt(
                                icon: Icons.chat_bubble_outline_rounded,
                                text: 'Ask about this photo',
                                onTap: () => onPrompt('photo')),
                            const SizedBox(height: 14),
                            Row(children: [
                              Flexible(
                                  child: GestureDetector(
                                      onTap: onOpen,
                                      child: Text.rich(
                                          EverlaneFonts.nameAge(
                                              person.name, person.age),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis))),
                              if (person.verified) ...[
                                const SizedBox(width: 8),
                                const Tooltip(
                                    message: 'Selfie verified',
                                    child: Icon(Icons.verified_rounded,
                                        size: 24, color: Color(0xFF60A5FA))),
                              ],
                            ]),
                            const SizedBox(height: 6),
                            Wrap(spacing: 14, runSpacing: 4, children: [
                              _meta(Icons.work_outline_rounded, person.job),
                              _meta(Icons.location_on_outlined,
                                  '${person.city} · ${person.distanceLabel}'),
                              _meta(person.lookingFor.first.icon,
                                  person.lookingFor.first.short),
                              if (person.heightCm != null)
                                _meta(Icons.height_rounded,
                                    heightLabel(person.heightCm!)),
                            ]),
                            if (person.bio.isNotEmpty && !compact) ...[
                              const SizedBox(height: 10),
                              Text(person.bio,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 14,
                                      height: 1.45,
                                      color:
                                          Colors.white.withValues(alpha: .88))),
                            ],
                            if (person.interests.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Row(children: [
                                const Icon(Icons.auto_awesome_rounded,
                                    size: 18, color: EverlaneColors.star),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                      for (final tag in person.interests)
                                        _GlassPill(
                                            child: Text(tag,
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12.5,
                                                    fontWeight:
                                                        FontWeight.w500))),
                                    ])),
                              ]),
                            ],
                          ])),
                ])));
      });
}

/// A translucent dark pill laid over a photo.
class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .38),
          border: Border.all(color: Colors.white.withValues(alpha: .18)),
          borderRadius: BorderRadius.circular(30)),
      child: child);
}

class PersonDetailsScreen extends StatelessWidget {
  const PersonDetailsScreen(
      {super.key,
      required this.person,
      required this.store,
      this.fromChat = false});
  final Person person;
  final PreviewStore store;

  /// Opened from a conversation: you've already matched, so there's nothing
  /// to like.
  final bool fromChat;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(fromChat ? person.name : 'Discover',
                style: const TextStyle(fontSize: 17)),
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
                        if (!fromChat)
                          RoundButton(
                              icon: Icons.favorite_border_rounded,
                              label: 'Like ${person.name}’s photo',
                              onTap: () => showLikeComposer(
                                  context, store, person, 'photo'))
                      ]),
                      Text('${person.city} · ${person.distanceLabel}',
                          style: TextStyle(
                              fontSize: 16, color: EverlaneColors.muted)),
                      const SizedBox(height: 16),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final c in person.lookingFor) Tag(c.icon, c.title)
                      ]),
                      if (person.hasVoice) ...[
                        const SizedBox(height: 22),
                        VoicePrompt.of(person),
                      ],
                      const SizedBox(height: 22),
                      ListenableBuilder(
                          listenable: store,
                          builder: (context, _) =>
                              ChemistryCard(store: store, person: person)),
                      const SizedBox(height: 30),
                      const DetailHeading(
                          icon: Icons.person_outline_rounded,
                          title: 'About',
                          color: EverlaneColors.star),
                      const SizedBox(height: 12),
                      Text(
                          person.bio.isNotEmpty
                              ? person.bio
                              : '${person.job}. Looking for a lasting connection and someone to share the everyday adventures with.',
                          style: TextStyle(
                              color: EverlaneColors.muted, height: 1.7)),
                      const SizedBox(height: 28),
                      const DetailHeading(
                          icon: Icons.favorite_rounded,
                          title: 'Interests',
                          color: EverlaneColors.like),
                      const SizedBox(height: 16),
                      Wrap(spacing: 10, runSpacing: 10, children: [
                        for (final tag in person.interests)
                          Tag(Icons.auto_awesome_outlined, tag),
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
                                if (!fromChat)
                                  Align(
                                      alignment: Alignment.centerRight,
                                      child: RoundButton(
                                          icon: Icons.favorite_border,
                                          label: 'Like this prompt',
                                          onTap: () => showLikeComposer(
                                              context,
                                              store,
                                              person,
                                              'My ideal Sunday'))),
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
    showOutOfLikes(context, store);
    return;
  }
  final sent = await showEverlaneSheet<bool>(
      context, _LikeComposer(store: store, person: person, target: target));
  if (sent == true && context.mounted) {
    showNotice(
        context,
        person.remote
            ? 'Like sent to ${person.name}.'
            : 'Like sent to ${person.name} in this preview.');
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
  var city = store.cityFilter;
  final cityField = TextEditingController(text: city);
  final intents = {...store.intentFilter};
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
                    onChanged: city.isEmpty
                        ? (value) => setState(() => distance = value)
                        : null),
                const SizedBox(height: 10),
                Row(children: [
                  const Expanded(child: Text('City')),
                  Text(city.isEmpty ? 'Near me' : city,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 10),
                TextField(
                    controller: cityField,
                    textInputAction: TextInputAction.search,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                        hintText: 'Search a city, e.g. Mumbai',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: city.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear city',
                                onPressed: () => setState(() {
                                      city = '';
                                      cityField.clear();
                                    }),
                                icon: const Icon(Icons.close_rounded))),
                    onChanged: (v) => setState(() => city = v.trim())),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final option in store.cityOptions
                      .where((c) => c
                          .toLowerCase()
                          .contains(cityField.text.trim().toLowerCase()))
                      .take(8))
                    ChoiceChip(
                        label: Text(option),
                        selected: option.toLowerCase() == city.toLowerCase(),
                        onSelected: (on) => setState(() {
                              city = on ? option : '';
                              cityField.text = city;
                            })),
                ]),
                if (city.isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                          'Showing people in $city. Distance doesn’t apply.',
                          style: TextStyle(
                              fontSize: 12, color: EverlaneColors.muted))),
                const SizedBox(height: 18),
                Row(children: [
                  const Expanded(child: Text('Selfie-verified profiles')),
                  if (!store.canFilterVerified)
                    TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          showUpgrade(context, store,
                              title: 'See only the real deal.',
                              detail:
                                  'Filter to selfie-verified profiles with Plus, Gold or Platinum.');
                        },
                        icon: const Icon(Icons.lock_outline_rounded, size: 16),
                        label: const Text('Plus')),
                ]),
                SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('A little extra peace of mind',
                        style: TextStyle(fontSize: 13)),
                    value: store.canFilterVerified && verified,
                    onChanged: store.canFilterVerified
                        ? (value) => setState(() => verified = value)
                        : null),
                const SizedBox(height: 14),
                Row(children: [
                  const Expanded(child: Text('Relationship intentions')),
                  if (!store.canFilterIntentions)
                    TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          showUpgrade(context, store,
                              title: 'Meet people who want what you want.',
                              detail:
                                  'Filter by relationship intentions with Plus, Gold or Platinum.');
                        },
                        icon: const Icon(Icons.lock_outline_rounded, size: 16),
                        label: const Text('Plus')),
                ]),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final c in LookingFor.values)
                    FilterChip(
                        label: Text(c.short),
                        selected: intents.contains(c),
                        onSelected: store.canFilterIntentions
                            ? (on) => setState(
                                () => on ? intents.add(c) : intents.remove(c))
                            : null),
                ]),
                const SizedBox(height: 22),
                FilledButton(
                    onPressed: () {
                      store.ages = ages;
                      store.distance = distance;
                      store.cityFilter = city;
                      store.verifiedOnly = store.canFilterVerified && verified;
                      store.intentFilter
                        ..clear()
                        ..addAll(intents);
                      store.update();
                      Navigator.pop(context);
                    },
                    child: const Text('Show my people')),
                Center(
                    child: TextButton(
                        onPressed: () => setState(() {
                              ages = const RangeValues(24, 32);
                              distance = 25;
                              city = '';
                              cityField.clear();
                              verified = false;
                              intents.clear();
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
        const SizedBox(height: 12),
        _NearbyBanner(store: store),
        const SizedBox(height: 12),
        _CrossedPathsBanner(store: store),
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

/// A wide Explore card that opens a screen.
class _ExploreLink extends StatelessWidget {
  const _ExploreLink(
      {required this.icon,
      required this.color,
      required this.title,
      required this.subtitle,
      required this.onTap});
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
      color: EverlaneColors.card,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: EverlaneColors.line)),
              child: Row(children: [
                Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                        color: color, borderRadius: BorderRadius.circular(16)),
                    child: Icon(icon, color: Colors.white, size: 26)),
                const SizedBox(width: 16),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 13, color: EverlaneColors.muted)),
                    ])),
                Icon(Icons.chevron_right_rounded, color: EverlaneColors.muted),
              ]))));
}

class _NearbyBanner extends StatelessWidget {
  const _NearbyBanner({required this.store});
  final PreviewStore store;
  @override
  Widget build(BuildContext context) {
    final count = store.nearby.length;
    return _ExploreLink(
        icon: Icons.near_me_rounded,
        color: EverlaneColors.boost,
        title: 'Nearby profiles',
        subtitle: count == 0
            ? 'No one close by right now'
            : count == 1
                ? '1 person close to you'
                : '$count people close to you',
        onTap: () => Navigator.push(context,
            MaterialPageRoute<void>(builder: (_) => NearbyScreen(store: store))));
  }
}

class _CrossedPathsBanner extends StatelessWidget {
  const _CrossedPathsBanner({required this.store});
  final PreviewStore store;
  @override
  Widget build(BuildContext context) {
    final count = store.crossings.length;
    return _ExploreLink(
        icon: Icons.map_rounded,
        color: EverlaneColors.like,
        title: 'Crossed paths',
        subtitle: count == 0
            ? 'See who you’ve crossed paths with'
            : count == 1
                ? '1 person you’ve crossed paths with'
                : '$count people you’ve crossed paths with',
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
                builder: (_) => CrossedPathsScreen(store: store))));
  }
}

/// People within a few km. Distances stay rounded ("Nearby"), never exact.
class NearbyScreen extends StatelessWidget {
  const NearbyScreen({super.key, required this.store});
  final PreviewStore store;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final people = store.nearby;
        return Scaffold(
            appBar: AppBar(
                title: const Text('Nearby', style: TextStyle(fontSize: 17))),
            body: people.isEmpty
                ? const EmptyState(
                    icon: Icons.near_me_outlined,
                    title: 'No one close by yet.',
                    detail:
                        'Check back later, or widen your distance in preferences.')
                : ListView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    children: [
                        Text(
                            'People close to you. We never show exact distance or location.',
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
                                        _likedWhat(store.likeNotes[p.id]),
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: EverlaneColors.muted)),
                                    if (_likeQuote(store, p) case final quote?) ...[
                                      const SizedBox(height: 16),
                                      Text('“$quote”',
                                          style: const TextStyle(
                                              fontSize: 20, height: 1.45)),
                                    ],
                                    const SizedBox(height: 20),
                                    Row(children: [
                                      RoundButton(
                                          icon: Icons.close,
                                          label: 'Remove ${p.name}’s like',
                                          onTap: () => store.removeLike(p)),
                                      const SizedBox(width: 12),
                                      Expanded(
                                          child: FilledButton(
                                              onPressed: () async {
                                                final chat = store.match(p);
                                                final openChat =
                                                    await Navigator.push<bool>(
                                                        context,
                                                        PageRouteBuilder<bool>(
                                                            transitionDuration:
                                                                const Duration(
                                                                    milliseconds:
                                                                        420),
                                                            pageBuilder: (_, __,
                                                                    ___) =>
                                                                MatchCelebration(
                                                                    store: store,
                                                                    person: p),
                                                            transitionsBuilder:
                                                                (context,
                                                                        animation,
                                                                        _,
                                                                        child) =>
                                                                    FadeTransition(
                                                                        opacity:
                                                                            animation,
                                                                        child:
                                                                            child)));
                                                if (openChat == true &&
                                                    context.mounted) {
                                                  Navigator.push(
                                                      context,
                                                      MaterialPageRoute<void>(
                                                          builder: (_) =>
                                                              ChatScreen(
                                                                  store: store,
                                                                  chat: chat)));
                                                }
                                              },
                                              child: const Text(
                                                  'Like back & say hello')))
                                    ]),
                                  ])),
                        ]))),
        if (!store.live)
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
  late int seen = widget.chat.messages.length;

  @override
  void initState() {
    super.initState();
    // Live replies from a real match arrive through the store.
    widget.store.addListener(changed);
  }

  void changed() {
    if (!mounted || widget.chat.messages.length == seen) return;
    seen = widget.chat.messages.length;
    setState(() {});
    toBottom();
  }

  void toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) {
          scroll.animateTo(scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut);
        }
      });

  void send() {
    if (controller.text.trim().isEmpty) return;
    setState(() {
      widget.store.send(widget.chat, controller.text);
      controller.clear();
    });
    toBottom();
  }

  @override
  void dispose() {
    widget.store.removeListener(changed);
    controller.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            // Tapping the name or photo opens their profile.
            title: Semantics(
                button: true,
                label: 'View ${widget.chat.person.name}’s profile',
                child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => PersonDetailsScreen(
                                person: widget.chat.person,
                                store: widget.store,
                                fromChat: true))),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Portrait(widget.chat.person,
                              height: 38, width: 38, radius: 19),
                          const SizedBox(width: 12),
                          Flexible(
                              child: Text(widget.chat.person.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 18))),
                          const SizedBox(width: 6),
                          const Icon(Icons.verified,
                              size: 16, color: EverlaneColors.boost),
                          const SizedBox(width: 8),
                        ])))),
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
                              widget.chat.person.remote
                                  ? 'You matched · Be kind, be yourself'
                                  : 'Demo conversation · Messages stay on this device',
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
                            for (final (i, message)
                                in widget.chat.messages.indexed) ...[
                              if (i == 0 ||
                                  !_sameDay(widget.chat.messages[i - 1].sentAt,
                                      message.sentAt))
                                Padding(
                                    padding: const EdgeInsets.only(
                                        top: 6, bottom: 14),
                                    child: Center(
                                        child: Text(_dayLabel(message.sentAt),
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: EverlaneColors.muted)))),
                              Align(
                                  alignment: message.mine
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Container(
                                      constraints:
                                          const BoxConstraints(maxWidth: 300),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.fromLTRB(
                                          18, 12, 14, 8),
                                      decoration: BoxDecoration(
                                          color: message.mine
                                              ? EverlaneColors.deep
                                              : EverlaneColors.card,
                                          borderRadius:
                                              BorderRadius.circular(18)),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Align(
                                                alignment: Alignment.centerLeft,
                                                widthFactor: 1,
                                                child: Text(message.text,
                                                    style: TextStyle(
                                                        color: message.mine
                                                            ? Colors.white
                                                            : EverlaneColors
                                                                .plum,
                                                        height: 1.5))),
                                            const SizedBox(height: 2),
                                            Text(_clock(message.sentAt),
                                                style: TextStyle(
                                                    fontSize: 10.5,
                                                    color: message.mine
                                                        ? Colors.white
                                                            .withValues(
                                                                alpha: .7)
                                                        : EverlaneColors
                                                            .muted)),
                                          ]))),
                            ],
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

Future<void> confirmDeleteAccount(
    BuildContext context, PreviewStore store) async {
  final confirmed = await showEverlaneSheet<bool>(
      context,
      Builder(
          builder: (context) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Delete your account?',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 12),
                    Text(
                        'This permanently deletes your profile, photos, voice prompt, likes, matches and messages. It can’t be undone.\n\nIf you just need a break, you can take a pause instead and keep your chats.',
                        style: TextStyle(
                            color: EverlaneColors.muted, height: 1.5)),
                    const SizedBox(height: 22),
                    SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                            style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 52),
                                backgroundColor: EverlaneColors.like,
                                foregroundColor: Colors.white,
                                backgroundBuilder: (context, states, child) =>
                                    child!),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete permanently',
                                style:
                                    TextStyle(fontWeight: FontWeight.w700)))),
                    const SizedBox(height: 6),
                    Center(
                        child: TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Keep my account'))),
                    const SizedBox(height: 10),
                  ])));
  if (confirmed != true || !context.mounted) return;
  try {
    await store.deleteAccount();
    if (context.mounted) showNotice(context, 'Your account has been deleted.');
  } catch (_) {
    if (context.mounted) {
      showNotice(context, 'Couldn’t delete your account. Try again.');
    }
  }
}

/// The member's own voice prompt with a way to record or re-record it, or
/// an invitation to add one.
class _MyVoicePrompt extends StatelessWidget {
  const _MyVoicePrompt({required this.store});
  final PreviewStore store;
  @override
  Widget build(BuildContext context) {
    if (!store.hasVoice) {
      return OutlinedButton.icon(
          onPressed: () => recordVoicePrompt(context, store),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
          icon: const Icon(Icons.mic_none_rounded),
          label: const Text('Add a voice prompt'));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      VoicePrompt(
          // A new recording gets a fresh player.
          key: ValueKey(store.myVoice ?? store.myVoiceUrl),
          id: 'me',
          label: store.myVoiceLabel,
          seconds: store.myVoiceSeconds,
          bytes: store.myVoice,
          url: store.myVoiceUrl),
      TextButton.icon(
          onPressed: () => recordVoicePrompt(context, store),
          icon: const Icon(Icons.mic_none_rounded, size: 18),
          label: const Text('Record again')),
    ]);
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// "9:05 PM".
String _clock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// "Today", "Yesterday", "Mon, 26 Oct", or "26 Oct 2025" in another year.
String _dayLabel(DateTime t) {
  final now = DateTime.now();
  if (_sameDay(t, now)) return 'Today';
  if (_sameDay(t, now.subtract(const Duration(days: 1)))) return 'Yesterday';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug',
      'Sep', 'Oct', 'Nov', 'Dec'];
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final date = '${t.day} ${months[t.month - 1]}';
  return t.year == now.year ? '${days[t.weekday - 1]}, $date' : '$date ${t.year}';
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.store});
  final PreviewStore store;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool picking = false;

  Future<void> pick() async {
    if (!widget.store.canAddPhoto || picking) return;
    setState(() => picking = true);
    try {
      final bytes = await pickPhotoBytes();
      if (bytes != null) widget.store.addPhoto(bytes);
    } catch (_) {
      if (mounted) showNotice(context, 'Couldn’t open your photos. Try again.');
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Widget _pill(
          {required IconData icon,
          required String label,
          required VoidCallback? onTap,
          Color? color}) =>
      OutlinedButton.icon(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              side: BorderSide(color: EverlaneColors.line)),
          icon: Icon(icon, size: 18, color: color ?? EverlaneColors.lavender),
          label: Text(label));

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final strength = store.profileCompleteness;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 32), children: [
      if (store.adminWarning.isNotEmpty)
        Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: EverlaneColors.star.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: EverlaneColors.star.withValues(alpha: .5))),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.warning_amber_rounded,
                        color: EverlaneColors.star),
                    SizedBox(width: 8),
                    Text('A note from our team',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 8),
                  Text(store.adminWarning, style: const TextStyle(height: 1.5)),
                  const SizedBox(height: 4),
                  Text(
                      'Repeated issues can lead to a suspension. Our community guidelines apply to profiles and messages.',
                      style: TextStyle(
                          fontSize: 12, color: EverlaneColors.muted)),
                  Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                          onPressed: store.acknowledgeWarning,
                          child: const Text('I understand'))),
                ])),
      Align(
          alignment: Alignment.centerRight,
          child: IconButton(
              tooltip: 'Edit profile',
              onPressed: () => editProfile(context, store),
              style: IconButton.styleFrom(
                  backgroundColor: EverlaneColors.card,
                  side: BorderSide(color: EverlaneColors.line)),
              icon: Icon(Icons.edit_outlined,
                  size: 20, color: EverlaneColors.lavender))),
      // Header: big avatar with a gradient ring and a camera badge.
      Center(
          child: Stack(clipBehavior: Clip.none, children: [
        Container(
            padding: const EdgeInsets.all(3.5),
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: EverlaneColors.premiumGradient,
                boxShadow: [
                  BoxShadow(
                      color: EverlaneColors.deep.withValues(alpha: .45),
                      blurRadius: 28,
                      offset: const Offset(0, 10))
                ]),
            child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: EverlaneColors.paper),
                child: MyAvatar(store: store, size: 122))),
        Positioned(
            right: 0,
            bottom: 4,
            child: DecoratedBox(
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: EverlaneColors.premiumGradient,
                    border: Border.all(color: EverlaneColors.paper, width: 3)),
                child: IconButton(
                    tooltip: 'Add a photo',
                    onPressed: store.canAddPhoto && !picking ? pick : null,
                    icon: picking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.photo_camera_outlined,
                            color: Colors.white, size: 20)))),
      ])),
      const SizedBox(height: 18),
      Center(
          child: Text.rich(
              EverlaneFonts.nameAge(store.myName, store.myAge,
                  size: 32, color: EverlaneColors.plum),
              textAlign: TextAlign.center)),
      const SizedBox(height: 6),
      Center(
          child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 14,
              runSpacing: 4,
              children: [
            if (store.myJob.isNotEmpty)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.work_outline_rounded,
                    size: 16, color: EverlaneColors.muted),
                const SizedBox(width: 5),
                Text(store.myJob,
                    style: TextStyle(color: EverlaneColors.muted, fontSize: 14)),
              ]),
            if (store.myCity.isNotEmpty)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.location_on_outlined,
                    size: 16, color: EverlaneColors.muted),
                const SizedBox(width: 5),
                Text(store.myCity,
                    style: TextStyle(color: EverlaneColors.muted, fontSize: 14)),
              ]),
          ])),
      const SizedBox(height: 10),
      Center(
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: store.myProfilePosted
                      ? EverlaneColors.boost.withValues(alpha: .15)
                      : EverlaneColors.blush,
                  borderRadius: BorderRadius.circular(30)),
              child: Text(
                  store.myProfilePosted
                      ? 'Live in the preview'
                      : 'Draft, not posted',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: store.myProfilePosted
                          ? EverlaneColors.boost
                          : EverlaneColors.like)))),
      const SizedBox(height: 18),
      Center(
          child: SizedBox(
              width: 260,
              child: Column(children: [
                Row(children: [
                  Text('Profile strength',
                      style: TextStyle(fontSize: 13, color: EverlaneColors.muted)),
                  const Spacer(),
                  Text('$strength%',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 8),
                Container(
                    height: 8,
                    decoration: BoxDecoration(
                        color: EverlaneColors.line,
                        borderRadius: BorderRadius.circular(8)),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                        widthFactor: strength / 100,
                        child: Container(
                            decoration: BoxDecoration(
                                gradient: EverlaneColors.premiumGradient,
                                borderRadius: BorderRadius.circular(8))))),
              ]))),
      const SizedBox(height: 18),
      Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
        _pill(
            icon: store.myVerified
                ? Icons.verified_rounded
                : Icons.verified_outlined,
            label: store.myVerified ? 'Verified' : 'Get verified',
            color: store.myVerified ? const Color(0xFF60A5FA) : null,
            onTap: store.myVerified ? null : () => verifyMe(context, store)),
        _pill(
            icon: Icons.visibility_outlined,
            label: 'Preview',
            onTap: () => previewMyProfile(context, store)),
      ]),
      const SizedBox(height: 22),
      Row(children: [
        Expanded(
            child: _StatTile(
                value: '${store.conversations.length}', label: 'Matches')),
        const SizedBox(width: 10),
        Expanded(
            child: _StatTile(
                value: '${store.remaining < 0 ? 0 : store.remaining}',
                label: 'Likes left')),
        const SizedBox(width: 10),
        Expanded(child: _StatTile(value: store.plan.title, label: 'Plan')),
      ]),
      const SizedBox(height: 18),
      _ProfileSection(
          title: 'Photos',
          subtitle:
              'Add up to ${PreviewStore.maxPhotos} photos. Your first photo is the one people see first.',
          children: [
            LayoutBuilder(builder: (context, c) {
              const gap = 10.0;
              final w = (c.maxWidth - gap * 2) / 3;
              return Wrap(spacing: gap, runSpacing: gap, children: [
                for (var i = 0; i < PreviewStore.maxPhotos; i++)
                  SizedBox(
                      width: w,
                      height: w * 1.28,
                      child: i < store.myPhotos.length
                          ? _PhotoSlot(
                              bytes: store.myPhotos[i],
                              isMain: i == 0,
                              onSetMain: i == 0
                                  ? null
                                  : () => store.setMainPhoto(i),
                              onRemove: () => store.removePhoto(i))
                          : _EmptyPhotoSlot(
                              busy: picking && i == store.myPhotos.length,
                              onTap: pick)),
              ]);
            }),
          ]),
      _ProfileSection(
          title: 'About me',
          trailing: IconButton(
              tooltip: 'Edit about me',
              onPressed: () => editProfile(context, store),
              icon: Icon(Icons.edit_outlined,
                  size: 21, color: EverlaneColors.lavender)),
          children: [
            Text('Bio',
                style: TextStyle(fontSize: 12, color: EverlaneColors.muted)),
            const SizedBox(height: 6),
            Text(
                store.myBio.isEmpty
                    ? 'Add a bio so members know who you are.'
                    : store.myBio,
                style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: store.myBio.isEmpty
                        ? EverlaneColors.muted
                        : EverlaneColors.body,
                    fontStyle: store.myBio.isEmpty
                        ? FontStyle.italic
                        : FontStyle.normal)),
            const SizedBox(height: 18),
            Text(store.myPromptLabel,
                style: TextStyle(fontSize: 12, color: EverlaneColors.muted)),
            const SizedBox(height: 6),
            Text(
                store.myPrompt.isEmpty
                    ? 'Add an answer from Edit profile.'
                    : '“${store.myPrompt}”',
                style: GoogleFonts.cormorantGaramond(
                    fontSize: 21,
                    height: 1.35,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    color: EverlaneColors.plum)),
            const SizedBox(height: 18),
            _MyVoicePrompt(store: store),
            const SizedBox(height: 18),
            Text('Interests',
                style: TextStyle(fontSize: 12, color: EverlaneColors.muted)),
            const SizedBox(height: 8),
            if (store.myInterests.isEmpty)
              Text('Pick up to 6 from Edit profile.',
                  style: TextStyle(
                      fontSize: 14,
                      color: EverlaneColors.muted,
                      fontStyle: FontStyle.italic))
            else
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final tag in store.myInterests)
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                          color: EverlaneColors.deep,
                          borderRadius: BorderRadius.circular(30)),
                      child: Text(tag,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500))),
              ]),
            const SizedBox(height: 18),
            Row(children: [
              Icon(Icons.favorite_rounded, size: 16, color: EverlaneColors.like),
              const SizedBox(width: 6),
              Expanded(
                  child: Text('Looking for: ${store.myLookingFor}',
                      style: const TextStyle(fontSize: 13))),
            ]),
            const SizedBox(height: 18),
            GradientButton(
                label: 'Edit profile',
                icon: Icons.edit_outlined,
                onTap: () => editProfile(context, store)),
          ]),
      _MembershipBanner(store: store),
      const SizedBox(height: 12),
      QuizCard(store: store),
      const SizedBox(height: 16),
      _ProfileSection(
          title: 'Privacy & safety',
          icon: Icons.verified_user_outlined,
          iconColor: EverlaneColors.boost,
          subtitle: 'You’re in control of what others see.',
          children: [
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Invisible mode'),
                subtitle: Text('Only people you like can see you',
                    style: TextStyle(fontSize: 12, color: EverlaneColors.muted)),
                value: store.invisible,
                onChanged: (value) {
                  store.invisible = value;
                  store.update();
                }),
            const Divider(height: 1),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Take a pause'),
                subtitle: Text('Keep your chats. Take some time.',
                    style: TextStyle(fontSize: 12, color: EverlaneColors.muted)),
                value: store.paused,
                onChanged: (value) {
                  store.paused = value;
                  store.update();
                }),
            const Divider(height: 1),
            ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('A safer space'),
                subtitle: Text('Tips for meeting safely',
                    style: TextStyle(fontSize: 12, color: EverlaneColors.muted)),
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
          ]),
      if (store.signedIn)
        _ProfileSection(
            title: 'Account',
            icon: Icons.person_outline_rounded,
            iconColor: EverlaneColors.lavender,
            subtitle: store.accountEmail,
            children: [
              if (store.syncError != null) ...[
                Row(children: [
                  const Icon(Icons.cloud_off_rounded,
                      size: 18, color: EverlaneColors.like),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(store.syncError!,
                          style: const TextStyle(
                              fontSize: 13, color: EverlaneColors.like))),
                ]),
                const SizedBox(height: 8),
              ],
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('Log out'),
                  subtitle: Text('Your profile stays saved to your account',
                      style:
                          TextStyle(fontSize: 12, color: EverlaneColors.muted)),
                  onTap: () => store.logOut()),
              const Divider(height: 1),
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_outline_rounded,
                      color: EverlaneColors.like),
                  title: const Text('Delete account',
                      style: TextStyle(color: EverlaneColors.like)),
                  subtitle: Text(
                      'Permanently remove your profile, photos and chats',
                      style:
                          TextStyle(fontSize: 12, color: EverlaneColors.muted)),
                  onTap: () => confirmDeleteAccount(context, store)),
            ]),
      _ProfileSection(
          title: 'Preferences',
          icon: Icons.tune_rounded,
          iconColor: EverlaneColors.lavender,
          children: [
            ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Dating preferences'),
                subtitle: Text('Age, distance and who you see',
                    style: TextStyle(fontSize: 12, color: EverlaneColors.muted)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showFilters(context, store)),
            const Divider(height: 1),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Notifications'),
                subtitle: Text('Preview preference only',
                    style: TextStyle(fontSize: 12, color: EverlaneColors.muted)),
                value: store.notifications,
                onChanged: (value) {
                  store.notifications = value;
                  store.update();
                }),
            const Divider(height: 1),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Dark mode'),
                subtitle: Text('Easier on the eyes at night',
                    style: TextStyle(fontSize: 12, color: EverlaneColors.muted)),
                value: store.darkMode,
                onChanged: (value) {
                  store.darkMode = value;
                  store.update();
                }),
          ]),
      const SizedBox(height: 12),
      const Center(
          child: Icon(Icons.favorite_rounded, size: 24, color: EverlaneColors.like)),
      const SizedBox(height: 8),
      Center(
          child: Text('Made for something real.',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 20,
                  fontStyle: FontStyle.italic,
                  color: EverlaneColors.muted))),
      const SizedBox(height: 6),
      Center(
          child: Text('Everlane · UI preview 0.1',
              style: TextStyle(fontSize: 10, color: EverlaneColors.muted))),
    ]);
  }
}

/// A rounded card section on the profile page, titled in Playfair Display.
class _ProfileSection extends StatelessWidget {
  const _ProfileSection(
      {required this.title,
      required this.children,
      this.subtitle,
      this.icon,
      this.iconColor,
      this.trailing});
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  final List<Widget> children;
  @override
  // A Material (not a decorated Container) so the ListTiles inside can paint
  // their ink splashes.
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
          color: EverlaneColors.card,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(color: EverlaneColors.line)),
          child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
        Row(children: [
          if (icon != null) ...[
            Icon(icon, size: 22, color: iconColor ?? EverlaneColors.lavender),
            const SizedBox(width: 10),
          ],
          Expanded(
              child: Text(title,
                  style: EverlaneFonts.playfair(
                      size: 23,
                      weight: FontWeight.w600,
                      color: EverlaneColors.plum))),
          if (trailing != null) trailing!,
        ]),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!,
              style: TextStyle(
                  fontSize: 13.5, height: 1.45, color: EverlaneColors.muted)),
        ],
        const SizedBox(height: 14),
        ...children,
      ]))));
}

/// A filled slot in the profile photo grid.
class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot(
      {required this.bytes,
      required this.isMain,
      required this.onSetMain,
      required this.onRemove});
  final Uint8List bytes;
  final bool isMain;
  final VoidCallback? onSetMain, onRemove;
  @override
  Widget build(BuildContext context) => ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(fit: StackFit.expand, children: [
        Image.memory(bytes,
            fit: BoxFit.cover,
            errorBuilder: (_, error, stack) => Container(
                color: EverlaneColors.blush,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image_outlined,
                    color: EverlaneColors.like))),
        if (isMain)
          Positioned(
              left: 7,
              top: 7,
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      gradient: EverlaneColors.premiumGradient,
                      borderRadius: BorderRadius.circular(20)),
                  child: const Text('Main',
                      style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.white,
                          fontWeight: FontWeight.w700))))
        else if (onSetMain != null)
          Positioned(
              left: 6,
              right: 6,
              bottom: 6,
              child: Material(
                  color: Colors.black.withValues(alpha: .6),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: onSetMain,
                      child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Text('Make main',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 10.5,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)))))),
        Positioned(
            top: 5,
            right: 5,
            child: Material(
                color: Colors.black.withValues(alpha: .55),
                shape: const CircleBorder(),
                child: IconButton(
                    tooltip: 'Remove photo',
                    iconSize: 15,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                    onPressed: onRemove,
                    icon:
                        const Icon(Icons.close_rounded, color: Colors.white)))),
      ]));
}

/// An empty, dashed-outline slot in the profile photo grid.
class _EmptyPhotoSlot extends StatelessWidget {
  const _EmptyPhotoSlot({required this.busy, required this.onTap});
  final bool busy;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => CustomPaint(
      painter: _DashedRRectPainter(color: EverlaneColors.muted.withValues(alpha: .5)),
      child: Material(
          color: EverlaneColors.paper.withValues(alpha: .4),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: busy ? null : onTap,
              child: Center(
                  child: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(Icons.add_rounded,
                          size: 30, color: EverlaneColors.lavender)))));
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(.7), const Radius.circular(18)));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
        d += 11;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) => old.color != color;
}

/// The user's own photo if they added one from sign-up or Edit profile,
/// otherwise their initial on a blush circle.
class MyAvatar extends StatelessWidget {
  const MyAvatar({super.key, required this.store, this.size = 70});
  final PreviewStore store;
  final double size;
  @override
  Widget build(BuildContext context) => ClipOval(
      child: store.hasPhoto
          ? Image.memory(store.myPhotos.first,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, error, stack) => _initial(context))
          : _initial(context));

  Widget _initial(BuildContext context) => Container(
      width: size,
      height: size,
      decoration:
          BoxDecoration(shape: BoxShape.circle, color: EverlaneColors.blush),
      alignment: Alignment.center,
      child: Text(store.myName.isEmpty ? 'R' : store.myName[0],
          style: TextStyle(fontSize: size * .46, color: EverlaneColors.like)));
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
          color: EverlaneColors.blush.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(14)),
      alignment: Alignment.center,
      child: Column(children: [
        Text(value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: EverlaneColors.muted)),
      ]));
}

/// "This is how members see you" — a read-only look at the profile as it
/// would appear to someone browsing Discover.
Future<void> previewMyProfile(BuildContext context, PreviewStore store) =>
    showEverlaneSheet(
        context,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('This is how members see you.',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 18),
          ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                  aspectRatio: 1,
                  child: store.hasPhoto
                      ? Image.memory(store.myPhotos.first, fit: BoxFit.cover)
                      : Container(
                          color: EverlaneColors.blush,
                          alignment: Alignment.center,
                          child: Text(
                              store.myName.isEmpty ? 'R' : store.myName[0],
                              style: const TextStyle(
                                  fontSize: 64, color: EverlaneColors.like))))),
          const SizedBox(height: 14),
          Text('${store.myName}, ${store.myAge}',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 2),
          Text('Member', style: TextStyle(color: EverlaneColors.muted)),
          const SizedBox(height: 8),
          Row(children: [
            if (store.myCity.isNotEmpty) ...[
              Icon(Icons.place_outlined, size: 15, color: EverlaneColors.muted),
              const SizedBox(width: 4),
              Text('${store.myCity} · Nearby',
                  style: TextStyle(fontSize: 12, color: EverlaneColors.muted)),
              const SizedBox(width: 14),
            ],
            const Icon(Icons.favorite_rounded, size: 14, color: EverlaneColors.like),
            const SizedBox(width: 4),
            Text(store.myLookingFor, style: const TextStyle(fontSize: 12)),
          ]),
          const SizedBox(height: 14),
          Text(store.myBio.isEmpty ? 'No bio yet.' : store.myBio,
              style: TextStyle(
                  color: store.myBio.isEmpty
                      ? EverlaneColors.muted
                      : EverlaneColors.plum,
                  height: 1.5)),
          const SizedBox(height: 20),
          OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              child: const Text('Close')),
        ]));

/// A demo-only verification: a real app would ask for a selfie and match it
/// against your photos. Here, confirming is enough to flip the badge on.
Future<void> verifyMe(BuildContext context, PreviewStore store) async {
  final confirmed = await showEverlaneSheet<bool>(
      context,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Verify your profile', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 14),
        Text(
            'In the real app, we’d ask you to match a quick selfie to your photos so people know you’re really you. This preview skips the camera step.',
            style: TextStyle(color: EverlaneColors.muted, height: 1.5)),
        const SizedBox(height: 20),
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: EverlaneColors.like),
            child: const Text('Verify now (preview)')),
        const SizedBox(height: 8),
        Center(
            child: TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not now'))),
      ]));
  if (confirmed == true) {
    store.myVerified = true;
    store.update();
    store.saveProfile();
    if (context.mounted) showNotice(context, 'Profile verified in this preview.');
  }
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
  late final age = TextEditingController(text: '${widget.store.myAge}');
  late final job = TextEditingController(text: widget.store.myJob);
  late final city = TextEditingController(text: widget.store.myCity);
  late final bio = TextEditingController(text: widget.store.myBio);
  late final promptAnswer = TextEditingController(text: widget.store.myPrompt);
  late final customInterest = TextEditingController();
  late String lookingFor = widget.store.myLookingFor;
  late String promptLabel = widget.store.myPromptLabel;
  late final interests = <String>{...widget.store.myInterests};
  bool picking = false;
  final key = GlobalKey<FormState>();

  @override
  void dispose() {
    name.dispose();
    age.dispose();
    job.dispose();
    city.dispose();
    bio.dispose();
    promptAnswer.dispose();
    customInterest.dispose();
    super.dispose();
  }

  Future<void> pickPhoto() async {
    setState(() => picking = true);
    try {
      final bytes = await pickPhotoBytes();
      if (bytes != null) widget.store.addPhoto(bytes);
    } catch (_) {
      if (mounted) showNotice(context, 'Couldn’t open your photos. Try again.');
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  void toggleInterest(String tag) => setState(() {
        if (interests.contains(tag)) {
          interests.remove(tag);
        } else if (interests.length < 6) {
          interests.add(tag);
        }
      });

  void addCustomInterest(String value) {
    final v = value.trim();
    if (v.isEmpty) return;
    if (interests.length < 6) setState(() => interests.add(v));
    customInterest.clear();
  }

  void save({required bool post}) {
    if (!key.currentState!.validate()) return;
    final store = widget.store;
    final parsedAge = int.tryParse(age.text.trim());
    store.myName = name.text.trim();
    store.myJob = job.text.trim();
    store.myCity = city.text.trim();
    store.myBio = bio.text.trim();
    store.myLookingFor = lookingFor;
    store.myPromptLabel = promptLabel;
    store.myPrompt = promptAnswer.text.trim();
    store.myInterests
      ..clear()
      ..addAll(interests);
    if (parsedAge != null && parsedAge >= 18) {
      final now = DateTime.now();
      store.myBirthday = DateTime(now.year - parsedAge, now.month, now.day);
    }
    if (post) store.myProfilePosted = true;
    store.update();
    store.saveProfile();
    Navigator.pop(context);
    showNotice(
        context, post ? 'Profile posted in this preview.' : 'Draft saved.');
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Form(
        key: key,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Edit profile', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 20),
          const Text('Photos', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
              store.myPhotos.length > 1
                  ? 'Tap “Make main” on a photo to lead with it.'
                  : 'Add a few photos — the first one is what people see first.',
              style: TextStyle(fontSize: 12, color: EverlaneColors.muted)),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (var i = 0; i < store.myPhotos.length; i++)
              PhotoTile(
                  bytes: store.myPhotos[i],
                  isMain: i == 0,
                  onSetMain: store.myPhotos.length > 1 && i != 0
                      ? () => setState(() => store.setMainPhoto(i))
                      : null,
                  onRemove: () => setState(() => store.removePhoto(i))),
            if (store.canAddPhoto)
              AddPhotoTile(busy: picking, onTap: pickPhoto),
          ]),
          const SizedBox(height: 18),
          TextFormField(
              controller: name,
              maxLength: 40,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Add your first name' : null),
          const SizedBox(height: 12),
          TextFormField(
              controller: age,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Age'),
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                return n == null || n < 18 ? 'Enter an age of 18 or over' : null;
              }),
          const SizedBox(height: 12),
          TextFormField(
              controller: job,
              maxLength: 80,
              decoration: const InputDecoration(
                  labelText: 'Profession',
                  hintText: 'For example, Product designer')),
          const SizedBox(height: 12),
          TextFormField(
              controller: city,
              decoration: const InputDecoration(labelText: 'Area or city')),
          const SizedBox(height: 12),
          TextFormField(
              controller: bio,
              maxLength: 200,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'About you', hintText: 'Share what makes you, you')),
          const SizedBox(height: 18),
          const Text('Looking for', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final option in PreviewStore.lookingForOptions)
              ChoiceChip(
                  label: Text(option),
                  selected: lookingFor == option,
                  showCheckmark: false,
                  selectedColor: EverlaneColors.deep,
                  backgroundColor: EverlaneColors.card,
                  side: BorderSide(
                      color: lookingFor == option
                          ? EverlaneColors.deep
                          : EverlaneColors.line),
                  labelStyle: TextStyle(
                      color: lookingFor == option
                          ? Colors.white
                          : EverlaneColors.plum),
                  onSelected: (_) => setState(() => lookingFor = option)),
          ]),
          const SizedBox(height: 18),
          const Text('Interests (choose up to 6)',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final tag in {...PreviewStore.interestOptions, ...interests})
              FilterChip(
                  label: Text(tag),
                  selected: interests.contains(tag),
                  showCheckmark: false,
                  selectedColor: EverlaneColors.deep,
                  backgroundColor: EverlaneColors.card,
                  side: BorderSide(
                      color: interests.contains(tag)
                          ? EverlaneColors.deep
                          : EverlaneColors.line),
                  labelStyle: TextStyle(
                      color: interests.contains(tag)
                          ? Colors.white
                          : EverlaneColors.plum),
                  onSelected: (_) => toggleInterest(tag)),
          ]),
          const SizedBox(height: 10),
          TextField(
              controller: customInterest,
              decoration: const InputDecoration(
                  labelText: 'Add your own, then press Enter'),
              onSubmitted: addCustomInterest),
          const SizedBox(height: 18),
          const Text('Prompt', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
              initialValue: promptLabel,
              isExpanded: true,
              decoration: const InputDecoration(),
              items: [
                // The member's current prompt stays selectable even if an
                // admin has since retired it.
                for (final option in {...PreviewStore.promptOptions, promptLabel})
                  DropdownMenuItem(value: option, child: Text(option)),
              ],
              onChanged: (v) => setState(() => promptLabel = v ?? promptLabel)),
          const SizedBox(height: 10),
          TextFormField(
              controller: promptAnswer,
              maxLength: 250,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Your answer'),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Tell us a little about this'
                  : null),
          const SizedBox(height: 8),
          const Text('Voice prompt',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ListenableBuilder(
              listenable: store,
              builder: (context, _) => _MyVoicePrompt(store: store)),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
                child: OutlinedButton(
                    onPressed: () => save(post: false),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                    child: const Text('Save draft'))),
            const SizedBox(width: 12),
            Expanded(
                child: GradientButton(
                    label: 'Post profile', onTap: () => save(post: true))),
          ]),
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
          Text(person.remote && store.signedIn
              ? 'Our moderation team will review your report. ${person.name} won’t know who reported them, and you won’t see each other again.'
              : 'This preview hides the profile locally. It does not submit a report to a moderation team.'),
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
  final reported = action == 'report' && person.remote && store.signedIn;
  if (reported) await store.report(person, reason!);
  if (!context.mounted) return;
  store.forgetRemotely(person);
  store.passed.add(person.id);
  store.incoming.removeWhere((p) => p.id == person.id);
  store.conversations.removeWhere((c) => c.person.id == person.id);
  store.update();
  if (chat != null) Navigator.pop(context);
  showNotice(
      context,
      reported
          ? 'Thanks for telling us. We’ll review your report.'
          : action == 'report'
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
                                ? 'Explore membership'
                                : '${store.plan.title} member',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color:
                                    free ? Colors.white : EverlaneColors.plum)),
                        const SizedBox(height: 3),
                        Text(
                            free
                                ? 'Plus, Gold and Platinum'
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
                    'Blocking, reporting, privacy controls and account deletion are free on every plan. Paid plans add convenience and discovery; none can promise a match.',
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
                const SizedBox(height: 8),
                Text(
                    'Prices are test prices for launch. Before purchase you’ll see the renewal period, total charge and how to cancel.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 11, color: EverlaneColors.muted)),
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
          if (plan == Plan.gold)
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
        Text.rich(TextSpan(children: [
          TextSpan(
              text: plan.price,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: EverlaneColors.star)),
          TextSpan(
              text: plan == Plan.free ? '  forever free' : '  per month',
              style: TextStyle(fontSize: 13, color: EverlaneColors.muted)),
        ])),
        const SizedBox(height: 4),
        Text(plan.tagline,
            style: TextStyle(fontSize: 13, color: EverlaneColors.muted)),
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
        if (plan != Plan.free) ...[
          const SizedBox(height: 8),
          Text(
              'Renews monthly at ${plan.price} until you cancel. Cancel anytime.',
              style: TextStyle(fontSize: 11, color: EverlaneColors.muted)),
        ],
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

void showOutOfLikes(BuildContext context, PreviewStore store) {
  final next =
      store.plan == Plan.platinum ? null : Plan.values[store.plan.index + 1];
  showUpgrade(context, store,
      title: 'You’ve used today’s ${store.plan.dailyLikes} likes.',
      detail: next == null
          ? 'Your likes refresh tomorrow. Take a breather; the right people will still be here.'
          : 'Your likes refresh tomorrow, or ${next.title} gives you ${next.dailyLikes} a day.');
}

/// A timed boost from the monthly allowance (Gold and Platinum), with the
/// start, end and what it can't promise stated plainly.
void showBoost(BuildContext context, PreviewStore store) {
  if (store.plan.monthlyBoosts == 0) {
    showUpgrade(context, store,
        title: 'Be seen by more people nearby.',
        detail:
            'A boost shows your profile to more people for ${PreviewStore.boostLength.inMinutes} minutes. Gold includes 2 a month and Platinum 5.');
    return;
  }
  showEverlaneSheet(
      context,
      ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final ends = store.boostEndsAt;
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                          color: EverlaneColors.boost,
                          borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.bolt_rounded,
                          color: Colors.white, size: 28)),
                  const SizedBox(height: 20),
                  Text(
                      store.boosting
                          ? 'You’re boosted until ${TimeOfDay.fromDateTime(ends!).format(context)}.'
                          : 'Boost your profile',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 10),
                  Text(
                      'More people nearby see you for ${PreviewStore.boostLength.inMinutes} minutes. More visibility doesn’t guarantee likes or matches.',
                      style:
                          TextStyle(color: EverlaneColors.muted, height: 1.6)),
                  const SizedBox(height: 14),
                  Text(
                      '${store.boostsLeft} of ${store.plan.monthlyBoosts} boosts left this month',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 22),
                  FilledButton(
                      onPressed: store.boosting || store.boostsLeft <= 0
                          ? null
                          : store.startBoost,
                      style: FilledButton.styleFrom(
                          backgroundColor: EverlaneColors.boost),
                      child: Text(store.boosting
                          ? 'Boost active'
                          : store.boostsLeft <= 0
                              ? 'No boosts left this month'
                              : 'Start a ${PreviewStore.boostLength.inMinutes}-minute boost')),
                  const SizedBox(height: 8),
                ]);
          }));
}

/// "Liked your photo" / "Liked your answer to …" for an incoming like.
String _likedWhat(SentLike? note) => switch (note?.target) {
      null => 'Liked your answer to “My ideal Sunday”',
      'photo' || 'profile' => 'Liked your photo',
      'soundtrack' => 'Liked your soundtrack',
      final t => 'Liked your answer to “$t”',
    };

/// The comment a real member sent with their like, or the demo line.
String? _likeQuote(PreviewStore store, Person p) {
  final note = store.likeNotes[p.id];
  if (note != null) return note.comment.isEmpty ? null : note.comment;
  return p.remote
      ? null
      : 'I know just the place. Coffee and a bookstore sounds like a pretty perfect start.';
}
