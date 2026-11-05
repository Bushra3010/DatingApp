import 'package:flutter/material.dart';
import 'cities.dart';
import 'models.dart';
import 'screens.dart';
import 'theme.dart';
import 'voice.dart';
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

/// Opens Hangouts as its own page (from Explore and the side menu).
void openHangouts(BuildContext context, PreviewStore store) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  Navigator.push(context,
      MaterialPageRoute<void>(builder: (_) => HangoutsScreen(store: store)));
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
                                  child: Text('Platinum',
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
    widget.store.joinHangouts(mood, detail.text, hasPlace);
    Navigator.pop(context);
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

/// Plans near you: Hangouts is a main tab ([embedded]) and also opens as
/// its own page from Explore and the side menu.
class HangoutsScreen extends StatefulWidget {
  const HangoutsScreen({super.key, required this.store, this.embedded = false});
  final PreviewStore store;
  final bool embedded;
  @override
  State<HangoutsScreen> createState() => _HangoutsScreenState();
}

class _HangoutsScreenState extends State<HangoutsScreen> {
  HangoutKind? filter;

  /// "Find a +1": only plans built around this kind of event.
  HangoutEvent? event;

  @override
  void initState() {
    super.initState();
    widget.store.loadHangouts();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final store = widget.store;
        final plans = store.hangouts
            .where((h) => filter == null || h.kind == filter)
            .where((h) => event == null || h.event == event)
            .toList();
        final mine = plans.where((h) => h.mine).toList();
        final others = plans.where((h) => !h.mine).toList();
        final list = RefreshIndicator(
            onRefresh: store.loadHangouts,
            child: ListView(
                padding: EdgeInsets.fromLTRB(24, widget.embedded ? 8 : 0, 24, 24),
                children: [
                  if (widget.embedded) ...[
                    const Eyebrow('Make a plan, meet in person'),
                    const SizedBox(height: 8),
                    Text('Hangouts',
                        style: Theme.of(context).textTheme.headlineLarge),
                    const SizedBox(height: 6),
                  ],
                  Text(
                      store.signedIn && store.myCity.isNotEmpty
                          ? 'Plans within ${store.distance.round()} km of you. Host one, or ask to join.'
                          : 'Host a plan, or ask to join one that suits you.',
                      style: TextStyle(color: EverlaneColors.muted, height: 1.4)),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                        child: Tag(
                            Icons.tune_rounded,
                            store.hangoutMood == null
                                ? 'Set your vibe'
                                : '${store.hangoutMood}${store.hangoutHasPlace ? ' · Have a place' : ' · Flexible'}')),
                    TextButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) =>
                                    HangoutSetupScreen(store: store))),
                        child: Text(store.hangoutMood == null ? 'Set' : 'Change')),
                  ]),
                  const SizedBox(height: 10),
                  GradientButton(
                      label: 'Host a plan',
                      icon: Icons.add_rounded,
                      onTap: () => hostPlan(context, store)),
                  const SizedBox(height: 18),
                  SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        for (final kind in [null, ...HangoutKind.values])
                          Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                  avatar: kind == null
                                      ? null
                                      : Icon(kind.icon,
                                          size: 16,
                                          color: filter == kind
                                              ? Colors.white
                                              : EverlaneColors.lavender),
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
                  const SizedBox(height: 14),
                  Row(children: [
                    Icon(Icons.confirmation_number_outlined,
                        size: 16, color: EverlaneColors.like),
                    const SizedBox(width: 6),
                    const Text('Find a +1',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text('Spare tickets, looking for company',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12, color: EverlaneColors.muted))),
                  ]),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        for (final e in HangoutEvent.values)
                          Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                  avatar: Icon(e.icon,
                                      size: 16,
                                      color: event == e
                                          ? Colors.white
                                          : EverlaneColors.like),
                                  label: Text(e.label),
                                  selected: event == e,
                                  showCheckmark: false,
                                  selectedColor: EverlaneColors.like,
                                  backgroundColor: EverlaneColors.card,
                                  side: BorderSide(color: EverlaneColors.line),
                                  labelStyle: TextStyle(
                                      color: event == e
                                          ? Colors.white
                                          : EverlaneColors.plum),
                                  // Tap again to clear.
                                  onSelected: (_) => setState(
                                      () => event = event == e ? null : e))),
                      ])),
                  const SizedBox(height: 18),
                  if (store.hangoutsLoading && plans.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(30),
                        child: Center(child: CircularProgressIndicator())),
                  if (mine.isNotEmpty) ...[
                    const Eyebrow('Your plans'),
                    const SizedBox(height: 10),
                    for (final h in mine)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _HangoutCard(store: store, hangout: h)),
                    const SizedBox(height: 6),
                    if (others.isNotEmpty) const Eyebrow('Near you'),
                    const SizedBox(height: 10),
                  ],
                  if (!store.hangoutsLoading && plans.isEmpty)
                    EmptyState(
                        icon: event?.icon ?? filter?.icon ?? Icons.groups_outlined,
                        title: event != null
                            ? 'No spare ${event!.label.toLowerCase()} tickets right now.'
                            : 'Nothing planned nearby yet.',
                        detail:
                            'Be the first: host a plan and see who joins. You can also widen your distance in preferences.'),
                  for (final h in others)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _HangoutCard(store: store, hangout: h)),
                  if (!store.signedIn)
                    const Center(child: Eyebrow('Demo plans · sign in to see real ones')),
                ]));
        if (widget.embedded) return list;
        return Scaffold(
            appBar: AppBar(
                title: const Text('Hangouts', style: TextStyle(fontSize: 17))),
            body: list);
      });
}

class _HangoutCard extends StatelessWidget {
  const _HangoutCard({required this.store, required this.hangout});
  final PreviewStore store;
  final Hangout hangout;

  Widget _pill(String text, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color)),
      child: Text(text, style: const TextStyle(fontSize: 11)));

  @override
  Widget build(BuildContext context) {
    final h = hangout;
    final host = h.host;
    final requests =
        store.hangoutRequests.where((r) => r.hangoutId == h.id).toList();
    final hostName = host?.name ?? 'you';
    final where = [
      h.place,
      if (h.distanceKm != null && !h.mine)
        h.distanceKm! <= 5 ? 'Nearby' : '${h.distanceKm} km away',
    ].where((s) => s.isNotEmpty).join(' · ');
    final accent = _kindColor(h.kind);
    final taken = (h.spots - h.spotsLeft).clamp(0, h.spots);
    // Once someone is accepted the plan no longer expires.
    final locked =
        h.status == 'accepted' || requests.any((r) => r.status == 'accepted');
    final endsIn = h.official || locked ? null : timeLeft(h.expiresAt);
    final lockLeft = h.status == 'accepted'
        ? timeLeft(h.acceptedAt?.add(hangoutLockWindow))
        : null;
    return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
            color: EverlaneColors.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: h.mine
                    ? EverlaneColors.deep.withValues(alpha: .6)
                    : EverlaneColors.line),
            boxShadow: [
              BoxShadow(
                  color: accent.withValues(alpha: .12),
                  blurRadius: 24,
                  offset: const Offset(0, 10))
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // The plan's kind and date, in its own colour.
          Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                accent.withValues(alpha: .28),
                accent.withValues(alpha: .06),
              ])),
              child: Row(children: [
                Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: accent.withValues(alpha: .22),
                        borderRadius: BorderRadius.circular(13)),
                    child: Icon(h.event?.icon ?? h.kind.icon,
                        color: accent, size: 21)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          h.official
                              ? '${h.kind.label.toUpperCase()} · EVERLANE EVENT'
                              : h.event != null
                                  ? '+1 · ${h.event!.label.toUpperCase()}'
                                  : h.kind.label.toUpperCase(),
                          style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 1.6,
                              fontWeight: FontWeight.w800,
                              color: accent)),
                      const SizedBox(height: 3),
                      Text(h.when,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      if (endsIn != null) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.hourglass_bottom_rounded,
                              size: 13, color: EverlaneColors.muted),
                          const SizedBox(width: 4),
                          Flexible(
                              child: Text('Post ends in $endsIn',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      color: EverlaneColors.muted))),
                        ]),
                      ],
                    ])),
                _DateBlock(date: h.startsAt, color: accent),
              ])),
          Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
          Row(children: [
            host == null
                ? Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: EverlaneColors.premiumGradient),
                    alignment: Alignment.center,
                    child: Text(store.myName.isEmpty ? 'Y' : store.myName[0],
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)))
                : GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => PersonDetailsScreen(
                                store: store, person: host))),
                    child: Portrait(host, height: 38, width: 38, radius: 19)),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Flexible(
                        child: Text(
                            host == null
                                ? 'You'
                                : host.age > 0
                                    ? '${host.name}, ${host.age}'
                                    : host.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700))),
                    if (host?.verified ?? false) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified_rounded,
                          size: 15, color: Color(0xFF60A5FA)),
                    ],
                  ]),
                  Text(
                      h.official
                          ? 'Hosted by the Everlane team'
                          : 'Hosted by $hostName',
                      style: TextStyle(
                          fontSize: 11,
                          color: h.official
                              ? EverlaneColors.lavender
                              : EverlaneColors.muted)),
                ])),
            _pill(
                h.spotsLeft == 0
                    ? 'Full'
                    : h.spotsLeft == 1
                        ? '1 spot left'
                        : '${h.spotsLeft} spots left',
                h.spotsLeft == 0 ? EverlaneColors.pass : EverlaneColors.star),
          ]),
          const SizedBox(height: 14),
          Text(h.title,
              style: EverlaneFonts.playfair(
                  size: 21, weight: FontWeight.w700, color: EverlaneColors.plum)),
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.place_outlined, size: 15, color: EverlaneColors.lavender),
            const SizedBox(width: 6),
            Expanded(
                child: Text(
                    h.venue.isNotEmpty
                        ? '${h.venue}${where.isEmpty ? '' : ' · $where'}'
                        : '$where${where.isEmpty ? '' : ' '}(exact venue shared after approval)',
                    style: TextStyle(fontSize: 13, color: EverlaneColors.muted))),
          ]),
          if (h.note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(h.note, style: const TextStyle(fontSize: 14)),
          ],
          if (h.lookingFor.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Hoping to meet: ${h.lookingFor}',
                style: TextStyle(fontSize: 13, color: EverlaneColors.muted)),
          ],
          if (h.prompt.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Icebreaker(prompt: h.prompt, color: accent),
          ],
          if (lockLeft != null) ...[
            const SizedBox(height: 12),
            _LockIn(left: lockLeft),
          ],
          const SizedBox(height: 14),
          // How full the plan is.
          Row(children: [
            Expanded(
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                        value: h.spots == 0 ? 0 : taken / h.spots,
                        minHeight: 6,
                        backgroundColor: EverlaneColors.line,
                        color: accent))),
            const SizedBox(width: 10),
            Text(taken == 0 ? 'Be the first' : '$taken of ${h.spots} going',
                style: TextStyle(fontSize: 12, color: EverlaneColors.muted)),
          ]),
          const SizedBox(height: 16),
          if (h.mine) ...[
            if (requests.isEmpty)
              Text(
                  store.signedIn
                      ? 'No requests yet. We’ll show them here.'
                      : 'You’re hosting',
                  style: TextStyle(fontSize: 13, color: EverlaneColors.muted)),
            for (final r in requests)
              Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  Row(children: [
                    Portrait(r.person, height: 32, width: 32, radius: 16),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(
                            r.status == 'accepted'
                                ? '${r.person.name} is coming'
                                : '${r.person.name} asked to join',
                            style: const TextStyle(fontSize: 14))),
                    if (r.status == 'pending') ...[
                      FilledButton(
                          onPressed: h.spotsLeft == 0
                              ? null
                              : () => store.answerHangoutRequest(r, accept: true),
                          style: FilledButton.styleFrom(
                              backgroundColor: EverlaneColors.like,
                              minimumSize: const Size(0, 34),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14)),
                          child: const Text('Accept')),
                      TextButton(
                          onPressed: () =>
                              store.answerHangoutRequest(r, accept: false),
                          child: const Text('Decline')),
                    ] else
                      Icon(Icons.check_circle_rounded,
                          color: EverlaneColors.boost, size: 20),
                  ]),
                  // Their answer to your icebreaker: listen before accepting.
                  if (r.voiceUrl.isNotEmpty && r.status == 'pending') ...[
                    const SizedBox(height: 8),
                    VoicePrompt(
                        id: r.person.id,
                        seconds: r.voiceSeconds,
                        url: r.voiceUrl),
                  ],
                  if (r.status == 'accepted' &&
                      timeLeft(r.acceptedAt?.add(hangoutLockWindow)) != null) ...[
                    const SizedBox(height: 8),
                    _LockIn(
                        left: timeLeft(r.acceptedAt?.add(hangoutLockWindow))!),
                  ],
                ])),
            Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                                  title: const Text('Cancel this plan?'),
                                  content: const Text(
                                      'It disappears for everyone, including guests you accepted.'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Keep it')),
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Cancel plan')),
                                  ]));
                      if (ok == true) store.cancelHangout(h);
                    },
                    child: const Text('Cancel plan'))),
          ] else
            Wrap(spacing: 10, runSpacing: 10, children: [
              FilledButton(
                  onPressed: h.status != null || h.spotsLeft == 0
                      ? null
                      : () => _join(context, store, h),
                  style: FilledButton.styleFrom(
                      backgroundColor: EverlaneColors.like,
                      minimumSize: const Size(0, 42),
                      padding: const EdgeInsets.symmetric(horizontal: 18)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (h.status == null &&
                        h.prompt.isNotEmpty &&
                        h.spotsLeft > 0) ...[
                      const Icon(Icons.mic_rounded, size: 18),
                      const SizedBox(width: 6),
                    ],
                    Text(switch (h.status) {
                      'pending' => 'Requested',
                      'accepted' => 'You’re in ✓',
                      'declined' => 'Not this time',
                      _ => h.spotsLeft == 0
                          ? 'Full'
                          : h.prompt.isNotEmpty
                              ? 'Answer to join'
                              : 'Request to join',
                    }),
                  ])),
              // No typed openers: chat opens once the host accepts you.
              if (!h.official && h.status == 'accepted')
                OutlinedButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => ChatScreen(
                                store: store,
                                chat: store.chatWith(host!),
                                draft: ''))),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 42),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16))),
                    child: const Text('Message host')),
            ]),
                  ])),
        ]));
  }
}

/// Asks to join [h]: plans with an icebreaker are answered by voice first.
Future<void> _join(BuildContext context, PreviewStore store, Hangout h) async {
  final hostName = h.host?.name ?? 'The host';
  VoiceAnswer? answer;
  if (h.prompt.isNotEmpty) {
    answer = await recordHangoutAnswer(context, h.prompt, hostName);
    if (answer == null) return;
  }
  await store.requestToJoin(h,
      voice: answer?.wav, voiceSeconds: answer?.seconds ?? 0);
  if (!context.mounted || h.status == null) return;
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  showNotice(context, 'Request sent to $hostName');
}

/// The host's icebreaker, which people answer with a voice note.
class _Icebreaker extends StatelessWidget {
  const _Icebreaker({required this.prompt, required this.color});
  final String prompt;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: .3))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.record_voice_over_rounded, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('ICEBREAKER · ANSWER BY VOICE',
                  style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w800,
                      color: EverlaneColors.muted)),
              const SizedBox(height: 3),
              Text(prompt,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, height: 1.35)),
            ])),
      ]));
}

/// The 2-hour window after acceptance to settle the time and place.
class _LockIn extends StatelessWidget {
  const _LockIn({required this.left});
  final String left;
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
          color: EverlaneColors.boost.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(Icons.timer_outlined, size: 16, color: EverlaneColors.boost),
        const SizedBox(width: 8),
        Expanded(
            child: Text('Lock in the time and place in chat · $left left',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: EverlaneColors.boost))),
      ]));
}

/// A colour per kind of plan, used for the card's band and progress bar.
Color _kindColor(HangoutKind kind) => switch (kind) {
      HangoutKind.dinner => EverlaneColors.star,
      HangoutKind.movie => EverlaneColors.lavender,
      HangoutKind.coffee => const Color(0xFFD9A47A),
      HangoutKind.drinks => EverlaneColors.like,
      HangoutKind.outdoors => EverlaneColors.boost,
    };

/// A small calendar tile: day of the month over the short month name.
class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.date, required this.color});
  final DateTime date;
  final Color color;
  static const _months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];
  @override
  Widget build(BuildContext context) => Container(
      width: 48,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
          color: EverlaneColors.paper,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: .45))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${date.day}',
            style: TextStyle(
                fontSize: 18,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: EverlaneColors.plum)),
        Text(_months[date.month - 1],
            style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: color)),
      ]));
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
  HangoutEvent? event;
  var spots = 2;
  var posting = false;
  late DateTime day = _today();
  TimeOfDay time = const TimeOfDay(hour: 20, minute: 0);
  final title = TextEditingController();
  final area = TextEditingController();
  final venue = TextEditingController();
  final note = TextEditingController();
  final lookingFor = TextEditingController();
  late final city = TextEditingController(text: widget.store.myCity);

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  DateTime get startsAt =>
      DateTime(day.year, day.month, day.day, time.hour, time.minute);

  @override
  void dispose() {
    for (final c in [title, area, venue, note, lookingFor, city]) {
      c.dispose();
    }
    super.dispose();
  }

  String _dayLabel(DateTime d) {
    final diff = d.difference(_today()).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return whenLabel(d).split(',').first;
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
        context: context,
        initialDate: day,
        firstDate: _today(),
        lastDate: _today().add(const Duration(days: 60)),
        helpText: 'Pick a day');
    if (picked != null) setState(() => day = picked);
  }

  Future<void> pickTime() async {
    final picked = await showTimePicker(
        context: context, initialTime: time, helpText: 'Pick a time');
    if (picked != null) setState(() => time = picked);
  }

  Future<void> post() async {
    if (startsAt.isBefore(DateTime.now())) {
      showNotice(context, 'Pick a time later than now');
      return;
    }
    setState(() => posting = true);
    try {
      await widget.store.hostHangout(Hangout(
          id: 'mine-${DateTime.now().microsecondsSinceEpoch}',
          host: null,
          kind: kind,
          title: title.text.trim(),
          startsAt: startsAt,
          area: area.text.trim(),
          city: city.text.trim(),
          venue: venue.text.trim(),
          note: note.text.trim(),
          lookingFor: lookingFor.text.trim(),
          spots: spots,
          event: event,
          expiresAt: DateTime.now().add(hangoutLifetime)));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) showNotice(context, 'Couldn’t post your plan. Try again.');
    } finally {
      if (mounted) setState(() => posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = [for (var i = 0; i < 7; i++) _today().add(Duration(days: i))];
    final customDay = !days.contains(day);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Eyebrow('Host a plan'),
      const SizedBox(height: 10),
      Text('What’s the plan?', style: Theme.of(context).textTheme.headlineMedium),
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
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
              labelText: 'Title', hintText: 'e.g. Late show at PVR')),
      const SizedBox(height: 4),
      const Text('When', style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final d in days)
              Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                      label: Text(_dayLabel(d)),
                      selected: day == d,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => day = d))),
            ChoiceChip(
                avatar: const Icon(Icons.calendar_month_rounded, size: 16),
                label: Text(customDay ? _dayLabel(day) : 'Pick date'),
                selected: customDay,
                showCheckmark: false,
                onSelected: (_) => pickDate()),
          ])),
      const SizedBox(height: 10),
      OutlinedButton.icon(
          onPressed: pickTime,
          icon: const Icon(Icons.schedule_rounded, size: 18),
          label: Text('${_dayLabel(day)} at ${time.format(context)}'),
          style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              alignment: Alignment.centerLeft,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)))),
      const SizedBox(height: 16),
      CityField(controller: city, labelText: 'City'),
      const SizedBox(height: 6),
      TextField(
          controller: area,
          onChanged: (_) => setState(() {}),
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
              labelText: 'Area (everyone sees this)',
              hintText: 'e.g. Kurla, Bandra West',
              prefixIcon: Icon(Icons.map_outlined))),
      const SizedBox(height: 10),
      TextField(
          controller: venue,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
              labelText: 'Exact venue (optional)',
              hintText: 'Only guests you accept will see it',
              prefixIcon: Icon(Icons.lock_outline_rounded))),
      const SizedBox(height: 10),
      TextField(
          controller: note,
          maxLength: 100,
          decoration: const InputDecoration(
              labelText: 'A line about it (optional)',
              hintText: 'e.g. Popcorn’s on me')),
      TextField(
          controller: lookingFor,
          maxLength: 80,
          decoration: const InputDecoration(
              labelText: 'Who are you hoping to meet? (optional)',
              hintText: 'e.g. Film lovers, easy-going people')),
      const SizedBox(height: 16),
      const Text('Got a spare ticket? (optional)',
          style: TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final e in HangoutEvent.values)
          ChoiceChip(
              avatar: Icon(e.icon, size: 16),
              label: Text(e.label),
              selected: event == e,
              showCheckmark: false,
              // Tap again to clear.
              onSelected: (_) => setState(() => event = event == e ? null : e)),
      ]),
      const SizedBox(height: 12),
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
      const SizedBox(height: 6),
      Text('Your post stays up for 24 hours. If you haven’t accepted anyone by then, it comes down.',
          style: TextStyle(fontSize: 12, color: EverlaneColors.muted, height: 1.4)),
      const SizedBox(height: 4),
      Text('Meet in a public place and tell a friend where you’ll be.',
          style: TextStyle(fontSize: 12, color: EverlaneColors.muted)),
      const SizedBox(height: 14),
      GradientButton(
          label: posting ? 'Posting…' : 'Post plan',
          onTap: posting ||
                  title.text.trim().isEmpty ||
                  area.text.trim().isEmpty
              ? null
              : post),
    ]);
  }
}
