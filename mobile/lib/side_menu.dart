import 'package:flutter/material.dart';
import 'theme.dart';

class SideMenuItem {
  const SideMenuItem(this.icon, this.title, this.subtitle, this.color,
      this.onTap,
      {this.badge});

  /// Drawn inside the round icon disc, in [color].
  final Widget icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;

  /// A count shown beside the arrow when above zero (new likes).
  final int? badge;
}

/// Warm, dark drawer: the member's photo and name on top, a list of
/// sections with a line of explanation each, and the wordmark below.
class SideMenu extends StatelessWidget {
  const SideMenu(
      {super.key,
      required this.name,
      required this.age,
      required this.location,
      required this.items,
      this.photo,
      this.onEdit});
  final String name;
  final int age;
  final String location;
  final List<SideMenuItem> items;

  /// The member's first photo; their initial shows without one.
  final ImageProvider? photo;
  final VoidCallback? onEdit;

  static const gold = Color(0xFFC4B5FD);
  static const cream = Color(0xFFFFFFFF);
  static const muted = Color(0xFFA1A1AA);
  static const line = Color(0xFF2A2436);

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width * .85).clamp(0.0, 360.0);
    final padding = MediaQuery.paddingOf(context);
    return Drawer(
      width: width,
      backgroundColor: const Color(0xFF0D0B12),
      shape: const RoundedRectangleBorder(),
      child: Stack(children: [
        // A soft violet arc of light in the top corner, and a faint glow below.
        Positioned(
            top: -width * .9,
            right: -width * .55,
            width: width * 1.4,
            height: width * 1.4,
            child: const IgnorePointer(
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          Color(0x00000000),
                          Color(0x00000000),
                          Color(0x337C3AED),
                          Color(0x00000000),
                        ], stops: [
                          0,
                          .82,
                          .97,
                          1
                        ]))))),
        const Positioned.fill(
            child: IgnorePointer(
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: RadialGradient(
                            center: Alignment(.9, -1.05),
                            radius: .9,
                            colors: [Color(0x407C3AED), Color(0x000D0B12)]))))),
        const Positioned.fill(
            child: IgnorePointer(
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: RadialGradient(
                            center: Alignment(.2, 1.15),
                            radius: .55,
                            colors: [Color(0x26EC4899), Color(0x000D0B12)]))))),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _Header(
              name: name,
              age: age,
              location: location,
              photo: photo,
              onEdit: onEdit,
              top: padding.top),
          const Divider(height: 1, thickness: 1, color: line),
          Expanded(
              child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(
                      height: 1, thickness: 1, indent: 8, endIndent: 8,
                      color: line),
                  itemBuilder: (_, i) => _MenuRow(item: items[i]))),
          Padding(
              padding: EdgeInsets.fromLTRB(26, 8, 22, padding.bottom + 26),
              child: Row(children: [
                Text('EVERLANE',
                    style: const TextStyle(
                        fontFamily: 'Lora',
                        fontSize: 14,
                        letterSpacing: 6,
                        color: gold)),
                const SizedBox(width: 10),
                Container(width: 46, height: 1, color: gold.withValues(alpha: .6)),
                const Spacer(),
                const Icon(Icons.eco_outlined, size: 24, color: gold),
              ])),
        ]),
      ]),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(
      {required this.name,
      required this.age,
      required this.location,
      required this.photo,
      required this.onEdit,
      required this.top});
  final String name;
  final int age;
  final String location;
  final ImageProvider? photo;
  final VoidCallback? onEdit;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.fromLTRB(22, top + 26, 10, 24),
      child: Row(children: [
        Container(
            width: 72,
            height: 72,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF7C3AED), Color(0xFFEC4899)]),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: .5),
                      blurRadius: 14,
                      offset: const Offset(0, 6))
                ]),
            child: CircleAvatar(
                backgroundColor: const Color(0xFF261C3B),
                backgroundImage: photo,
                child: photo == null
                    ? Text(name.isEmpty ? '' : name.characters.first,
                        style: const TextStyle(
                            fontFamily: 'Lora',
                            fontSize: 28,
                            color: SideMenu.cream))
                    : null)),
        const SizedBox(width: 18),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
              Text(age > 0 ? '$name, $age' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: 'Lora', fontSize: 25, color: SideMenu.cream)),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.location_on, size: 14, color: SideMenu.gold),
                const SizedBox(width: 6),
                Flexible(
                    child: Text(location.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: EverlaneFonts.inter(
                            size: 10.5,
                            letterSpacing: 2.2,
                            color: const Color(0xFFC4B5FD)))),
              ]),
            ])),
        if (onEdit != null)
          IconButton(
              tooltip: 'Edit profile',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined,
                  size: 22, color: SideMenu.gold)),
      ]));
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item});
  final SideMenuItem item;

  @override
  Widget build(BuildContext context) {
    final badge = item.badge ?? 0;
    return InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 15, 4, 15),
            child: Row(children: [
              Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                          center: const Alignment(-.3, -.4),
                          colors: [
                            Color.lerp(const Color(0xFF261C3B), item.color, .12)!,
                            const Color(0xFF191621),
                          ]),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: .05)),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: .45),
                            blurRadius: 10,
                            offset: const Offset(0, 4))
                      ]),
                  child: IconTheme(
                      data: IconThemeData(color: item.color, size: 20),
                      child: item.icon)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'Lora',
                            fontSize: 18,
                            color: SideMenu.cream)),
                    const SizedBox(height: 3),
                    Text(item.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: EverlaneFonts.inter(
                            size: 11.5, height: 1.35, color: SideMenu.muted)),
                  ])),
              if (badge > 0) ...[
                const SizedBox(width: 8),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: const Color(0xFFF472B6).withValues(alpha: .16),
                        border: Border.all(
                            color: const Color(0xFFF472B6)
                                .withValues(alpha: .5))),
                    child: Text('$badge',
                        style: EverlaneFonts.inter(
                            size: 12,
                            weight: FontWeight.w600,
                            color: const Color(0xFFF9A8D4)))),
              ],
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded,
                  size: 24, color: Color(0xFFA1A1AA)),
            ])));
  }
}

/// Two overlapping heart outlines, for Connections.
class TwoHeartsIcon extends StatelessWidget {
  const TwoHeartsIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final size = IconTheme.of(context).size ?? 22;
    return SizedBox(
        width: size * 1.35,
        height: size,
        child: Stack(children: [
          Positioned(
              left: 0,
              child: Icon(Icons.favorite_border_rounded, size: size)),
          Positioned(
              right: 0,
              child: Icon(Icons.favorite_border_rounded, size: size)),
        ]));
  }
}

/// A line-drawn crown, for the membership row.
class CrownIcon extends StatelessWidget {
  const CrownIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final size = theme.size ?? 22;
    return CustomPaint(
        size: Size(size * 1.2, size),
        painter: _CrownPainter(theme.color ?? SideMenu.gold));
  }
}

class _CrownPainter extends CustomPainter {
  const _CrownPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final crown = Path()
      ..moveTo(w * .1, h * .3)
      ..lineTo(w * .3, h * .55)
      ..lineTo(w * .5, h * .18)
      ..lineTo(w * .7, h * .55)
      ..lineTo(w * .9, h * .3)
      ..lineTo(w * .82, h * .75)
      ..lineTo(w * .18, h * .75)
      ..close();
    canvas.drawPath(crown, Paint()..color = color.withValues(alpha: .18));
    canvas.drawPath(crown, stroke);
    canvas.drawLine(Offset(w * .18, h * .9), Offset(w * .82, h * .9), stroke);
    final dot = Paint()..color = color;
    for (final p in [
      Offset(w * .1, h * .3),
      Offset(w * .5, h * .18),
      Offset(w * .9, h * .3)
    ]) {
      canvas.drawCircle(p, 1.8, dot);
    }
  }

  @override
  bool shouldRepaint(_CrownPainter oldDelegate) => color != oldDelegate.color;
}
