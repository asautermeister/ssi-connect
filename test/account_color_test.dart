import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/accounts/models/account_color.dart';

void main() {
  group('AccountColor storage', () {
    test('round-trips through its name', () {
      for (final color in AccountColor.values) {
        expect(AccountColor.byName(color.name), color);
      }
    });

    test('an unknown or missing name means no colour, not a crash', () {
      // A palette entry removed in a later version has to degrade to "no
      // bar" rather than take the account list down with it.
      expect(AccountColor.byName('chartreuse'), isNull);
      expect(AccountColor.byName(null), isNull);
      expect(AccountColor.byName(''), isNull);
    });
  });

  group('AccountColor legibility', () {
    test('every colour differs in both themes', () {
      for (final brightness in Brightness.values) {
        final seen = AccountColor.values
            .map((c) => c.resolve(brightness).toARGB32())
            .toSet();
        expect(seen, hasLength(AccountColor.values.length));
      }
    });

    test('every colour stands out against its card surface', () {
      // The bar is a 5px stripe, so it does not need text contrast - but it
      // does have to be visible, which a near-surface colour would not be.
      const lightSurface = Color(0xFFFFFFFF);
      const darkSurface = Color(0xFF16211E);

      double contrast(Color a, Color b) {
        final l1 = a.computeLuminance();
        final l2 = b.computeLuminance();
        final (lighter, darker) = l1 > l2 ? (l1, l2) : (l2, l1);
        return (lighter + 0.05) / (darker + 0.05);
      }

      for (final color in AccountColor.values) {
        expect(
          contrast(color.resolve(Brightness.light), lightSurface),
          greaterThan(3.0),
          reason: '${color.label} verschwindet auf der hellen Karte',
        );
        expect(
          contrast(color.resolve(Brightness.dark), darkSurface),
          greaterThan(3.0),
          reason: '${color.label} verschwindet auf der dunklen Karte',
        );
      }
    });

    test('each colour has a readable label, never just a hue', () {
      // The picker names its swatches, so it works without seeing colour.
      for (final color in AccountColor.values) {
        expect(color.label, isNotEmpty);
      }
    });
  });
}
