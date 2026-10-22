import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'models.dart';
import 'onboarding.dart';
import 'hangouts.dart';
import 'screens.dart';
import 'theme.dart';

void main() => runApp(const EverlaneApp());

class EverlaneApp extends StatefulWidget {
  const EverlaneApp({super.key, this.onboarded = false});

  /// Skips first-launch onboarding (used by tests).
  final bool onboarded;
  @override
  State<EverlaneApp> createState() => _EverlaneAppState();
}

class _EverlaneAppState extends State<EverlaneApp> {
  final store = PreviewStore();

  @override
  void initState() {
    super.initState();
    store.onboarded = widget.onboarded;
    EverlaneColors.dark = store.darkMode;
    store.addListener(syncTheme);
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
          builder: (context, _) => store.onboarded
              ? EverlaneShell(store: store)
              : OnboardingFlow(store: store)));
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

  Widget menuItem(
          IconData icon, String title, Color color, VoidCallback onTap) =>
      ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 26, vertical: 10),
          leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Colors.white, size: 22)),
          title: Text(title, style: const TextStyle(fontSize: 15)),
          onTap: () {
            Navigator.pop(scaffoldKey.currentContext!);
            onTap();
          });

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
                      drawer: Drawer(
                          backgroundColor: EverlaneColors.paper,
                          width: 310,
                          child: SafeArea(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                const SizedBox(height: 24),
                                Padding(
                                    padding: const EdgeInsets.all(26),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _Avatar(name: store.myName, size: 48),
                                          const SizedBox(height: 24),
                                          Text(
                                              '${store.myName}, ${store.myAge}',
                                              style: const TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w700)),
                                          const SizedBox(height: 6),
                                          Text('Bengaluru, India',
                                              style: TextStyle(
                                                  color: EverlaneColors.muted)),
                                        ])),
                                const SizedBox(height: 16),
                                menuItem(
                                    Icons.favorite_rounded,
                                    'Likes you · ${store.incoming.length}',
                                    EverlaneColors.like,
                                    () => setState(() => selected = 2)),
                                menuItem(
                                    Icons.chat_bubble_outline_rounded,
                                    'Matches',
                                    EverlaneColors.boost,
                                    () => setState(() => selected = 3)),
                                menuItem(
                                    Icons.search_rounded,
                                    'Looking for',
                                    EverlaneColors.deep,
                                    () => showFilters(context, store)),
                                menuItem(
                                    Icons.groups_rounded,
                                    'Hangouts',
                                    EverlaneColors.boost,
                                    () => openHangouts(context, store)),
                                menuItem(
                                    Icons.workspace_premium_rounded,
                                    'Membership · ${store.plan.title}',
                                    EverlaneColors.star,
                                    () => openMembership(context, store)),
                                menuItem(
                                    Icons.settings_outlined,
                                    'Settings',
                                    EverlaneColors.pass,
                                    () => setState(() => selected = 4)),
                                const Spacer(),
                                const Padding(
                                    padding: EdgeInsets.all(26),
                                    child: Text('Everlane',
                                        style: TextStyle(
                                            fontSize: 25,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -1))),
                              ]))),
                      appBar: AppBar(
                          toolbarHeight: 88,
                          automaticallyImplyLeading: false,
                          titleSpacing: 24,
                          title: Row(children: [
                            IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Open profile menu',
                                onPressed: () =>
                                    scaffoldKey.currentState!.openDrawer(),
                                icon: _Avatar(name: store.myName)),
                            const Spacer(),
                            const Text('Everlane',
                                style: TextStyle(
                                    fontSize: 23,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -1)),
                            const Spacer(),
                            IconButton(
                                tooltip: 'Filter profiles',
                                onPressed: () => showFilters(context, store),
                                icon: Icon(Icons.tune_rounded,
                                    color: EverlaneColors.muted, size: 25)),
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
                                      child: NavigationBar(selectedIndex: selected, onDestinationSelected: (value) => setState(() => selected = value), backgroundColor: Colors.transparent, indicatorColor: EverlaneColors.deep.withValues(alpha: .3), height: 76, destinations: [
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
  const _Avatar({required this.name, this.size = 36});
  final String name;
  final double size;
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
