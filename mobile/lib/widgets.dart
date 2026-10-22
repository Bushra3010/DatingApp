import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'models.dart';
import 'theme.dart';

class Portrait extends StatelessWidget {
  const Portrait(this.person,
      {super.key, this.height, this.width, this.radius = 22});
  final Person person;
  final double? height, width;
  final double radius;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          'assets/images/${person.id}.jpg',
          height: height,
          width: width,
          fit: BoxFit.cover,
          errorBuilder: (_, error, stack) => Container(
              height: height,
              width: width,
              color: EverlaneColors.blush,
              alignment: Alignment.center,
              child: Text(person.name[0],
                  style: const TextStyle(
                      fontFamily: 'Lora',
                      fontSize: 64,
                      color: EverlaneColors.like))),
        ),
      );
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color});
  final String text;

  /// Defaults to muted.
  final Color? color;
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: TextStyle(
          fontSize: 10,
          letterSpacing: 2,
          fontWeight: FontWeight.w700,
          color: color ?? EverlaneColors.muted));
}

class Tag extends StatelessWidget {
  const Tag(this.icon, this.text, {super.key});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
            color: EverlaneColors.card.withValues(alpha: .7),
            border: Border.all(color: EverlaneColors.line),
            borderRadius: BorderRadius.circular(30)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: EverlaneColors.muted),
          const SizedBox(width: 6),
          Flexible(child: Text(text, style: const TextStyle(fontSize: 11)))
        ]),
      );
}

class RoundButton extends StatelessWidget {
  const RoundButton(
      {super.key,
      required this.icon,
      required this.label,
      required this.onTap,
      this.filled = false,
      this.size = 48});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: size,
      height: size,
      child: IconButton(
        tooltip: label,
        onPressed: onTap,
        icon: Icon(icon, size: 23),
        style: IconButton.styleFrom(
            backgroundColor: filled ? EverlaneColors.like : EverlaneColors.card,
            foregroundColor: filled ? Colors.white : EverlaneColors.plum,
            side: filled ? null : BorderSide(color: EverlaneColors.line)),
      ));
}

/// A purple-to-pink gradient pill with a soft glow, for the hero calls to
/// action (Get started, Post profile, Start chatting…).
class GradientButton extends StatelessWidget {
  const GradientButton(
      {super.key, required this.label, required this.onTap, this.icon});
  final String label;
  final IconData? icon;

  /// Null shows the button faded and disabled.
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => DecoratedBox(
      decoration: BoxDecoration(
          gradient: EverlaneColors.premiumGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (onTap != null)
              BoxShadow(
                  color: EverlaneColors.deep.withValues(alpha: .5),
                  blurRadius: 22,
                  offset: const Offset(0, 10))
          ]),
      child: Material(
          type: MaterialType.transparency,
          child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Opacity(
                  opacity: onTap == null ? .45 : 1,
                  child: Container(
                      height: 54,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (icon != null) ...[
                              Icon(icon, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                                child: Text(label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700))),
                          ]))))));
}

/// One photo in an editable gallery grid (sign-up and Edit profile share
/// this): a thumbnail, a remove button, and — when there's more than one
/// photo — a badge for the main photo or a tap target to make this one main.
class PhotoTile extends StatelessWidget {
  const PhotoTile(
      {super.key,
      required this.bytes,
      required this.onRemove,
      this.isMain = false,
      this.onSetMain});
  final Uint8List bytes;
  final VoidCallback onRemove;
  final bool isMain;

  /// Null hides the "Make main" affordance (e.g. only one photo).
  final VoidCallback? onSetMain;

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
        if (isMain)
          Positioned(
              left: 5,
              bottom: 5,
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: const BoxDecoration(
                      gradient: EverlaneColors.premiumGradient,
                      borderRadius: BorderRadius.all(Radius.circular(20))),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.star_rounded, size: 11, color: Colors.white),
                    SizedBox(width: 3),
                    Text('Main',
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                  ])))
        else if (onSetMain != null)
          Positioned(
              left: 5,
              bottom: 5,
              child: Material(
                  color: Colors.black.withValues(alpha: .6),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: onSetMain,
                      child: const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          child: Text('Make main',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)))))),
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

/// The "add another photo" tile at the end of a [PhotoTile] grid.
class AddPhotoTile extends StatelessWidget {
  const AddPhotoTile({super.key, required this.busy, required this.onTap});
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

class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key,
      required this.icon,
      required this.title,
      required this.detail,
      this.action});
  final IconData icon;
  final String title, detail;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: EverlaneColors.blush, shape: BoxShape.circle),
            child: Icon(icon, size: 38, color: EverlaneColors.like)),
        const SizedBox(height: 24),
        Text(title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text(detail,
            textAlign: TextAlign.center,
            style: TextStyle(color: EverlaneColors.muted, height: 1.6)),
        if (action != null) ...[const SizedBox(height: 24), action!],
      ]));
}

void showNotice(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

Future<T?> showEverlaneSheet<T>(BuildContext context, Widget child) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: EverlaneColors.paper,
      builder: (context) => SafeArea(
          child: Padding(
              padding: EdgeInsets.fromLTRB(
                  24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
              child: SingleChildScrollView(child: child))),
    );

class PastelAction extends StatelessWidget {
  const PastelAction(
      {super.key,
      required this.icon,
      required this.label,
      required this.color,
      required this.size,
      required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final double size;

  /// Null shows the button faded and disabled.
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: onTap == null ? color.withValues(alpha: .3) : color,
            boxShadow: [
              if (onTap != null)
                BoxShadow(
                    color: color.withValues(alpha: .22),
                    blurRadius: 16,
                    offset: const Offset(0, 7))
            ]),
        child: IconButton(
            tooltip: label,
            onPressed: onTap,
            icon: Icon(icon, color: Colors.white, size: size * .48)),
      );
}

/// Slow fade-and-rise, like turning to the next page of a magazine.
Route<T> editorialRoute<T>(WidgetBuilder builder) => PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 560),
    reverseTransitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (context, _, __) => builder(context),
    transitionsBuilder: (context, animation, _, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
          opacity: curved,
          child: SlideTransition(
              position: Tween(begin: const Offset(0, .04), end: Offset.zero)
                  .animate(curved),
              child: child));
    });

/// A small frosted chip laid over a photo to invite a specific reply.
class PhotoPrompt extends StatelessWidget {
  const PhotoPrompt(
      {super.key, required this.icon, required this.text, required this.onTap});
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
      color: Colors.black.withValues(alpha: .38),
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Flexible(
                    child: Text(text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600))),
              ]))));
}

/// A voice prompt drawn as a thin waveform. The preview has no audio files,
/// so playing only animates the waveform over the clip's length.
class VoicePrompt extends StatefulWidget {
  const VoicePrompt({super.key, required this.person});
  final Person person;
  @override
  State<VoicePrompt> createState() => _VoicePromptState();
}

class _VoicePromptState extends State<VoicePrompt>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
      vsync: this, duration: Duration(seconds: widget.person.voiceSeconds))
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.reset();
        setState(() {});
      }
    });

  /// Bar heights, stable per person.
  late final bars = List.generate(36, (i) {
    final seed = widget.person.id.codeUnitAt(i % widget.person.id.length);
    return .25 + ((seed * (i + 7)) % 11) / 14;
  });

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 16, 14),
      decoration: BoxDecoration(
          color: EverlaneColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: EverlaneColors.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconButton(
              tooltip: controller.isAnimating
                  ? 'Pause voice prompt'
                  : 'Play voice prompt',
              onPressed: () {
                if (controller.isAnimating) {
                  controller.stop();
                } else {
                  controller.forward();
                }
                setState(() {});
              },
              style: IconButton.styleFrom(
                  backgroundColor: EverlaneColors.like,
                  foregroundColor: Colors.white),
              icon: Icon(controller.isAnimating
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded)),
          const SizedBox(width: 10),
          Expanded(
              child: SizedBox(
                  height: 34,
                  child: AnimatedBuilder(
                      animation: controller,
                      builder: (context, _) => Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                for (var i = 0; i < bars.length; i++)
                                  Expanded(
                                      child: Center(
                                          child: Container(
                                              width: 2,
                                              height: 34 * bars[i],
                                              decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(2),
                                                  color: i / bars.length <
                                                          controller.value
                                                      ? EverlaneColors.like
                                                      : EverlaneColors.line)))),
                              ])))),
          const SizedBox(width: 10),
          Text('0:${widget.person.voiceSeconds.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 12, color: EverlaneColors.muted)),
        ]),
        Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 0, 0),
            child: Text('“${widget.person.voicePrompt}”',
                style: const TextStyle(
                    fontSize: 14, fontStyle: FontStyle.italic, height: 1.5))),
      ]));
}
