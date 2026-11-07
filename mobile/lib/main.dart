import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin.dart';
import 'backend.dart';
import 'models.dart';
import 'onboarding.dart';
import 'hangouts.dart';
import 'legal.dart' show legalBackend;
import 'match_celebration.dart';
import 'screens.dart';
import 'side_menu.dart';
import 'support.dart';
import 'supabase_config.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ProfileBackend? backend;
  try {
    await Supabase.initialize(
        url: supabaseUrl, publishableKey: supabasePublishableKey);
    backend = ProfileBackend(Supabase.instance.client);
  } catch (_) {
    // Offline or misconfigured: the preview still runs, in memory only.
  }
  runApp(EverlaneApp(backend: backend));
}

class EverlaneApp extends StatefulWidget {
  const EverlaneApp(
      {super.key, this.onboarded = false, this.backend, this.store});

  /// Skips first-launch onboarding (used by tests).
  final bool onboarded;

  /// Supabase for the member's own account and profile; null in tests.
  final ProfileBackend? backend;

  /// A ready-made store (tests use it to set admin settings and the like).
  final PreviewStore? store;
  @override
  State<EverlaneApp> createState() => _EverlaneAppState();
}

class _EverlaneAppState extends State<EverlaneApp> {
  late final store = widget.store ?? PreviewStore(backend: widget.backend);

  /// Admin settings (maintenance, versions, flags) are re-checked whenever
  /// the app comes back to the front.
  late final AppLifecycleListener lifecycle;

  /// App-wide snackbars, shown on whichever screen is open.
  final messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    if (widget.onboarded) store.onboarded = true;
    EverlaneColors.dark = store.darkMode;
    store.addListener(syncTheme);
    store.planActivated.addListener(planActivated);
    lifecycle = AppLifecycleListener(onResume: () {
      store.loadSettings();
      store.loadAnnouncements();
      store.loadTickets();
      store.loadUpiPayments();
    });
    legalBackend = store.backend;
    store.loadSettings();
    store.loadContent();
    store.loadFilters();
    if (!store.signedIn) store.loadAnnouncements();
    // A returning member with a saved session goes straight to their profile.
    if (store.signedIn) {
      store.restoring = true;
      store.loadProfile().catchError((Object _) => false).whenComplete(() {
        store.restoring = false;
        store.update();
      });
    }
  }

  /// Colours are read at build time, so a theme change rebuilds every
  /// element, including routes and sheets that are already open.
  void syncTheme() {
    if (store.darkMode == EverlaneColors.dark) return;
    setState(() => EverlaneColors.dark = store.darkMode);
    void rebuild(Element element) {
      element.markNeedsBuild();
      element.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }

  /// A UPI payment was verified and the plan is on.
  void planActivated() {
    final text = store.planActivated.value;
    if (text == null) return;
    store.planActivated.value = null;
    messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(text), duration: const Duration(seconds: 6)));
  }

  @override
  void dispose() {
    lifecycle.dispose();
    store.planActivated.removeListener(planActivated);
    store.removeListener(syncTheme);
    store.dispose();
    EverlaneColors.dark = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
      title: 'Everlane',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: messengerKey,
      theme: everlaneTheme(),
      home: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            // What admins set in the panel comes first.
            if (store.maintenance) return MaintenanceScreen(store: store);
            if (store.updateRequired) return UpdateRequiredScreen(store: store);
            if (store.restriction case final r?) {
              return AccountRestrictedScreen(store: store, restriction: r);
            }
            if (store.restoring) return const _Splash();
            return store.onboarded
                ? EverlaneShell(store: store)
                : OnboardingFlow(store: store);
          }));
}

class _Splash extends StatefulWidget {
  const _Splash();
  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> with SingleTickerProviderStateMixin {
  late final pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat(reverse: true);

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        ScaleTransition(
            scale: Tween(begin: 1.0, end: 1.06).animate(
                CurvedAnimation(parent: pulse, curve: Curves.easeInOut)),
            child: Image.asset('assets/images/app_logo.png',
                width: 96, height: 96)),
        const SizedBox(height: 14),
        Text('Everlane', style: EverlaneFonts.logo(size: 44)),
        const SizedBox(height: 20),
        const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: EverlaneColors.like)),
      ])));
}

class EverlaneShell extends StatefulWidget {
  const EverlaneShell({super.key, required this.store});
  final PreviewStore store;
  @override
  State<EverlaneShell> createState() => _EverlaneShellState();
}

class _EverlaneShellState extends State<EverlaneShell> {
  int selected = 0;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  /// Tabs in order: Discover, Hangouts, Likes you, Messages, You. [selected]
  /// is always one of these; Hangouts drops out of the bar when an admin
  /// switches it off, without shifting the others.
  static const discoverTab = 0, hangoutsTab = 1, likesTab = 2, profileTab = 4;

  List<int> get visibleTabs => [
        discoverTab,
        if (widget.store.settings.hangouts) hangoutsTab,
        likesTab,
        3,
        profileTab,
      ];

  bool showingNotice = false;

  @override
  void initState() {
    super.initState();
    widget.store.newMatch.addListener(celebrate);
    widget.store.hangoutAccepted.addListener(hangoutAccepted);
    widget.store.addListener(showNotices);
    WidgetsBinding.instance.addPostFrameCallback((_) => showNotices());
  }

  @override
  void dispose() {
    widget.store.hangoutAccepted.removeListener(hangoutAccepted);
    widget.store.newMatch.removeListener(celebrate);
    widget.store.removeListener(showNotices);
    super.dispose();
  }

  /// 'notice' announcements open once, one after another.
  Future<void> showNotices() async {
    final notice = widget.store.pendingNotice;
    if (notice == null || showingNotice || !mounted) return;
    showingNotice = true;
    await showNoticeAnnouncement(context, widget.store, notice);
    showingNotice = false;
    if (mounted) WidgetsBinding.instance.addPostFrameCallback((_) => showNotices());
  }

  /// A host said yes to your hangout request.
  void hangoutAccepted() {
    final text = widget.store.hangoutAccepted.value;
    if (text == null || !mounted) return;
    widget.store.hangoutAccepted.value = null;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(text),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
              label: 'View',
              onPressed: () => setState(() => selected = hangoutsTab))));
  }

  /// A real member liked you back (or you liked them back from Discover):
  /// celebrate, then offer the chat.
  Future<void> celebrate() async {
    final chat = widget.store.newMatch.value;
    if (chat == null || !mounted) return;
    widget.store.newMatch.value = null;
    final openChat = await Navigator.push<bool>(
        context,
        PageRouteBuilder<bool>(
            transitionDuration: const Duration(milliseconds: 420),
            pageBuilder: (_, __, ___) =>
                MatchCelebration(store: widget.store, person: chat.person),
            transitionsBuilder: (context, animation, _, child) =>
                FadeTransition(opacity: animation, child: child)));
    if (openChat == true && mounted) {
      Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (_) => ChatScreen(store: widget.store, chat: chat)));
    }
  }

  /// Closes the side menu, then runs [onTap].
  VoidCallback fromMenu(VoidCallback onTap) => () {
        Navigator.pop(scaffoldKey.currentContext!);
        onTap();
      };

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final store = widget.store;
        final tabs = visibleTabs;
        // Hangouts was switched off while it was open.
        if (!tabs.contains(selected)) selected = discoverTab;
        return ColoredBox(
            color: EverlaneColors.dark
                ? const Color(0xFF07060B)
                : const Color(0xFFEFE6FB),
            child: Center(
                child: ConstrainedBox(
                    // A phone-width column on tablets and desktops; on a
                    // phone it fills the screen edge to edge.
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width >= 600
                            ? 440
                            : double.infinity),
                    child: Scaffold(
                      key: scaffoldKey,
                      drawer: SideMenu(
                          name: store.myName,
                          age: store.myAge,
                          location: store.myCity,
                          verified: store.myVerified,
                          photo: store.hasPhoto
                              ? MemoryImage(store.myPhotos.first)
                              : null,
                          onEdit: fromMenu(() => editProfile(context, store)),
                          items: [
                            SideMenuItem(
                                const Icon(Icons.favorite_border_rounded),
                                'Admirers',
                                'People who have liked your profile',
                                const Color(0xFFF472B6),
                                fromMenu(() => setState(() => selected = 2)),
                                badge: store.settings.likesYou
                                    ? store.incoming.length
                                    : 0),
                            SideMenuItem(
                                const TwoHeartsIcon(),
                                'Connections',
                                'Your mutual likes and matches',
                                const Color(0xFFC4B5FD),
                                fromMenu(() => setState(() => selected = 3))),
                            SideMenuItem(
                                const Icon(Icons.explore_outlined),
                                'Dating Goals',
                                'What you’re looking for',
                                const Color(0xFFA78BFA),
                                fromMenu(() => showFilters(context, store))),
                            if (store.settings.hangouts)
                              SideMenuItem(
                                  const Icon(Icons.calendar_today_outlined),
                                  'Hangouts',
                                  'Host a plan or join one near you',
                                  const Color(0xFFF9A8D4),
                                  fromMenu(() =>
                                      setState(() => selected = hangoutsTab))),
                            SideMenuItem(
                                const Icon(Icons.travel_explore_rounded),
                                'Explore',
                                'Introductions, nearby and crossed paths',
                                const Color(0xFFA78BFA),
                                fromMenu(() => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                        builder: (_) => Scaffold(
                                            appBar: AppBar(),
                                            body: ExploreScreen(
                                                store: store)))))),
                            SideMenuItem(
                                const CrownIcon(),
                                'Everlane Plus',
                                'Premium plans and exclusive benefits',
                                const Color(0xFFF2A93B),
                                fromMenu(() => openMembership(context, store))),
                            SideMenuItem(
                                const Icon(Icons.settings_outlined),
                                'Preferences',
                                'Account, privacy and app preferences',
                                const Color(0xFFC4B5FD),
                                fromMenu(() => setState(() => selected = 4))),
                            SideMenuItem(
                                const Icon(Icons.help_outline_rounded),
                                'Help & support',
                                'Answers, requests and your data',
                                const Color(0xFFA78BFA),
                                fromMenu(() => openHelp(context, store)),
                                badge: store.unreadTickets),
                            if (store.referralsOn && store.signedIn)
                              SideMenuItem(
                                  const Icon(Icons.card_giftcard_rounded),
                                  'Invite friends',
                                  'Share your code, get Plus',
                                  const Color(0xFFF472B6),
                                  fromMenu(() => openInvite(context, store))),
                          ]),
                      appBar: AppBar(
                          toolbarHeight: 88,
                          automaticallyImplyLeading: false,
                          titleSpacing: 0,
                          // The wordmark is centred on the bar itself, not
                          // between the two icons (which differ in width).
                          title: Stack(alignment: Alignment.center, children: [
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 72),
                                child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text('Everlane',
                                        style: EverlaneFonts.logo(size: 36)))),
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                child: Row(children: [
                                  IconButton(
                                      tooltip: 'Open profile menu',
                                      onPressed: () => scaffoldKey.currentState!
                                          .openDrawer(),
                                      icon: _Avatar(name: store.myName)),
                                  const Spacer(),
                                  // Preferences only apply to Discover.
                                  if (selected == 0)
                                    IconButton(
                                        tooltip: 'Filter profiles',
                                        onPressed: () =>
                                            showFilters(context, store),
                                        icon: Icon(Icons.tune_rounded,
                                            color: EverlaneColors.muted,
                                            size: 25)),
                                ])),
                          ])),
                      body: IndexedStack(index: selected, children: [
                        DiscoverScreen(store: store),
                        store.settings.hangouts
                            ? HangoutsScreen(store: store, embedded: true)
                            : const SizedBox.shrink(),
                        LikesScreen(store: store),
                        MessagesScreen(store: store),
                        ProfileScreen(store: store)
                      ]),
                      bottomNavigationBar: _PillNavBar(
                          // Bar positions map to tab ids through [tabs].
                          selected: tabs.indexOf(selected),
                          onSelect: (i) {
                            final value = tabs[i];
                            setState(() => selected = value);
                            // Pick up anyone who joined since.
                            if (value == discoverTab) store.refreshMembers();
                            if (value == hangoutsTab) store.loadHangouts();
                          },
                          items: [
                            for (final tab in tabs)
                              switch (tab) {
                                discoverTab => const _NavItem(
                                    Icons.home_outlined,
                                    Icons.home_rounded,
                                    'Discover'),
                                hangoutsTab => const _NavItem(
                                    Icons.groups_outlined,
                                    Icons.groups_rounded,
                                    'Hangouts'),
                                likesTab => _NavItem(
                                    Icons.favorite_border_rounded,
                                    Icons.favorite_rounded,
                                    'Likes you',
                                    dot: store.settings.likesYou &&
                                        store.incoming.isNotEmpty),
                                profileTab => const _NavItem(
                                    Icons.person_outline_rounded,
                                    Icons.person_rounded,
                                    'You'),
                                _ => _NavItem(
                                    Icons.chat_bubble_outline_rounded,
                                    Icons.chat_bubble_rounded,
                                    'Messages',
                                    dot: store.unreadMessages > 0),
                              }
                          ]),
                    ))));
      });
}

class _NavItem {
  const _NavItem(this.icon, this.selectedIcon, this.label, {this.dot = false});
  final IconData icon, selectedIcon;
  final String label;

  /// A small pink dot on the icon (new likes).
  final bool dot;
}

/// The tab bar: a floating frosted pill. The open tab widens into a soft
/// highlight with its name; the others show just their icon.
class _PillNavBar extends StatelessWidget {
  const _PillNavBar(
      {required this.selected, required this.onSelect, required this.items});
  final int selected;
  final ValueChanged<int> onSelect;
  final List<_NavItem> items;

  @override
  Widget build(BuildContext context) {
    final accent =
        EverlaneColors.dark ? EverlaneColors.lavender : EverlaneColors.deep;
    return SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 10),
        child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
            child: DecoratedBox(
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(34),
                    boxShadow: [
                      BoxShadow(
                          color: EverlaneColors.deep.withValues(alpha: .18),
                          blurRadius: 28,
                          offset: const Offset(0, 10))
                    ]),
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(34),
                    child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: Container(
                            height: 64,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                                color: EverlaneColors.card.withValues(alpha: .82),
                                borderRadius: BorderRadius.circular(34),
                                border: Border.all(color: EverlaneColors.line)),
                            child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  for (final (i, item) in items.indexed)
                                    Flexible(
                                        flex: i == selected ? 3 : 1,
                                        child: _tab(item, i == selected, accent,
                                            () {
                                          if (i == selected) return;
                                          HapticFeedback.selectionClick();
                                          onSelect(i);
                                        })),
                                ])))))));
  }

  Widget _tab(_NavItem item, bool on, Color accent, VoidCallback onTap) {
    final icon = Icon(on ? item.selectedIcon : item.icon,
        size: 24, color: on ? accent : EverlaneColors.muted);
    return Tooltip(
        message: item.label,
        child: Semantics(
            selected: on,
            button: true,
            label: item.label,
            child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(26),
                child: AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                        color: on
                            ? accent.withValues(alpha: .14)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(26)),
                    child: AnimatedSize(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Inside the Row rather than as padding, so it
                              // goes the moment the tab loses its width.
                              if (on) const SizedBox(width: 10),
                              item.dot
                                  ? Badge(
                                      backgroundColor: EverlaneColors.like,
                                      smallSize: 7,
                                      child: icon)
                                  : icon,
                              if (on) ...[
                                const SizedBox(width: 8),
                                Flexible(
                                    child: Text(item.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.clip,
                                        softWrap: false,
                                        style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: accent))),
                                const SizedBox(width: 10),
                              ],
                            ]))))));
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});
  final String name;
  static const size = 36.0;
  @override
  Widget build(BuildContext context) =>
      Stack(clipBehavior: Clip.none, children: [
        Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
                color: EverlaneColors.blush,
                borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Text(name.isEmpty ? 'E' : name[0],
                style: TextStyle(
                    fontSize: size * .48,
                    color: EverlaneColors.like,
                    fontWeight: FontWeight.w600))),
        Positioned(
            right: -2,
            top: -2,
            child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: EverlaneColors.star,
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: EverlaneColors.paper, width: 1.5)))),
      ]);
}
