import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';

/// A colour a family member can pick for their account, shown as a bar on
/// the left edge of their dives.
///
/// A fixed set rather than a free colour picker: six choices are enough to
/// tell a family apart at a glance, they are guaranteed to stay legible on
/// both the light and the dark card surface, and nobody can accidentally
/// pick the same near-white twice.
///
/// Stored by [name], never as a raw colour value - that way the palette can
/// be adjusted later without stored accounts turning a different colour,
/// and light/dark can use different shades of the same choice.
///
/// The colour is always supporting information. Every dive that carries a
/// bar also names its diver in text, so nothing depends on distinguishing
/// the hues - which matters for the roughly one in twelve men who would
/// struggle to.
enum AccountColor {
  coral(Color(0xFFD1452B), Color(0xFFFF8A6B)),
  amber(Color(0xFFB07000), Color(0xFFF0B84A)),
  green(Color(0xFF2A7A47), Color(0xFF6BCB8B)),
  blue(Color(0xFF2A5FCC), Color(0xFF7FA8FF)),
  violet(Color(0xFF6D3F9E), Color(0xFFBA92E8)),
  pink(Color(0xFFB03270), Color(0xFFF48FBC));

  const AccountColor(this._light, this._dark);

  /// The name is not stored on the enum: it has to change with the app
  /// language, and an enum constant cannot.
  String label(AppStrings s) => s.colourNames[index];

  /// Darker on a light card, lighter on a dark one - the same choice has to
  /// carry on both surfaces.
  final Color _light;
  final Color _dark;

  Color resolve(Brightness brightness) =>
      brightness == Brightness.dark ? _dark : _light;

  Color of(BuildContext context) => resolve(Theme.of(context).brightness);

  /// Text or icon colour that stays readable on top of this one. The dark
  /// variants are light enough that white on them would not be.
  Color inkOn(BuildContext context) => of(context).computeLuminance() > 0.45
      ? const Color(0xFF14201E)
      : Colors.white;

  /// Reads a stored name. Unknown or missing values mean "no colour", so a
  /// palette entry removed later degrades to no bar rather than crashing.
  static AccountColor? byName(String? name) {
    if (name == null) return null;
    for (final color in values) {
      if (color.name == name) return color;
    }
    return null;
  }
}
