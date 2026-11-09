import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everlane/crossed_paths.dart';
import 'package:everlane/models.dart';
import 'package:everlane/theme.dart';

class _SignedInStore extends PreviewStore {
  @override
  bool get signedIn => true;
}

Future<void> open(WidgetTester tester, PreviewStore store) async {
  tester.view.physicalSize = const Size(700, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
      theme: everlaneTheme(), home: CrossedPathsScreen(store: store)));
  await tester.pump();
}

MapCamera camera(WidgetTester tester) =>
    MapCamera.of(tester.element(find.byType(TileLayer)));

void main() {
  testWidgets('Signed in: no demo crossings, map starts at your position',
      (tester) async {
    final store = _SignedInStore()..myPosition = (18.525, 73.855);
    await open(tester, store);
    expect(store.crossings, isEmpty);
    final c = camera(tester).center;
    expect(c.latitude, closeTo(18.525, .01));
    expect(c.longitude, closeTo(73.855, .01));
    expect(find.byTooltip('Show my location'), findsOneWidget);
  });

  testWidgets('Signed in without a position: your city, not Bengaluru',
      (tester) async {
    final store = _SignedInStore()..myCity = 'Pune, Maharashtra';
    await open(tester, store);
    final c = camera(tester).center;
    expect(c.latitude, closeTo(18.52, .2));
  });

  testWidgets('The preview keeps the demo map', (tester) async {
    final store = PreviewStore();
    await open(tester, store);
    expect(store.crossings, isNotEmpty);
  });
}
