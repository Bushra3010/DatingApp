import 'package:flutter_test/flutter_test.dart';
import 'package:everlane/cities.dart';

void main() {
  test('Typing a small town suggests it', () {
    final s = suggestCities('Shirdi');
    expect(s.first.label, 'Shirdi, Maharashtra');
    expect(suggestCities('Shir').map((c) => c.name), contains('Shirdi'));
  });

  test('Main cities still come first', () {
    expect(suggestCities('Pune').first.label, 'Pune, Maharashtra');
    expect(suggestCities('Bombay').first.name, 'Mumbai');
  });

  test('Location in Shirdi finds Shirdi, not "couldn’t match"', () {
    expect(nearestCity(19.766, 74.477)?.name, 'Shirdi');
  });

  test('Location in a big city finds the city', () {
    expect(nearestCity(18.52, 73.85)?.name, 'Pune');
    expect(nearestCity(19.88, 75.34)?.name,
        anyOf('Aurangabad', 'Chhatrapati Sambhajinagar'));
  });

  test('There are thousands of towns', () {
    expect(indianTowns.length, greaterThan(5000));
  });
}
