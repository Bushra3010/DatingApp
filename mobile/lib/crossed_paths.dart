import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'cities.dart';
import 'models.dart';
import 'screens.dart' show PersonDetailsScreen;
import 'theme.dart';
import 'widgets.dart';

/// Indiranagar, Bengaluru: where the demo people are (account-less preview).
const _demoCentre = LatLng(12.9719, 77.6300);

/// Middle of India, when nothing better is known yet.
const _indiaCentre = LatLng(22.5, 79.0);

/// Asks for the current position once, at low accuracy (the store rounds it
/// to a ~1 km area anyway). Returns an error to show, or null on success.
Future<String?> shareMyArea(PreviewStore store) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'Turn on location services to see who you’ve crossed paths with.';
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return 'Allow location access to see who you’ve crossed paths with.';
    }
    final at = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.low));
    await store.recordArea(at.latitude, at.longitude);
    return null;
  } catch (_) {
    return 'Couldn’t find your area. Try again.';
  }
}

String _when(DateTime day) {
  final now = DateTime.now();
  final days = DateTime(now.year, now.month, now.day)
      .difference(DateTime(day.year, day.month, day.day))
      .inDays;
  return switch (days) {
    <= 0 => 'Today',
    1 => 'Yesterday',
    _ => '$days days ago',
  };
}

/// Happn-style: a map of areas where you and someone else were on the same
/// day, and who they were.
class CrossedPathsScreen extends StatefulWidget {
  const CrossedPathsScreen({super.key, required this.store});
  final PreviewStore store;
  @override
  State<CrossedPathsScreen> createState() => _CrossedPathsScreenState();
}

class _CrossedPathsScreenState extends State<CrossedPathsScreen> {
  final map = MapController();
  String? selected;
  bool locating = false;
  bool mapReady = false;

  /// Where the map was last moved to automatically, so it only follows
  /// new information (your position arriving) and not every rebuild.
  LatLng? movedTo;

  @override
  void initState() {
    super.initState();
    widget.store.refreshCrossings();
    if (widget.store.live) locateMe(quiet: true);
  }

  /// Finds where you are and centres the map there. While sharing is on,
  /// that also records today's area and reloads who you crossed paths with.
  Future<void> locateMe({bool quiet = false}) async {
    final store = widget.store;
    setState(() => locating = true);
    final at = await currentPosition();
    if (!mounted) return;
    setState(() => locating = false);
    if (at == null) {
      if (!quiet) {
        showNotice(context,
            'Couldn’t find your location. Allow location access for Everlane and try again.');
      }
      return;
    }
    if (store.shareArea) {
      await store.recordArea(at.$1, at.$2);
    } else {
      store.myPosition = snapToArea(at.$1, at.$2);
      store.update();
    }
  }

  Future<void> share() async {
    setState(() => locating = true);
    final error = await shareMyArea(widget.store);
    if (!mounted) return;
    setState(() => locating = false);
    if (error != null) {
      showNotice(context, error);
      return;
    }
    final me = widget.store.myArea;
    if (me != null && mapReady) map.move(LatLng(me.$1, me.$2), 13);
  }

  /// Your city's centre, from the profile.
  LatLng? get cityCentre {
    final city = widget.store.myCity;
    if (city.trim().isEmpty) return null;
    final match = suggestCities(city, limit: 1).firstOrNull;
    return match == null ? null : LatLng(match.lat, match.lng);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final store = widget.store;
        final areas = <String, List<Crossing>>{};
        for (final c in store.crossings) {
          (areas[c.areaKey] ??= []).add(c);
        }
        final shown = selected == null
            ? store.crossings
            : areas[selected] ?? const <Crossing>[];
        final me = store.myArea ?? store.myPosition;
        final first = store.crossings.firstOrNull;
        final city = store.live ? cityCentre : null;
        final centre = me != null
            ? LatLng(me.$1, me.$2)
            : first != null
                ? LatLng(first.lat, first.lng)
                : city ??
                    (store.live ? _indiaCentre : _demoCentre);
        final zoom = me != null || first != null
            ? 13.0
            : city != null
                ? 11.0
                : store.live
                    ? 4.5
                    : 12.0;
        // Follow your position once it's found.
        if (mapReady && me != null && movedTo != centre) {
          movedTo = centre;
          WidgetsBinding.instance
              .addPostFrameCallback((_) => map.move(centre, 13));
        }
        return Scaffold(
            appBar: AppBar(
                title: const Text('Crossed paths',
                    style: TextStyle(fontSize: 17))),
            body: Column(children: [
              Expanded(
                  flex: 5,
                  child: FlutterMap(
                      mapController: map,
                      options: MapOptions(
                          initialCenter: centre,
                          initialZoom: zoom,
                          minZoom: 4,
                          onMapReady: () {
                            mapReady = true;
                            if (me != null) movedTo = centre;
                          },
                          maxZoom: 15,
                          onTap: (_, __) => setState(() => selected = null)),
                      children: [
                        // OpenStreetMap's own tiles are for light use only;
                        // switch to a paid provider (MapTiler, Mapbox,
                        // Stadia) before launch.
                        TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            tileBuilder: EverlaneColors.dark
                                ? darkModeTileBuilder
                                : null,
                            userAgentPackageName: 'app.everlane'),
                        MarkerLayer(markers: [
                          for (final MapEntry(:key, :value) in areas.entries)
                            Marker(
                                point: LatLng(value.first.lat, value.first.lng),
                                width: 64,
                                height: 64,
                                child: _AreaBubble(
                                    count: value.length,
                                    selected: key == selected,
                                    onTap: () => setState(() =>
                                        selected = key == selected ? null : key))),
                          if (me != null)
                            Marker(
                                point: LatLng(me.$1, me.$2),
                                width: 22,
                                height: 22,
                                child: const _MeDot()),
                        ]),
                        const SimpleAttributionWidget(
                            source: Text('© OpenStreetMap contributors',
                                style: TextStyle(fontSize: 10))),
                        Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: FloatingActionButton.small(
                                    heroTag: 'locate-me',
                                    tooltip: 'Show my location',
                                    onPressed: locating
                                        ? null
                                        : () {
                                            movedTo = null;
                                            locateMe();
                                          },
                                    child: locating
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2))
                                        : const Icon(
                                            Icons.my_location_rounded)))),
                      ])),
              Expanded(
                  flex: 4,
                  child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                          color: EverlaneColors.paper,
                          border: Border(
                              top: BorderSide(color: EverlaneColors.line))),
                      child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                          children: [
                            _ShareCard(
                                sharing: store.shareArea,
                                locating: locating,
                                live: store.live,
                                onShare: share,
                                onStop: store.stopSharingArea),
                            const SizedBox(height: 18),
                            Eyebrow(selected == null
                                ? 'You crossed paths with'
                                : shown.firstOrNull?.area.isNotEmpty ?? false
                                    ? 'You crossed paths near ${shown.first.area}'
                                    : 'You crossed paths in this area'),
                            const SizedBox(height: 12),
                            if (shown.isEmpty && store.live && !store.crossingsLoaded)
                              const Center(
                                  child: Padding(
                                      padding: EdgeInsets.all(12),
                                      child: CircularProgressIndicator()))
                            else if (shown.isEmpty)
                              Text(
                                  store.shareArea
                                      ? 'No one yet. Paths you cross over the next few days show up here.'
                                      : 'Share your area to start finding people you’ve crossed paths with.',
                                  style: TextStyle(
                                      color: EverlaneColors.muted, height: 1.5))
                            else
                              for (final c in shown)
                                Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _CrossingTile(
                                        crossing: c,
                                        onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute<void>(
                                                builder: (_) =>
                                                    PersonDetailsScreen(
                                                        person: c.person,
                                                        store: store))))),
                          ]))),
            ]));
      });
}

class _ShareCard extends StatelessWidget {
  const _ShareCard(
      {required this.sharing,
      required this.locating,
      required this.live,
      required this.onShare,
      required this.onStop});
  final bool sharing, locating, live;
  final VoidCallback onShare, onStop;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: EverlaneColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: EverlaneColors.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.shield_outlined, size: 18, color: EverlaneColors.boost),
          const SizedBox(width: 8),
          Expanded(
              child: Text(sharing ? 'Sharing your area' : 'Your area stays private',
                  style: const TextStyle(fontWeight: FontWeight.w700))),
          Switch(
              value: sharing,
              onChanged: locating
                  ? null
                  : (on) => on ? onShare() : onStop()),
        ]),
        const SizedBox(height: 4),
        Text(
            'We only store a rough ~1 km area and date, never your exact location or time. Areas are deleted after 30 days, or straightaway when you turn this off.'
            '${live ? '' : ' In this preview the people shown are demo profiles.'}',
            style: TextStyle(
                fontSize: 12, height: 1.5, color: EverlaneColors.muted)),
      ]));
}

class _AreaBubble extends StatelessWidget {
  const _AreaBubble(
      {required this.count, required this.selected, required this.onTap});
  final int count;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      label: count == 1
          ? 'Area where you crossed paths with 1 person'
          : 'Area where you crossed paths with $count people',
      child: GestureDetector(
          onTap: onTap,
          child: Center(
              child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: selected ? 58 : 48,
                  height: selected ? 58 : 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: EverlaneColors.premiumGradient,
                      border: Border.all(
                          color: Colors.white, width: selected ? 3 : 2),
                      boxShadow: [
                        BoxShadow(
                            color: EverlaneColors.like.withValues(alpha: .45),
                            blurRadius: selected ? 22 : 12)
                      ]),
                  child: Text('$count',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800))))));
}

class _MeDot extends StatelessWidget {
  const _MeDot();
  @override
  Widget build(BuildContext context) => Semantics(
      label: 'Your area',
      child: Container(
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: EverlaneColors.boost,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                    color: EverlaneColors.boost.withValues(alpha: .5),
                    blurRadius: 12)
              ])));
}

class _CrossingTile extends StatelessWidget {
  const _CrossingTile({required this.crossing, required this.onTap});
  final Crossing crossing;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = crossing.person;
    return Material(
        color: EverlaneColors.card,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
            onTap: onTap,
            child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(children: [
                  Portrait(p, height: 64, width: 56, radius: 14),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Row(children: [
                          Flexible(
                              child: Text('${p.name}, ${p.age}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700))),
                          if (p.verified) ...[
                            const SizedBox(width: 5),
                            const Icon(Icons.verified,
                                size: 15, color: EverlaneColors.boost),
                          ],
                        ]),
                        const SizedBox(height: 3),
                        Text(
                            '${_when(crossing.lastDay)} · '
                            '${crossing.times == 1 ? 'Crossed once' : 'Crossed ${crossing.times} times'}',
                            style: TextStyle(
                                fontSize: 12, color: EverlaneColors.muted)),
                        if (crossing.area.isNotEmpty)
                          Text(crossing.area,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12, color: EverlaneColors.lavender)),
                      ])),
                  Icon(Icons.chevron_right_rounded,
                      color: EverlaneColors.muted),
                ]))));
  }
}
