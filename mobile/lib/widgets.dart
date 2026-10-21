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
              color: KindredColors.blush,
              alignment: Alignment.center,
              child: Text(person.name[0],
                  style: const TextStyle(
                      fontFamily: 'Lora',
                      fontSize: 64,
                      color: KindredColors.coral))),
        ),
      );
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color = KindredColors.muted});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: TextStyle(
          fontSize: 10,
          letterSpacing: 2,
          fontWeight: FontWeight.w700,
          color: color));
}

class Tag extends StatelessWidget {
  const Tag(this.icon, this.text, {super.key});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .7),
            border: Border.all(color: KindredColors.line),
            borderRadius: BorderRadius.circular(30)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: KindredColors.muted),
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
            backgroundColor: filled ? KindredColors.coral : Colors.white,
            foregroundColor: filled ? Colors.white : KindredColors.plum,
            side: filled ? null : const BorderSide(color: KindredColors.line)),
      ));
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
            decoration: const BoxDecoration(
                color: KindredColors.blush, shape: BoxShape.circle),
            child: Icon(icon, size: 38, color: KindredColors.coral)),
        const SizedBox(height: 24),
        Text(title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text(detail,
            textAlign: TextAlign.center,
            style: const TextStyle(color: KindredColors.muted, height: 1.6)),
        if (action != null) ...[const SizedBox(height: 24), action!],
      ]));
}

void showNotice(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

Future<T?> showKindredSheet<T>(BuildContext context, Widget child) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: KindredColors.paper,
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
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration:
            BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [
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
