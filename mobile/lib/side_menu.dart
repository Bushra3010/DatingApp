import 'dart:ui' as ui;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'theme.dart';

class SideMenuItem {
  const SideMenuItem(this.icon, this.title, this.colors, this.onTap,
      {this.badge});
  final IconData icon;
  final String title;
  final List<Color> colors;
  final VoidCallback onTap;
  final int? badge;
}

/// Live controls over glass surfaces, with the original reference artwork.
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

  @override
  Widget build(BuildContext context) {
    final width =
        (MediaQuery.sizeOf(context).width * 535 / 768).clamp(0.0, 310.0);
    final scale = width / 535;
    final radius = BorderRadius.only(
        topRight: Radius.circular(47 * scale),
        bottomRight: Radius.circular(47 * scale));
    return Drawer(
      width: width,
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: DecoratedBox(
            decoration: BoxDecoration(
                borderRadius: radius,
                gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF191224),
                      Color(0xF20D0C13),
                      Color(0xF214101D)
                    ],
                    stops: [
                      0,
                      .55,
                      1
                    ]),
                border: Border.all(
                    color: const Color(0xFF80508E).withValues(alpha: .7))),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(
                      name: name, age: age, location: location, scale: scale),
                  Expanded(
                      child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                        28 * scale, 82 * scale, 32 * scale, 20 * scale),
                    child: Column(children: [
                      for (var i = 0; i < items.length; i++)
                        Padding(
                            padding: EdgeInsets.only(bottom: 16 * scale),
                            child: _MenuRow(
                                item: items[i], index: i, scale: scale)),
                    ]),
                  )),
                  Padding(
                      padding: EdgeInsets.fromLTRB(24 * scale, 10 * scale, 0,
                          MediaQuery.paddingOf(context).bottom + 30 * scale),
                      child: Align(
                          alignment: Alignment.centerLeft,
                          child: Semantics(
                              label: 'Everlane',
                              image: true,
                              child: _Artwork(
                                  source:
                                      const Rect.fromLTWH(24, 1248, 270, 104),
                                  width: 270 * scale,
                                  height: 104 * scale,
                                  feather: true)))),
                ]),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(
      {required this.name,
      required this.age,
      required this.location,
      required this.scale});
  final String name;
  final int age;
  final String location;
  final double scale;

  @override
  Widget build(BuildContext context) => Container(
      height: 250 * scale + MediaQuery.paddingOf(context).top,
      padding: EdgeInsets.fromLTRB(
          47 * scale,
          MediaQuery.paddingOf(context).top + 49 * scale,
          24 * scale,
          28 * scale),
      decoration: BoxDecoration(
          borderRadius:
              BorderRadius.only(bottomLeft: Radius.circular(46 * scale)),
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF42305E), Color(0xFF30324E), Color(0xFF21172F)],
              stops: [0, .5, 1]),
          border: Border(
              bottom: BorderSide(
                  color: const Color(0xFFB546AF).withValues(alpha: .65))),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFE443D7).withValues(alpha: .2),
                blurRadius: 12 * scale,
                spreadRadius: -6 * scale,
                offset: Offset(0, 7 * scale))
          ]),
      // The name and city sit beside the avatar, not under it.
      child: Row(children: [
        _Artwork(
            source: const Rect.fromLTWH(38, 49, 160, 160),
            width: 142 * scale,
            height: 160 * scale,
            feather: true),
        SizedBox(width: 14 * scale),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
              Text('$name, $age',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EverlaneFonts.inter(
                      size: 44 * scale, color: const Color(0xFFF8F5FB))),
              SizedBox(height: 5 * scale),
              Text(location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EverlaneFonts.inter(
                      size: 26 * scale, color: const Color(0xFFB08BD7))),
            ])),
      ]));
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(
      {required this.item, required this.index, required this.scale});
  final SideMenuItem item;
  final int index;
  final double scale;

  static const _art = [
    Rect.fromLTWH(42, 463, 86, 79),
    Rect.fromLTWH(42, 575, 86, 80),
    Rect.fromLTWH(42, 690, 86, 82),
    Rect.fromLTWH(42, 806, 86, 82),
    Rect.fromLTWH(42, 921, 86, 84),
    Rect.fromLTWH(42, 1037, 86, 81),
  ];

  @override
  Widget build(BuildContext context) {
    final likes = item.badge != null;
    final shape = BorderRadius.circular(50 * scale);
    Widget surface({bool behind = false}) => DecoratedBox(
            decoration: BoxDecoration(
                borderRadius: shape,
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: behind
                        ? [const Color(0xFF302538), const Color(0xFF17131F)]
                        : [
                            const Color(0xFF2D2936),
                            const Color(0xFF201D27),
                            const Color(0xFF24202E)
                          ],
                    stops: behind ? null : [0, .45, 1]),
                border: Border.all(
                    color: const Color(0xFFAB8BB9)
                        .withValues(alpha: behind ? .35 : .6),
                    width: 1.5 * scale),
                boxShadow: [
              BoxShadow(
                  color: (likes
                          ? const Color(0xFFE55CC0)
                          : const Color(0xFFB9A2CC))
                      .withValues(alpha: .12),
                  blurRadius: 10 * scale,
                  spreadRadius: -3 * scale)
            ]));
    return Stack(clipBehavior: Clip.none, children: [
      if (likes) ...[
        for (var depth = 2; depth >= 1; depth--)
          Positioned(
              key: ValueKey('stack-card-$depth'),
              left: 0,
              right: 0,
              top: -19 * scale * depth,
              height: 98 * scale,
              child: surface(behind: true)),
        Positioned(
            left: 18 * scale,
            top: -47 * scale,
            child: _Sparkle(size: 28 * scale)),
      ],
      Positioned.fill(child: surface()),
      Material(
          color: Colors.transparent,
          borderRadius: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
              onTap: item.onTap,
              borderRadius: shape,
              child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: 98 * scale),
                  child: Padding(
                      padding: EdgeInsets.fromLTRB(
                          14 * scale, 7 * scale, 22 * scale, 7 * scale),
                      child: Row(children: [
                        if (index < _art.length)
                          ExcludeSemantics(
                              child: _Artwork(
                                  source: _art[index],
                                  width: 86 * scale,
                                  height: 82 * scale,
                                  feather: true))
                        else
                          Icon(item.icon,
                              color: item.colors.first, size: 70 * scale),
                        SizedBox(width: 14 * scale),
                        Expanded(
                            child: Text(item.title,
                                style: EverlaneFonts.inter(
                                    size: 32 * scale,
                                    color: const Color(0xFFFAF8FC)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis)),
                        if (likes) ...[
                          SizedBox(width: 8 * scale),
                          Container(
                              width: 46 * scale,
                              height: 40 * scale,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(22 * scale),
                                  color: const Color(0xFF382033),
                                  border: Border.all(
                                      color: const Color(0xFFF15ABD),
                                      width: 2 * scale),
                                  boxShadow: [
                                    BoxShadow(
                                        color: const Color(0xFFF535A8)
                                            .withValues(alpha: .65),
                                        blurRadius: 10 * scale)
                                  ]),
                              child: Text('${item.badge}',
                                  style: EverlaneFonts.inter(
                                      size: 25 * scale,
                                      color: const Color(0xFFF45ABA)))),
                        ],
                      ]))))),
      if (likes)
        Positioned(
            right: -8 * scale,
            top: -8 * scale,
            child: IgnorePointer(child: _Sparkle(size: 38 * scale))),
      if (index == 4)
        Positioned(
            right: 20 * scale,
            top: -14 * scale,
            child: IgnorePointer(child: _Sparkle(size: 30 * scale))),
    ]);
  }
}

/// Clips the supplied reference at render time, retaining its exact icon art.
/// A soft edge lets the original glow blend into the live glass surface.
class _Artwork extends StatefulWidget {
  const _Artwork(
      {required this.source,
      required this.width,
      required this.height,
      this.feather = false});
  final Rect source;
  final double width;
  final double height;
  final bool feather;

  @override
  State<_Artwork> createState() => _ArtworkState();
}

class _ArtworkState extends State<_Artwork> {
  ImageStream? _stream;
  ImageInfo? _image;
  late final _listener = ImageStreamListener((image, _) {
    final previous = _image;
    setState(() => _image = image);
    previous?.dispose();
  });

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final stream = const AssetImage('assets/images/side_menu_reference.png')
        .resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
      size: Size(widget.width, widget.height),
      painter: _ArtworkPainter(_image?.image, widget.source, widget.feather));
}

/// Paint only the requested source rectangle. Keeping the blend layer bounded
/// to the icon prevents web compositing from masking the rest of the drawer.
class _ArtworkPainter extends CustomPainter {
  const _ArtworkPainter(this.image, this.source, this.feather);
  final ui.Image? image;
  final Rect source;
  final bool feather;

  @override
  void paint(Canvas canvas, Size size) {
    if (image == null) return;
    final bounds = Offset.zero & size;
    canvas.save();
    canvas.clipRect(bounds);
    if (feather) canvas.saveLayer(bounds, Paint());
    canvas.drawImageRect(
        image!, source, bounds, Paint()..filterQuality = FilterQuality.high);
    if (feather) {
      for (final vertical in [false, true]) {
        canvas.drawRect(
            bounds,
            Paint()
              ..blendMode = BlendMode.dstIn
              ..shader = LinearGradient(
                  begin: vertical ? Alignment.topCenter : Alignment.centerLeft,
                  end:
                      vertical ? Alignment.bottomCenter : Alignment.centerRight,
                  colors: const [
                    Colors.transparent,
                    Colors.white,
                    Colors.white,
                    Colors.transparent
                  ],
                  stops: const [
                    0,
                    .16,
                    .84,
                    1
                  ]).createShader(bounds));
      }
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ArtworkPainter oldDelegate) =>
      image != oldDelegate.image ||
      source != oldDelegate.source ||
      feather != oldDelegate.feather;
}

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
    final w = r * .18;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + w, c.dy - w, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + w, c.dy + w, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - w, c.dy + w, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - w, c.dy - w, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFC78CF9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    canvas.drawPath(path, Paint()..color = const Color(0xFFE8CCFF));
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) => false;
}
