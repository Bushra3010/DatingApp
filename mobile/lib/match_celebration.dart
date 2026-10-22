import 'dart:math';

import 'package:flutter/material.dart';
import 'models.dart';
import 'screens.dart' show MyAvatar;
import 'theme.dart';
import 'widgets.dart';

/// A full-screen "it's a match" moment: gradient background, floating
/// hearts, both photos, and a choice to jump into the chat or keep
/// exploring. The match itself (the conversation) already exists in the
/// store by the time this shows — this is just the celebration.
class MatchCelebration extends StatefulWidget {
  const MatchCelebration({super.key, required this.store, required this.person});
  final PreviewStore store;
  final Person person;
  @override
  State<MatchCelebration> createState() => _MatchCelebrationState();
}

class _MatchCelebrationState extends State<MatchCelebration>
    with SingleTickerProviderStateMixin {
  late final controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))
        ..repeat();
  late final hearts = List.generate(
      12,
      (i) => _Heart(
          left: Random(i * 7 + 1).nextDouble(),
          delay: Random(i * 13 + 2).nextDouble(),
          size: 16 + Random(i * 19 + 3).nextDouble() * 20));

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Widget _photo(Widget child) => Container(
      width: 108,
      height: 108,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 16, offset: Offset(0, 6))
          ]),
      child: ClipOval(child: child));

  @override
  Widget build(BuildContext context) {
    final p = widget.person;
    final size = MediaQuery.sizeOf(context);
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) Navigator.pop(context, false);
        },
        child: Scaffold(
            body: DecoratedBox(
                decoration:
                    const BoxDecoration(gradient: EverlaneColors.premiumGradient),
                child: Stack(children: [
                  for (final h in hearts)
                    AnimatedBuilder(
                        animation: controller,
                        builder: (context, _) {
                          final t = (controller.value + h.delay) % 1.0;
                          return Positioned(
                              left: h.left * size.width,
                              bottom: t * (size.height + 80) - 40,
                              child: Opacity(
                                  opacity: (1 - t) * .75,
                                  child: Icon(Icons.favorite_rounded,
                                      color: Colors.white, size: h.size)));
                        }),
                  SafeArea(
                      child: Center(
                          child: Padding(
                              padding: const EdgeInsets.all(28),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                        height: 132,
                                        child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Positioned(
                                                  left: 6,
                                                  child: _photo(MyAvatar(
                                                      store: widget.store,
                                                      size: 108))),
                                              Positioned(
                                                  right: 6,
                                                  child: _photo(Portrait(p,
                                                      width: 108, height: 108))),
                                              Container(
                                                  width: 44,
                                                  height: 44,
                                                  decoration: const BoxDecoration(
                                                      color: Colors.white,
                                                      shape: BoxShape.circle),
                                                  alignment: Alignment.center,
                                                  child: const Icon(
                                                      Icons.favorite_rounded,
                                                      color: EverlaneColors.like,
                                                      size: 24)),
                                            ])),
                                    const SizedBox(height: 30),
                                    Text('It’s a match!',
                                        style: EverlaneFonts.playfair(
                                            size: 38, weight: FontWeight.w700)),
                                    const SizedBox(height: 10),
                                    Text(
                                        'You and ${p.name} liked each other.',
                                        textAlign: TextAlign.center,
                                        style: EverlaneFonts.inter(
                                            size: 15,
                                            height: 1.5,
                                            color: Colors.white)),
                                    const SizedBox(height: 40),
                                    SizedBox(
                                        width: double.infinity,
                                        child: FilledButton(
                                            style: FilledButton.styleFrom(
                                                backgroundColor: Colors.white,
                                                foregroundColor:
                                                    EverlaneColors.deep,
                                                minimumSize:
                                                    const Size(0, 56)),
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Start chatting',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.w700)))),
                                    const SizedBox(height: 10),
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Keep exploring',
                                            style:
                                                TextStyle(color: Colors.white))),
                                  ])))),
                ]))));
  }
}

class _Heart {
  _Heart({required this.left, required this.delay, required this.size});
  final double left, delay, size;
}
