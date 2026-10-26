import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'theme.dart';

/// One row of the side menu: a glass pill with a glowing gradient icon.
class SideMenuItem {
  const SideMenuItem(this.icon, this.title, this.colors, this.onTap,
      {this.badge});
  final IconData icon;
  final String title;

  /// Top-left to bottom-right fill of the icon; the last colour is its glow.
  final List<Color> colors;
  final VoidCallback onTap;

  /// Shown as an outlined pill on the right; the row glows when set.
  final int? badge;
}

/// The profile side menu: a frosted panel with the member's orb, glass
/// menu pills and the wordmark at the foot.
class SideMenu extends StatelessWidget {
  const SideMenu(
      {super.key,
      required this.name,
      required this.age,
      required this.location,
      required this.items});
  final String name;
  final int age;
  final String location;
  final List<SideMenuItem> items;

  static const _radius = BorderRadius.only(
      topRight: Radius.circular(28), bottomRight: Radius.circular(28));

  @override
  Widget build(BuildContext context) => Drawer(
      width: 310,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: _radius),
      child: ClipRRect(
          borderRadius: _radius,
          child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      borderRadius: _radius,
                      gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            EverlaneColors.paper.withValues(alpha: .82),
                            EverlaneColors.paper.withValues(alpha: .9),
                          ]),
                      border: Border.all(
                          color:
                              EverlaneColors.lavender.withValues(alpha: .14))),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Header(name: name, age: age, location: location),
                        Expanded(
                            child: Stack(children: [
                          ListView(
                              padding:
                                  const EdgeInsets.fromLTRB(18, 28, 18, 12),
                              children: [
                                for (final item in items)
                                  Padding(
                                      padding: const EdgeInsets.only(bottom: 13),
                                      child: _Stacked(
                                          layers: (item.badge ?? 0) - 1,
                                          child: _Pill(item: item))),
                              ]),
                          const Positioned(
                              left: 22, top: 6, child: _Sparkle(size: 11)),
                          const Positioned(
                              right: 8, top: 10, child: _Sparkle(size: 14)),
                          const Positioned(
                              right: 36, top: 352, child: _Sparkle(size: 13)),
                        ])),
                        _Footer(),
                      ])))));
}

class _Header extends StatelessWidget {
  const _Header(
      {required this.name, required this.age, required this.location});
  final String name;
  final int age;
  final String location;

  @override
  Widget build(BuildContext context) => Container(
      padding: EdgeInsets.fromLTRB(
          30, MediaQuery.paddingOf(context).top + 40, 24, 30),
      decoration: BoxDecoration(
          borderRadius:
              const BorderRadius.only(bottomRight: Radius.circular(28)),
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                EverlaneColors.deep.withValues(alpha: .32),
                EverlaneColors.deep.withValues(alpha: .08),
              ]),
          // The glowing pink rule under the header.
          border: const Border(
              bottom: BorderSide(color: Color(0xFFD946EF), width: 1.4)),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFD946EF).withValues(alpha: .35),
                blurRadius: 18,
                offset: const Offset(0, 6),
                spreadRadius: -8),
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _Orb(letter: name.isEmpty ? 'E' : name[0].toUpperCase()),
        const SizedBox(height: 18),
        Text('$name, $age',
            style: EverlaneFonts.inter(size: 30, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(location,
            style: EverlaneFonts.inter(
                size: 16, color: const Color(0xFFB794F6))),
      ]));
}

/// The member's initial in a glass sphere, with the amber "online" dot.
class _Orb extends StatelessWidget {
  const _Orb({required this.letter});
  final String letter;

  @override
  Widget build(BuildContext context) =>
      Stack(clipBehavior: Clip.none, children: [
        Container(
            width: 88,
            height: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                    center: Alignment(-.35, -.45),
                    radius: .95,
                    colors: [
                      Color(0xFF9F7AEA),
                      Color(0xFF5B34A8),
                      Color(0xFF2A1650)
                    ],
                    stops: [0, .55, 1]),
                border: Border.all(
                    color: EverlaneColors.lavender.withValues(alpha: .55),
                    width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: EverlaneColors.deep.withValues(alpha: .6),
                      blurRadius: 26,
                      spreadRadius: 1),
                ]),
            child: Text(letter,
                style: EverlaneFonts.logo(size: 40, color: Colors.white)
                    .copyWith(shadows: [
                  Shadow(
                      color: EverlaneColors.lavender.withValues(alpha: .9),
                      blurRadius: 12)
                ]))),
        // Glass highlight across the top of the sphere.
        Positioned(
            left: 16,
            top: 8,
            child: Container(
                width: 46,
                height: 20,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: .35),
                          Colors.white.withValues(alpha: 0)
                        ])))),
        Positioned(
            right: -4,
            top: -4,
            child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                        center: Alignment(-.3, -.3),
                        colors: [Color(0xFFFFC266), Color(0xFFF59E0B)]),
                    boxShadow: [
                      BoxShadow(
                          color: EverlaneColors.star.withValues(alpha: .7),
                          blurRadius: 12)
                    ]))),
      ]);
}

/// One card edge peeks out above the pill for each extra like (up to two),
/// so a pile of likes reads as a stack.
class _Stacked extends StatelessWidget {
  const _Stacked({required this.layers, required this.child});
  final int layers;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final count = layers.clamp(0, 2);
    if (count == 0) return child;
    Widget card(int depth) => Positioned(
        key: ValueKey('stack-card-$depth'),
        left: 14.0 * depth,
        right: 14.0 * depth,
        top: -7.0 * depth,
        height: 64,
        child: DecoratedBox(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                color: Color.alphaBlend(
                    EverlaneColors.like.withValues(alpha: .10 / depth),
                    EverlaneColors.card),
                border: Border.all(
                    color: EverlaneColors.like.withValues(alpha: .4 / depth)))));
    return Padding(
        padding: EdgeInsets.only(top: 7.0 * count),
        child: Stack(clipBehavior: Clip.none, children: [
          for (var depth = count; depth >= 1; depth--) card(depth),
          // Solid backing so the cards behind don't show through the glass.
          Positioned.fill(
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      color: EverlaneColors.paper))),
          child,
        ]));
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.item});
  final SideMenuItem item;

  @override
  Widget build(BuildContext context) {
    final highlighted = item.badge != null;
    return Material(
        color: Colors.transparent,
        child: InkWell(
            borderRadius: BorderRadius.circular(32),
            onTap: item.onTap,
            child: Ink(
                height: 64,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          EverlaneColors.plum.withValues(alpha: .09),
                          EverlaneColors.plum.withValues(alpha: .03),
                        ]),
                    border: Border.all(
                        color: highlighted
                            ? EverlaneColors.like.withValues(alpha: .55)
                            : EverlaneColors.plum.withValues(alpha: .16),
                        width: 1.2),
                    boxShadow: highlighted
                        ? [
                            BoxShadow(
                                color:
                                    EverlaneColors.like.withValues(alpha: .28),
                                blurRadius: 18,
                                spreadRadius: -4)
                          ]
                        : null),
                padding: const EdgeInsets.only(left: 12, right: 16),
                child: Row(children: [
                  _GlowIcon(icon: item.icon, colors: item.colors),
                  const SizedBox(width: 18),
                  Expanded(
                      child: Text(item.title,
                          overflow: TextOverflow.ellipsis,
                          style: EverlaneFonts.inter(
                              size: 18, weight: FontWeight.w500))),
                  if (highlighted)
                    Container(
                        constraints: const BoxConstraints(minWidth: 32),
                        height: 24,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: EverlaneColors.like, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                  color: EverlaneColors.like
                                      .withValues(alpha: .35),
                                  blurRadius: 8)
                            ]),
                        child: Text('${item.badge}',
                            style: EverlaneFonts.inter(
                                size: 13,
                                weight: FontWeight.w600,
                                color: EverlaneColors.like))),
                ]))));
  }
}

/// An icon filled with a gradient and lit from behind by its own colour.
class _GlowIcon extends StatelessWidget {
  const _GlowIcon({required this.icon, required this.colors});
  final IconData icon;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) => Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
        BoxShadow(
            color: colors.last.withValues(alpha: .45),
            blurRadius: 16,
            spreadRadius: -2)
      ]),
      child: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors)
              .createShader(bounds),
          child: Icon(icon, size: 36)));
}

class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.fromLTRB(
          30, 12, 24, MediaQuery.paddingOf(context).bottom + 26),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Flexible(
            child: Text('Everlane',
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: EverlaneFonts.logo(size: 32).copyWith(shadows: [
              Shadow(
                  color: EverlaneColors.lavender.withValues(alpha: .8),
                  blurRadius: 14),
              Shadow(
                  color: EverlaneColors.deep.withValues(alpha: .9),
                  blurRadius: 28),
            ]))),
        const Padding(
            padding: EdgeInsets.only(left: 2), child: _Sparkle(size: 14)),
      ]));
}

/// A four-pointed twinkle.
class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _SparklePainter());
}

class _SparklePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final w = r * .22;
    final star = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + w, c.dy - w, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + w, c.dy + w, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - w, c.dy + w, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - w, c.dy - w, c.dx, c.dy - r)
      ..close();
    canvas
      ..drawPath(
          star,
          Paint()
            ..color = EverlaneColors.lavender.withValues(alpha: .8)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3))
      ..drawPath(star, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) => false;
}
