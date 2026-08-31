import 'package:flutter/material.dart';

/// Design tokens for SSI Connect.
///
/// The visual language follows Garmin Connect's, since that is where these
/// dives come from and users arrive here straight from that app: a light
/// neutral canvas carrying white cards, a large light-weight number as the
/// hero of every card, small grey labels above/below it, hairline dividers,
/// and very little chrome otherwise. Numbers lead, labels follow.
///
/// What is deliberately *not* borrowed is Garmin's blue - the accent stays
/// our own teal, so the app reads as related to but not part of Garmin.
///
/// Contrast of every ink/accent pairing below was checked against its
/// surface; all clear WCAG AA 4.5:1 (see the design commit for the numbers).
class AppColors {
  const AppColors._();

  // --- light ---
  /// Page background. A neutral biased very slightly toward the accent's
  /// hue rather than a flat grey, so cards sit on something considered.
  static const lightCanvas = Color(0xFFF1F3F2);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightInkPrimary = Color(0xFF14201E);
  static const lightInkSecondary = Color(0xFF55625F);
  static const lightInkMuted = Color(0xFF63706C);
  static const lightHairline = Color(0xFFE2E7E5);
  static const lightAccent = Color(0xFF00696B);
  static const lightAccentContainer = Color(0xFFCDE9E6);

  // --- dark ---
  static const darkCanvas = Color(0xFF0E1513);
  static const darkSurface = Color(0xFF16211E);
  static const darkInkPrimary = Color(0xFFE7EDE9);
  static const darkInkSecondary = Color(0xFFAFBEB9);
  static const darkInkMuted = Color(0xFF8B9A95);
  static const darkHairline = Color(0xFF253531);
  static const darkAccent = Color(0xFF5CDBD0);
  static const darkAccentContainer = Color(0xFF123935);
  static const darkOnAccent = Color(0xFF00312F);

  /// Status colours are reserved: they signal state and are never reused as
  /// decoration, and always ship alongside an icon or label rather than
  /// carrying meaning by hue alone.
  static const statusGood = Color(0xFF0CA30C);
  static const statusWarning = Color(0xFFFAB219);
  static const statusCritical = Color(0xFFD03B3B);

  /// The one deep green in the app. Deliberately not the accent: it says
  /// "settled" - a dive carried over into SSI, a diver whose site is known,
  /// a site's own position.
  ///
  /// The same value in both themes, because it has to hold on the white
  /// scan surface of a QR page as well as on the dark canvas.
  ///
  /// The site's coordinate line is the one place it is not a state - it is
  /// there on every card. It earns the exception by never sharing a screen
  /// with the tick: the SSI screen has no transferred dives on it.
  static const settled = Color(0xFF2E7D32);
}

/// Spacing scale - every gap in the app is one of these.
class AppSpacing {
  const AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

class AppRadius {
  const AppRadius._();

  /// Garmin's cards are barely rounded; the restraint is part of the look.
  static const card = 10.0;
  static const pill = 999.0;
}

/// Semantic colours that Material's [ColorScheme] has no slot for.
/// Reached through `Theme.of(context).extension<AppPalette>()!`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.canvas,
    required this.inkPrimary,
    required this.inkSecondary,
    required this.inkMuted,
    required this.hairline,
    required this.accentContainer,
    required this.meterTrack,
  });

  final Color canvas;
  final Color inkPrimary;
  final Color inkSecondary;
  final Color inkMuted;
  final Color hairline;
  final Color accentContainer;
  final Color meterTrack;

  static const light = AppPalette(
    canvas: AppColors.lightCanvas,
    inkPrimary: AppColors.lightInkPrimary,
    inkSecondary: AppColors.lightInkSecondary,
    inkMuted: AppColors.lightInkMuted,
    hairline: AppColors.lightHairline,
    accentContainer: AppColors.lightAccentContainer,
    meterTrack: Color(0xFFE8EDEB),
  );

  static const dark = AppPalette(
    canvas: AppColors.darkCanvas,
    inkPrimary: AppColors.darkInkPrimary,
    inkSecondary: AppColors.darkInkSecondary,
    inkMuted: AppColors.darkInkMuted,
    hairline: AppColors.darkHairline,
    accentContainer: AppColors.darkAccentContainer,
    meterTrack: Color(0xFF1F2E2A),
  );

  @override
  AppPalette copyWith({
    Color? canvas,
    Color? inkPrimary,
    Color? inkSecondary,
    Color? inkMuted,
    Color? hairline,
    Color? accentContainer,
    Color? meterTrack,
  }) {
    return AppPalette(
      canvas: canvas ?? this.canvas,
      inkPrimary: inkPrimary ?? this.inkPrimary,
      inkSecondary: inkSecondary ?? this.inkSecondary,
      inkMuted: inkMuted ?? this.inkMuted,
      hairline: hairline ?? this.hairline,
      accentContainer: accentContainer ?? this.accentContainer,
      meterTrack: meterTrack ?? this.meterTrack,
    );
  }

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      inkPrimary: Color.lerp(inkPrimary, other.inkPrimary, t)!,
      inkSecondary: Color.lerp(inkSecondary, other.inkSecondary, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      accentContainer: Color.lerp(accentContainer, other.accentContainer, t)!,
      meterTrack: Color.lerp(meterTrack, other.meterTrack, t)!,
    );
  }
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(
    brightness: Brightness.light,
    palette: AppPalette.light,
    surface: AppColors.lightSurface,
    accent: AppColors.lightAccent,
    onAccent: Colors.white,
  );

  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    palette: AppPalette.dark,
    surface: AppColors.darkSurface,
    accent: AppColors.darkAccent,
    onAccent: AppColors.darkOnAccent,
  );

  static ThemeData _build({
    required Brightness brightness,
    required AppPalette palette,
    required Color surface,
    required Color accent,
    required Color onAccent,
  }) {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.lightAccent,
          brightness: brightness,
        ).copyWith(
          primary: accent,
          onPrimary: onAccent,
          surface: surface,
          onSurface: palette.inkPrimary,
          error: AppColors.statusCritical,
        );

    final textTheme = _textTheme(palette);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: palette.canvas,
      textTheme: textTheme,
      extensions: [palette],
      dividerTheme: DividerThemeData(
        color: palette.hairline,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: palette.inkPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: palette.hairline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: accent,
          side: BorderSide(color: palette.hairline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: TextStyle(color: palette.inkSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: BorderSide(color: palette.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: BorderSide(color: palette.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          borderSide: BorderSide(color: accent, width: 2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: palette.inkSecondary,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodySmall,
      ),
    );
  }

  /// Hero numbers are large and *light* - that weight contrast against the
  /// small semibold labels is what makes the Garmin cards readable at a
  /// glance. Digits use tabular figures wherever they line up in columns.
  static TextTheme _textTheme(AppPalette palette) {
    return TextTheme(
      // Hero metric, e.g. a dive's max depth.
      displayMedium: TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.w300,
        height: 1.05,
        color: palette.inkPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      // Secondary metric inside a stat tile.
      displaySmall: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w300,
        height: 1.1,
        color: palette.inkPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      // Section heading, e.g. "Tauchgänge".
      headlineSmall: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w300,
        color: palette.inkPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: palette.inkPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: palette.inkPrimary,
      ),
      bodyLarge: TextStyle(fontSize: 15, color: palette.inkPrimary),
      bodyMedium: TextStyle(fontSize: 14, color: palette.inkSecondary),
      bodySmall: TextStyle(fontSize: 12.5, color: palette.inkMuted),
      // Small caps-ish label above a metric.
      labelSmall: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: palette.inkMuted,
      ),
    );
  }
}
