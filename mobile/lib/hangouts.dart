import 'package:flutter/material.dart';
import 'cities.dart';
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
                          ? 'Plans within ${store.distance.round()} km of ${store.myCity.split(',').first}. Host one, or ask to join.'
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
                        icon: filter?.icon ?? Icons.groups_outlined,
                        title: 'Nothing planned nearby yet.',
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
    return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: EverlaneColors.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: h.mine
                    ? EverlaneColors.deep.withValues(alpha: .6)
                    : EverlaneColors.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                  Text(host == null
                      ? 'You'
                      : host.age > 0 ? '${host.name}, ${host.age}' : host.name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('${h.kind.label}, hosted by $hostName',
                      style:
                          TextStyle(fontSize: 11, color: EverlaneColors.muted)),
                ])),
            _pill(
                h.spotsLeft == 0
                    ? 'Full'
                    : h.spotsLeft == 1
                        ? '1 spot left'
                        : '${h.spotsLeft} spots left',
                EverlaneColors.star),
          ]),
          const SizedBox(height: 14),
          Text(h.title,
              style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.4)),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.event_rounded, size: 15, color: EverlaneColors.lavender),
            const SizedBox(width: 6),
            Text(h.when, style: const TextStyle(fontSize: 13)),
          ]),
          const SizedBox(height: 4),
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
          const SizedBox(height: 14),
          if (h.mine) ...[
            if (requests.isEmpty)
              Text(
                  store.signedIn
                      ? 'No requests yet. We’ll show them here.'
                      : 'You’re hosting',
                  style: TextStyle(fontSize: 13, color: EverlaneColors.muted)),
            for (final r in requests)
              Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
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
                      : () {
                          store.requestToJoin(h);
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          showNotice(context, 'Request sent to ${host!.name}');
                        },
                  style: FilledButton.styleFrom(
                      backgroundColor: EverlaneColors.like,
                      minimumSize: const Size(0, 42),
                      padding: const EdgeInsets.symmetric(horizontal: 18)),
                  child: Text(switch (h.status) {
                    'pending' => 'Requested',
                    'accepted' => 'You’re in ✓',
                    'declined' => 'Not this time',
                    _ => h.spotsLeft == 0 ? 'Full' : 'Request to join',
                  })),
              // Real members can chat once the host accepts (that matches
              // you); the demo lets you message straight away.
              if (h.status == 'accepted' || !(host?.remote ?? false))
                OutlinedButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                            builder: (_) => ChatScreen(
                                store: store,
                                chat: store.chatWith(host!),
                                draft: h.status == 'accepted'
                                    ? ''
                                    : 'Hi, I’m interested in “${h.title}”. Is there still room?'))),
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
          spots: spots));
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
      Text('Meet in a public place and tell a friend where you’ll be.',
          style: TextStyle(fontSize: 12, color: EverlaneColors.muted)),
      const SizedBox(height: 14),
      GradientButton(
          label: posting ? 'Posting…' : 'Post plan',
          onTap: posting || title.text.trim().isEmpty || area.text.trim().isEmpty
              ? null
              : post),
    ]);
  }
}
