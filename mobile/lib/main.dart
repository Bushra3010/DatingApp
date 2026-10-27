import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'backend.dart';
import 'models.dart';
import 'onboarding.dart';
import 'hangouts.dart';
import 'match_celebration.dart';
import 'screens.dart';
import 'side_menu.dart';
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
  const EverlaneApp({super.key, this.onboarded = false, this.backend});

  /// Skips first-launch onboarding (used by tests).
  final bool onboarded;

  /// Supabase for the member's own account and profile; null in tests.
  final ProfileBackend? backend;
  @override
  State<EverlaneApp> createState() => _EverlaneAppState();
}

class _EverlaneAppState extends State<EverlaneApp> {
  late final store = PreviewStore(backend: widget.backend);

  @override
  void initState() {
    super.initState();
    store.onboarded = widget.onboarded;
    EverlaneColors.dark = store.darkMode;
    store.addListener(syncTheme);
    store.loadContent();
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

  @override
  void dispose() {
    store.removeListener(syncTheme);
    store.dispose();
    EverlaneColors.dark = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
      title: 'Everlane',
      debugShowCheckedModeBanner: false,
      theme: everlaneTheme(),
      home: ListenableBuilder(
          listenable: store,
          builder: (context, _) => store.restoring
              ? const _Splash()
              : store.onboarded
                  ? EverlaneShell(store: store)
                  : OnboardingFlow(store: store)));
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

  @override
  void initState() {
    super.initState();
    widget.store.newMatch.addListener(celebrate);
  }

  @override
  void dispose() {
    widget.store.newMatch.removeListener(celebrate);
    super.dispose();
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
        return ColoredBox(
            color: EverlaneColors.dark
                ? const Color(0xFF07060B)
                : const Color(0xFFEFE6FB),
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Scaffold(
                      key: scaffoldKey,
                      drawer: SideMenu(
                          name: store.myName,
                          age: store.myAge,
                          location: 'Bengaluru, India',
                          items: [
                            SideMenuItem(
                                Icons.monitor_heart_rounded,
                                'Likes you · ${store.incoming.length}',
                                const [Color(0xFFFF7AB6), Color(0xFFE11D48)],
                                fromMenu(() => setState(() => selected = 2)),
                                badge: store.incoming.length),
                            SideMenuItem(
                                Icons.forum_rounded,
                                'Matches',
                                const [Color(0xFF7AF5E0), Color(0xFF0EA5A0)],
                                fromMenu(() => setState(() => selected = 3))),
                            SideMenuItem(
                                Icons.person_search_rounded,
                                'Looking for',
                                const [Color(0xFFC4B5FD), Color(0xFF7C3AED)],
                                fromMenu(() => showFilters(context, store))),
                            SideMenuItem(
                                Icons.groups_rounded,
                                'Hangouts',
                                const [Color(0xFF86EFAC), Color(0xFF10B981)],
                                fromMenu(() => openHangouts(context, store))),
                            SideMenuItem(
                                Icons.workspace_premium_rounded,
                                'Membership · ${store.plan.title}',
                                const [Color(0xFFFFD166), Color(0xFFF97316)],
                                fromMenu(() => openMembership(context, store))),
                            SideMenuItem(
                                Icons.settings_rounded,
                                'Settings',
                                const [Color(0xFFDDD6FE), Color(0xFF8B5CF6)],
                                fromMenu(() => setState(() => selected = 4))),
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
                                    child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Image.asset(
                                              'assets/images/app_logo.png',
                                              width: 34,
                                              height: 34),
                                          const SizedBox(width: 8),
                                          Text('Everlane',
                                              style: EverlaneFonts.logo(
                                                  size: 36)),
                                        ]))),
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
                        ExploreScreen(store: store),
                        LikesScreen(store: store),
                        MessagesScreen(store: store),
                        ProfileScreen(store: store)
                      ]),
                      bottomNavigationBar: ClipRRect(
                          child: BackdropFilter(
                              filter:
                                  ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                              child: Container(
                                  decoration: BoxDecoration(
                                      color: EverlaneColors.card
                                          .withValues(alpha: .78),
                                      border: Border(
                                          top: BorderSide(
                                              color: EverlaneColors.line)),
                                      boxShadow: [
                                        BoxShadow(
                                            color: EverlaneColors.deep
                                                .withValues(alpha: .18),
                                            blurRadius: 24,
                                            offset: const Offset(0, -6))
                                      ]),
                                  child: NavigationBarTheme(
                                      data: NavigationBarThemeData(
                                          labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
                                              fontSize: 10,
                                              fontWeight: states.contains(WidgetState.selected)
                                                  ? FontWeight.w700
                                                  : FontWeight.w400,
                                              color: states.contains(WidgetState.selected)
                                                  ? EverlaneColors.lavender
                                                  : EverlaneColors.muted)),
                                          iconTheme: WidgetStateProperty.resolveWith(
                                              (states) => IconThemeData(
                                                  size: 25,
                                                  color: states.contains(WidgetState.selected)
                                                      ? EverlaneColors.lavender
                                                      : EverlaneColors.muted))),
                                      child: NavigationBar(selectedIndex: selected, onDestinationSelected: (value) {
                                        setState(() => selected = value);
                                        // Pick up anyone who joined since.
                                        if (value == 0) store.refreshMembers();
                                      }, backgroundColor: Colors.transparent, indicatorColor: EverlaneColors.deep.withValues(alpha: .3), height: 76, destinations: [
                                const NavigationDestination(
                                    icon: Icon(Icons.home_outlined),
                                    selectedIcon: Icon(Icons.home_rounded),
                                    label: 'Discover'),
                                const NavigationDestination(
                                    icon: Icon(Icons.explore_outlined),
                                    selectedIcon: Icon(Icons.explore_rounded),
                                    label: 'Explore'),
                                NavigationDestination(
                                    icon: Badge(
                                        isLabelVisible:
                                            store.incoming.isNotEmpty,
                                        backgroundColor: EverlaneColors.like,
                                        smallSize: 7,
                                        child: const Icon(
                                            Icons.favorite_border_rounded)),
                                    selectedIcon:
                                        const Icon(Icons.favorite_rounded),
                                    label: 'Likes you'),
                                const NavigationDestination(
                                    icon:
                                        Icon(Icons.chat_bubble_outline_rounded),
                                    selectedIcon:
                                        Icon(Icons.chat_bubble_rounded),
                                    label: 'Messages'),
                                const NavigationDestination(
                                    icon: Icon(Icons.person_outline_rounded),
                                    selectedIcon: Icon(Icons.person_rounded),
                                    label: 'You'),
                              ]))))),
                    ))));
      });
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
