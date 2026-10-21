import 'package:flutter/material.dart';
import 'models.dart';
import 'screens.dart';
import 'theme.dart';
import 'widgets.dart';

/// "What do you want to do?" choices on the Ready to Hangout screen.
const hangoutMoods = [
  ('Up for anything', Icons.wb_sunny_outlined),
  ('Chill outside', Icons.park_outlined),
  ('Explore nearby', Icons.location_city_outlined),
  ('Go out', Icons.nightlife_outlined),
  ('Grab food', Icons.restaurant_outlined),
  ('Watch a game', Icons.sports_cricket_outlined),
];

/// Premium members go to Hangouts (via setup the first time); everyone else
/// sees the upgrade sheet.
void openHangouts(BuildContext context, PreviewStore store) {
  if (!store.canHangout) {
    showUpgrade(context, store,
        title: 'Hangouts are a Premium feature.',
        detail:
            'Host a plan or ask to join one nearby, from coffee to a late show. Get Premium to start hanging out.');
    return;
  }
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  Navigator.push(
      context,
      MaterialPageRoute<void>(
          builder: (_) => store.hangoutMood == null
              ? HangoutSetupScreen(store: store)
              : HangoutsScreen(store: store)));
}

class HangoutsBanner extends StatelessWidget {
  const HangoutsBanner({super.key, required this.store});
  final PreviewStore store;
  @override
  Widget build(BuildContext context) => Material(
      color: EverlaneColors.deep,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => openHangouts(context, store),
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                        color: EverlaneColors.boost,
                        borderRadius: BorderRadius.circular(15)),
                    child: const Icon(Icons.groups_rounded,
                        color: Colors.white, size: 26)),
                const SizedBox(width: 16),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text('Hangouts',
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                            if (!store.canHangout)
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                      color: EverlaneColors.star,
                                      borderRadius: BorderRadius.circular(20)),
                                  child: Text('Premium',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: EverlaneColors.plum))),
                          ]),
                      const SizedBox(height: 4),
                      Text('Host a plan, or join one near you.',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: .75))),
                    ])),
                Icon(
                    store.canHangout
                        ? Icons.chevron_right_rounded
                        : Icons.lock_outline_rounded,
                    color: Colors.white),
              ]))));
}

class HangoutSetupScreen extends StatefulWidget {
  const HangoutSetupScreen({super.key, required this.store});
  final PreviewStore store;
  @override
  State<HangoutSetupScreen> createState() => _HangoutSetupScreenState();
}

class _HangoutSetupScreenState extends State<HangoutSetupScreen> {
  late var mood = widget.store.hangoutMood ?? hangoutMoods.first.$1;
  late final detail = TextEditingController(text: widget.store.hangoutDetail);
  late var hasPlace = widget.store.hangoutHasPlace;

  @override
  void dispose() {
    detail.dispose();
    super.dispose();
  }

  void join() {
    final first = widget.store.hangoutMood == null;
    widget.store.joinHangouts(mood, detail.text, hasPlace);
    if (first) {
      Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
              builder: (_) => HangoutsScreen(store: widget.store)));
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            Text('Ready to hang out?',
                style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 10),
            Text(
                'Tell us what you feel like doing and see who’s around to join you.',
                style: TextStyle(color: EverlaneColors.muted, height: 1.5)),
            const SizedBox(height: 28),
            const Text('What do you want to do?',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final (label, icon) in hangoutMoods)
                ChoiceChip(
                    avatar: Icon(icon,
                        size: 17,
                        color:
                            mood == label ? Colors.white : EverlaneColors.plum),
                    label: Text(label),
                    selected: mood == label,
                    showCheckmark: false,
                    selectedColor: EverlaneColors.like,
                    backgroundColor: EverlaneColors.card,
                    side: BorderSide(
                        color: mood == label
                            ? EverlaneColors.like
                            : EverlaneColors.line),
                    labelStyle: TextStyle(
                        color:
                            mood == label ? Colors.white : EverlaneColors.plum,
                        fontWeight: FontWeight.w600),
                    onSelected: (_) => setState(() => mood = label)),
            ]),
            const SizedBox(height: 28),
            const Text('Anything specific?',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
                controller: detail,
                maxLength: 80,
                decoration: const InputDecoration(
                    hintText: 'e.g. find a quiet café and people-watch')),
            const SizedBox(height: 16),
            const Text('Where do you want to hang out?',
                style: TextStyle(fontWeight: FontWeight.w700)),
            RadioGroup<bool>(
                groupValue: hasPlace,
                onChanged: (v) => setState(() => hasPlace = v ?? false),
                child: const Column(children: [
                  RadioListTile(
                      value: false,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.trailing,
                      title: Text('I’m flexible')),
                  RadioListTile(
                      value: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.trailing,
                      title: Text('I have a place in mind')),
                ])),
            const SizedBox(height: 24),
            Center(
                child: Text('We never share your exact location.',
                    style:
                        TextStyle(fontSize: 12, color: EverlaneColors.muted))),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: join,
                style: FilledButton.styleFrom(
                    backgroundColor: EverlaneColors.like),
                child: Text(widget.store.hangoutMood == null
                    ? 'Join Hangouts'
                    : 'Save')),
          ]));
}

class HangoutsScreen extends StatefulWidget {
  const HangoutsScreen({super.key, required this.store});
  final PreviewStore store;
  @override
  State<HangoutsScreen> createState() => _HangoutsScreenState();
}

class _HangoutsScreenState extends State<HangoutsScreen> {
  HangoutKind? filter;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final store = widget.store;
        final plans = store.hangouts
            .where((h) => filter == null || h.kind == filter)
            .toList();
        return Scaffold(
            appBar: AppBar(
                title: const Text('Hangouts', style: TextStyle(fontSize: 17))),
            body: ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                children: [
                  Text('Host a plan, or ask to join one that suits you.',
                      style: TextStyle(color: EverlaneColors.muted)),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                        child: Tag(Icons.tune_rounded,
                            '${store.hangoutMood}${store.hangoutHasPlace ? ' · Have a place' : ' · Flexible'}')),
                    TextButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) =>
                                    HangoutSetupScreen(store: store))),
                        child: const Text('Change')),
                  ]),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                      onPressed: () => hostPlan(context, store),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Host a plan')),
                  const SizedBox(height: 18),
                  SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        for (final kind in [null, ...HangoutKind.values])
                          Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                  label: Text(kind?.label ?? 'All'),
                                  selected: filter == kind,
                                  showCheckmark: false,
                                  selectedColor: EverlaneColors.deep,
                                  backgroundColor: EverlaneColors.card,
                                  side: BorderSide(color: EverlaneColors.line),
                                  labelStyle: TextStyle(
                                      color: filter == kind
                                          ? Colors.white
                                          : EverlaneColors.plum),
                                  onSelected: (_) =>
                                      setState(() => filter = kind))),
                      ])),
                  const SizedBox(height: 18),
                  if (plans.isEmpty)
                    EmptyState(
                        icon: filter?.icon ?? Icons.groups_outlined,
                        title: 'Nothing planned yet.',
                        detail: 'Be the first: host a plan and see who joins.'),
                  for (final h in plans)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _HangoutCard(store: store, hangout: h)),
                  const Center(child: Eyebrow('Demo plans · UI preview')),
                ]));
      });
}

class _HangoutCard extends StatelessWidget {
  const _HangoutCard({required this.store, required this.hangout});
  final PreviewStore store;
  final Hangout hangout;
  @override
  Widget build(BuildContext context) {
    final h = hangout;
    final host = h.host;
    final requested = store.hangoutRequests.contains(h.id);
    final hostName = host?.name ?? 'you';
    return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: EverlaneColors.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: EverlaneColors.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            host == null
                ? Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: EverlaneColors.blush),
                    alignment: Alignment.center,
                    child: Text(store.myName.isEmpty ? 'R' : store.myName[0],
                        style: const TextStyle(color: EverlaneColors.like)))
                : Portrait(host, height: 38, width: 38, radius: 19),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(host?.name ?? 'You',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('${h.kind.label}, hosted by $hostName',
                      style:
                          TextStyle(fontSize: 11, color: EverlaneColors.muted)),
                ])),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: EverlaneColors.star)),
                child: Text(
                    h.spots == 1 ? '1 spot left' : '${h.spots} spots left',
                    style: const TextStyle(fontSize: 11))),
          ]),
          const SizedBox(height: 14),
          Text(h.title,
              style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.4)),
          const SizedBox(height: 4),
          Text('${h.when} · ${h.place}',
              style: TextStyle(fontSize: 12, color: EverlaneColors.muted)),
          if (h.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(h.note, style: const TextStyle(fontSize: 14)),
          ],
          const SizedBox(height: 14),
          if (host == null)
            const Eyebrow('You’re hosting', color: EverlaneColors.boost)
          else
            Wrap(spacing: 10, runSpacing: 10, children: [
              FilledButton(
                  onPressed: requested
                      ? null
                      : () {
                          store.requestToJoin(h);
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          showNotice(context, 'Request sent to ${host.name}');
                        },
                  style: FilledButton.styleFrom(
                      backgroundColor: EverlaneColors.like,
                      minimumSize: const Size(0, 42),
                      padding: const EdgeInsets.symmetric(horizontal: 18)),
                  child: Text(requested ? 'Requested' : 'Request to join')),
              OutlinedButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (_) => ChatScreen(
                              store: store,
                              chat: store.chatWith(host),
                              draft:
                                  'Hi, I’m interested in “${h.title}”. Is there still room?'))),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 42),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16))),
                  child: const Text('Message host')),
            ]),
        ]));
  }
}

Future<void> hostPlan(BuildContext context, PreviewStore store) =>
    showEverlaneSheet(context, _HostPlanForm(store: store));

/// Owns its controllers so they outlive the sheet's closing animation.
class _HostPlanForm extends StatefulWidget {
  const _HostPlanForm({required this.store});
  final PreviewStore store;
  @override
  State<_HostPlanForm> createState() => _HostPlanFormState();
}

class _HostPlanFormState extends State<_HostPlanForm> {
  var kind = HangoutKind.coffee;
  var spots = 2;
  final title = TextEditingController();
  final when = TextEditingController();
  final place = TextEditingController();
  final note = TextEditingController();

  @override
  void dispose() {
    for (final c in [title, when, place, note]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Eyebrow('Host a plan'),
        const SizedBox(height: 10),
        Text('What’s the plan?',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 18),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final k in HangoutKind.values)
            ChoiceChip(
                avatar: Icon(k.icon, size: 16),
                label: Text(k.label),
                selected: kind == k,
                showCheckmark: false,
                onSelected: (_) => setState(() => kind = k)),
        ]),
        const SizedBox(height: 16),
        TextField(
            controller: title,
            onChanged: (_) => setState(() {}),
            maxLength: 50,
            decoration:
                const InputDecoration(hintText: 'Title, e.g. Sunday brunch')),
        TextField(
            controller: when,
            onChanged: (_) => setState(() {}),
            decoration:
                const InputDecoration(hintText: 'When, e.g. Sunday, 11:00 am')),
        const SizedBox(height: 10),
        TextField(
            controller: place,
            onChanged: (_) => setState(() {}),
            decoration:
                const InputDecoration(hintText: 'Area, e.g. Indiranagar')),
        const SizedBox(height: 10),
        TextField(
            controller: note,
            maxLength: 100,
            decoration:
                const InputDecoration(hintText: 'A line about it (optional)')),
        Row(children: [
          const Expanded(child: Text('Spots')),
          IconButton(
              tooltip: 'Fewer spots',
              onPressed: spots > 1 ? () => setState(() => spots--) : null,
              icon: const Icon(Icons.remove_circle_outline)),
          Text('$spots', style: const TextStyle(fontWeight: FontWeight.w700)),
          IconButton(
              tooltip: 'More spots',
              onPressed: spots < 8 ? () => setState(() => spots++) : null,
              icon: const Icon(Icons.add_circle_outline)),
        ]),
        const SizedBox(height: 16),
        FilledButton(
            onPressed: [title, when, place].any((c) => c.text.trim().isEmpty)
                ? null
                : () {
                    widget.store.hostHangout(Hangout(
                        id: 'mine-${widget.store.hangouts.length}',
                        host: null,
                        kind: kind,
                        title: title.text.trim(),
                        when: when.text.trim(),
                        place: place.text.trim(),
                        note: note.text.trim(),
                        spots: spots));
                    Navigator.pop(context);
                  },
            child: const Text('Post plan')),
      ]);
}
