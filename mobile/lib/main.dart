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
      home: KindredShell(store: store));
}

class KindredShell extends StatefulWidget {
  const KindredShell({super.key, required this.store});
  final PreviewStore store;
  @override
  State<KindredShell> createState() => _KindredShellState();
}

class _KindredShellState extends State<KindredShell> {
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
            color: const Color(0xFFFCE9EC),
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Scaffold(
                      key: scaffoldKey,
                      drawer: Drawer(
                          backgroundColor: Colors.white,
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
                                          Text('${store.myName}, 29',
                                              style: const TextStyle(
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w700)),
                                          const SizedBox(height: 6),
                                          const Text('Bengaluru, India',
                                              style: TextStyle(
                                                  color: KindredColors.muted)),
                                        ])),
                                const SizedBox(height: 16),
                                menuItem(
                                    Icons.favorite_rounded,
                                    'Likes you · ${store.incoming.length}',
                                    KindredColors.red,
                                    () => setState(() => selected = 1)),
                                menuItem(
                                    Icons.chat_bubble_outline_rounded,
                                    'Matches',
                                    KindredColors.blue,
                                    () => setState(() => selected = 2)),
                                menuItem(
                                    Icons.search_rounded,
                                    'Looking for',
                                    KindredColors.purple,
                                    () => showFilters(context, store)),
                                menuItem(
                                    Icons.settings_outlined,
                                    'Settings',
                                    KindredColors.lime,
                                    () => setState(() => selected = 3)),
                                const Spacer(),
                                const Padding(
                                    padding: EdgeInsets.all(26),
                                    child: Text('kindred',
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
                            const Text('kindred',
                                style: TextStyle(
                                    fontSize: 23,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -1)),
                            const Spacer(),
                            IconButton(
                                tooltip: 'Filter profiles',
                                onPressed: () => showFilters(context, store),
                                icon: const Icon(Icons.tune_rounded,
                                    color: KindredColors.muted, size: 25)),
                          ])),
                      body: IndexedStack(index: selected, children: [
                        DiscoverScreen(store: store),
                        LikesScreen(store: store),
                        MessagesScreen(store: store),
                        ProfileScreen(store: store)
                      ]),
                      bottomNavigationBar: Container(
                          decoration: const BoxDecoration(color: Colors.white, boxShadow: [
                            BoxShadow(
                                color: Color(0x08000000),
                                blurRadius: 20,
                                offset: Offset(0, -4))
                          ]),
                          child: NavigationBarTheme(
                              data: NavigationBarThemeData(
                                  labelTextStyle: WidgetStateProperty.resolveWith(
                                      (states) => TextStyle(
                                          fontSize: 10,
                                          fontWeight: states.contains(WidgetState.selected)
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                          color: states.contains(WidgetState.selected)
                                              ? KindredColors.plum
                                              : KindredColors.muted)),
                                  iconTheme: WidgetStateProperty.resolveWith(
                                      (states) => IconThemeData(
                                          size: 26,
                                          color: states.contains(WidgetState.selected)
                                              ? KindredColors.plum
                                              : const Color(0xFFBDBDBF)))),
                              child: NavigationBar(selectedIndex: selected, onDestinationSelected: (value) => setState(() => selected = value), backgroundColor: Colors.white, indicatorColor: Colors.transparent, height: 76, destinations: [
                                const NavigationDestination(
                                    icon: Icon(Icons.home_outlined),
                                    selectedIcon: Icon(Icons.home_rounded),
                                    label: 'Discover'),
                                NavigationDestination(
                                    icon: Badge(
                                        isLabelVisible:
                                            store.incoming.isNotEmpty,
                                        backgroundColor: KindredColors.red,
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
                              ]))),
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
                color: KindredColors.blush,
                borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Text(name.isEmpty ? 'K' : name[0],
                style: TextStyle(
                    fontSize: size * .48,
                    color: KindredColors.coral,
                    fontWeight: FontWeight.w600))),
        Positioned(
            right: -2,
            top: -2,
            child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: KindredColors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5)))),
      ]);
}
