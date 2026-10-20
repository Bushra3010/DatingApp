import 'package:flutter/material.dart';
import 'models.dart';
import 'screens.dart';
import 'theme.dart';

void main() => runApp(const KindredApp());

class KindredApp extends StatefulWidget {
  const KindredApp({super.key});
  @override
  State<KindredApp> createState() => _KindredAppState();
}

class _KindredAppState extends State<KindredApp> {
  final store = PreviewStore();
  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Kindred',
        debugShowCheckedModeBanner: false,
        theme: kindredTheme(),
        home: KindredShell(store: store),
      );
}

class KindredShell extends StatefulWidget {
  const KindredShell({super.key, required this.store});
  final PreviewStore store;
  @override
  State<KindredShell> createState() => _KindredShellState();
}

class _KindredShellState extends State<KindredShell> {
  int selected = 0;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final store = widget.store;
        return ColoredBox(
            color: const Color(0xFFEDE8E2),
            child: Center(
                child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Scaffold(
                appBar: AppBar(
                  toolbarHeight: 76,
                  titleSpacing: 24,
                  title: Row(children: [
                    const Icon(Icons.spa_outlined,
                        color: KindredColors.coral, size: 29),
                    const SizedBox(width: 8),
                    Flexible(
                        child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text('kindred',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontSize: 32))))
                  ]),
                  actions: [
                    const Icon(Icons.location_on_outlined,
                        size: 15, color: KindredColors.muted),
                    const SizedBox(width: 3),
                    const Text('Bengaluru',
                        style: TextStyle(
                            fontSize: 12, color: KindredColors.muted)),
                    const SizedBox(width: 24)
                  ],
                  bottom: const PreferredSize(
                      preferredSize: Size.fromHeight(1),
                      child: Divider(height: 1)),
                ),
                body: IndexedStack(index: selected, children: [
                  DiscoverScreen(store: store),
                  LikesScreen(store: store),
                  MessagesScreen(store: store),
                  ProfileScreen(store: store)
                ]),
                bottomNavigationBar: DecoratedBox(
                    decoration: const BoxDecoration(
                        border:
                            Border(top: BorderSide(color: KindredColors.line))),
                    child: NavigationBar(
                      selectedIndex: selected,
                      onDestinationSelected: (value) =>
                          setState(() => selected = value),
                      backgroundColor: KindredColors.paper,
                      indicatorColor: KindredColors.blush,
                      height: 78,
                      destinations: [
                        const NavigationDestination(
                            icon: Icon(Icons.explore_outlined),
                            selectedIcon: Icon(Icons.explore),
                            label: 'Discover'),
                        NavigationDestination(
                            icon: Badge(
                                isLabelVisible: store.incoming.isNotEmpty,
                                label: Text('${store.incoming.length}'),
                                backgroundColor: KindredColors.coral,
                                child: const Icon(Icons.favorite_border)),
                            selectedIcon: const Icon(Icons.favorite),
                            label: 'Likes you'),
                        const NavigationDestination(
                            icon: Icon(Icons.chat_bubble_outline_rounded),
                            selectedIcon: Icon(Icons.chat_bubble_rounded),
                            label: 'Messages'),
                        const NavigationDestination(
                            icon: Icon(Icons.person_outline_rounded),
                            selectedIcon: Icon(Icons.person_rounded),
                            label: 'You'),
                      ],
                    )),
              ),
            )));
      });
}
