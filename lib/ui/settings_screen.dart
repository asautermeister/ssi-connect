import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../l10n/app_strings_de.dart';
import '../l10n/app_strings_en.dart';
import '../settings/settings_controller.dart';
import 'theme/app_theme.dart';
import 'widgets/app_card.dart';

/// App-wide preferences: how the app looks and which language it speaks.
///
/// Both choices offer "follow the device" first, then the explicit
/// overrides. That order is deliberate - the default is the answer for
/// most people, and the overrides exist for the cases the device gets
/// wrong.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final s = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          SectionHeader(title: s.appearance),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final option in _ThemeOption.values)
                  _OptionRow(
                    icon: option.icon,
                    label: option.label(s),
                    description: option.description(s),
                    selected: settings.themeMode == option.mode,
                    onTap: () => settings.setThemeMode(option.mode),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text(
              s.qrStaysLightNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          SectionHeader(title: s.language),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _OptionRow(
                  icon: Icons.language,
                  label: s.languageSystem,
                  description: s.languageSystemHint,
                  selected: settings.locale == null,
                  onTap: () => settings.setLocale(null),
                ),
                for (final language in _languages)
                  _OptionRow(
                    icon: Icons.translate,
                    // The language names itself, so it stays readable to
                    // someone who cannot read the language currently set.
                    label: language.strings.languageName,
                    description: null,
                    selected:
                        settings.locale?.languageCode ==
                        language.locale.languageCode,
                    onTap: () => settings.setLocale(language.locale),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The languages on offer, each paired with its own texts so the picker can
/// name it in itself.
final _languages = [
  (locale: const Locale('de'), strings: const AppStringsDe()),
  (locale: const Locale('en'), strings: const AppStringsEn()),
];

/// The three theme choices, in the order they belong: the default first,
/// then the two ways to override it.
enum _ThemeOption {
  system(ThemeMode.system, Icons.brightness_auto_outlined),
  light(ThemeMode.light, Icons.light_mode_outlined),
  dark(ThemeMode.dark, Icons.dark_mode_outlined);

  const _ThemeOption(this.mode, this.icon);

  final ThemeMode mode;
  final IconData icon;

  String label(AppStrings s) => switch (this) {
    _ThemeOption.system => s.themeSystem,
    _ThemeOption.light => s.themeLight,
    _ThemeOption.dark => s.themeDark,
  };

  String description(AppStrings s) => switch (this) {
    _ThemeOption.system => s.themeSystemHint,
    _ThemeOption.light => s.themeLightHint,
    _ThemeOption.dark => s.themeDarkHint,
  };
}

/// One choice. Built by hand rather than from [RadioListTile] so the whole
/// row is the tap target and the styling matches the rest of the app.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.icon,
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final description = this.description;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: selected ? theme.colorScheme.primary : palette.inkMuted,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.titleMedium),
                  if (description != null) ...[
                    const SizedBox(height: 2),
                    Text(description, style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            // The tick alone carries the selection, so it needs to be
            // unmistakable rather than a shade of the same colour.
            if (selected)
              Icon(
                Icons.check_circle,
                size: 22,
                color: theme.colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}
