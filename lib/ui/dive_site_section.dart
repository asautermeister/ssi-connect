import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../models/dive.dart';
import '../ssi/dive_site.dart';
import '../ssi/dive_sites_controller.dart';
import 'theme/app_theme.dart';
import 'widgets/app_card.dart';

/// The dive site of one dive: which one it is, or a way to say so.
///
/// The site is the one field of the SSI payload that cannot be derived -
/// Garmin has coordinates, SSI wants its own site number, and there is no
/// open lookup between the two. The numbers come from the user's own SSI
/// logbook, or are entered by hand; the position is what recognises the
/// place afterwards.
///
/// A suggestion is always shown as a suggestion, and when several sites are
/// in reach they are all offered. Applying the nearest one silently would
/// be the one mistake worth avoiding here: dive sites sit close together on
/// the same stretch of coast, and SSI never says that a dive was filed at
/// the wrong place.
class DiveSiteSection extends StatelessWidget {
  const DiveSiteSection({
    super.key,
    required this.dive,
    required this.selected,
    required this.onChanged,
  });

  final Dive dive;

  /// The site currently chosen for this dive, or null.
  final DiveSite? selected;
  final ValueChanged<DiveSite?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final palette = theme.extension<AppPalette>()!;
    final sites = context.watch<DiveSitesController>();
    final selected = this.selected;
    final suggestions = selected == null
        ? sites.suggestionsFor(dive)
        : const <DiveSiteMatch>[];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.place_outlined, size: 18, color: palette.inkMuted),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  selected?.name ?? s.noDiveSiteYet,
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          if (selected != null) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                'site:${selected.siteId}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],

          // Offered rather than applied - the user confirms which place
          // this was.
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.siteNearby(
                      suggestions.first.site.name,
                      suggestions.first.distanceMetres.round(),
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: () => onChanged(suggestions.first.site),
                  child: Text(s.useSuggestion),
                ),
              ],
            ),
            // The nearest is not automatically the right one. When others
            // are in reach, say so instead of hiding them behind a button
            // labelled as if there were nothing to choose from.
            if (suggestions.length > 1)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => _assign(context, dive, sites, onChanged),
                  child: Text(s.moreSitesNearby(suggestions.length - 1)),
                ),
              ),
          ],

          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              TextButton.icon(
                icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                label: Text(
                  selected == null ? s.assignDiveSite : s.changeDiveSite,
                ),
                onPressed: () => _assign(context, dive, sites, onChanged),
              ),
              if (selected != null)
                TextButton(
                  onPressed: () => onChanged(null),
                  child: Text(s.remove),
                ),
            ],
          ),

          // Said outright, so a missing suggestion doesn't look like a
          // missing site.
          if (!dive.hasPosition) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              s.noPositionNoSite,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.inkMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Picks a known site, or takes down a new one.
Future<void> _assign(
  BuildContext context,
  Dive dive,
  DiveSitesController sites,
  ValueChanged<DiveSite?> onChanged,
) async {
  final chosen = await showDialog<DiveSite>(
    context: context,
    builder: (_) => _SitePickerDialog(dive: dive, sites: sites),
  );
  if (chosen == null) return;
  await sites.save(chosen);
  onChanged(chosen);
}

class _SitePickerDialog extends StatefulWidget {
  const _SitePickerDialog({required this.dive, required this.sites});

  final Dive dive;
  final DiveSitesController sites;

  @override
  State<_SitePickerDialog> createState() => _SitePickerDialogState();
}

class _SitePickerDialogState extends State<_SitePickerDialog> {
  /// Above this many known sites, scrolling stops being a way to find
  /// anything and the search field earns its space. An SSI import pushes
  /// most logbooks past it; a hand-built list of five stays uncluttered.
  static const _searchThreshold = 8;

  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// Ranked by distance from the dive, so the place you were is at the top
  /// and picking it is a confirmation rather than a search.
  List<DiveSiteMatch> get _visible {
    final ranked = widget.sites.rankedByDistanceFrom(widget.dive);
    final query = _query.text.trim().toLowerCase();
    if (query.isEmpty) return ranked;
    return [
      for (final match in ranked)
        if (match.site.name.toLowerCase().contains(query) ||
            match.site.siteId.contains(query))
          match,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final dive = widget.dive;
    final known = widget.sites.sites;
    final visible = _visible;

    return AlertDialog(
      title: Text(s.diveSite),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (known.length > _searchThreshold) ...[
              TextField(
                controller: _query,
                decoration: InputDecoration(
                  labelText: s.searchDiveSite,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            // Known sites first: after a week in one place this is the
            // whole interaction.
            if (visible.isNotEmpty)
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final match in visible)
                      ListTile(
                        dense: true,
                        title: Text(match.site.name),
                        subtitle: Text(
                          dive.hasPosition
                              ? 'site:${match.site.siteId} · '
                                    '${s.distance(match.distanceMetres.round())}'
                              : 'site:${match.site.siteId}',
                        ),
                        onTap: () => Navigator.of(context).pop(match.site),
                      ),
                  ],
                ),
              )
            else if (known.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text(s.noSiteMatches, style: theme.textTheme.bodySmall),
              ),
            const Divider(),
            TextButton.icon(
              icon: const Icon(Icons.add_location_alt_outlined, size: 18),
              label: Text(s.assignDiveSite),
              // A new site is defined by the position of the dive it is
              // matched to, so a dive without one cannot create it. Picking
              // an already-known site still works.
              onPressed: !dive.hasPosition
                  ? null
                  : () async {
                      final created = await showDialog<DiveSite>(
                        context: context,
                        builder: (_) => _NewSiteDialog(dive: dive),
                      );
                      if (created != null && context.mounted) {
                        Navigator.of(context).pop(created);
                      }
                    },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
      ],
    );
  }
}

/// Takes down a site: the number, a name, and the position of the dive it
/// is being matched to.
class _NewSiteDialog extends StatefulWidget {
  const _NewSiteDialog({required this.dive});

  final Dive dive;

  @override
  State<_NewSiteDialog> createState() => _NewSiteDialogState();
}

class _NewSiteDialogState extends State<_NewSiteDialog> {
  final _idOrUrl = TextEditingController();
  final _name = TextEditingController();
  bool _idInvalid = false;

  @override
  void initState() {
    super.initState();
    // A dive that already carries a place name from Garmin starts with it
    // filled in - usually the right answer, always editable.
    _name.text = widget.dive.locationName ?? '';
  }

  @override
  void dispose() {
    _idOrUrl.dispose();
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final siteId = DiveSite.parseSiteId(_idOrUrl.text);
    if (siteId == null) {
      setState(() => _idInvalid = true);
      return;
    }
    final name = _name.text.trim();
    Navigator.of(context).pop(
      DiveSite(
        siteId: siteId,
        // Named by its number when nothing else is known, the same way a
        // buddy without a name is.
        name: name.isEmpty ? 'site:$siteId' : name,
        latitude: widget.dive.latitude!,
        longitude: widget.dive.longitude!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);

    return AlertDialog(
      title: Text(s.assignDiveSite),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _idOrUrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: s.diveSiteNumber,
              helperText: s.diveSiteNumberHint,
              helperMaxLines: 3,
              errorText: _idInvalid ? s.siteIdUnreadable : null,
            ),
            onChanged: (_) {
              if (_idInvalid) setState(() => _idInvalid = false);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: s.diveSiteName),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.md),
          // The position is not editable: it comes from the dive, which is
          // the whole reason this pairing can be recognised again.
          Text(
            '${s.position}: '
            '${widget.dive.latitude!.toStringAsFixed(5)}, '
            '${widget.dive.longitude!.toStringAsFixed(5)}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        TextButton(onPressed: _submit, child: Text(s.save)),
      ],
    );
  }
}
