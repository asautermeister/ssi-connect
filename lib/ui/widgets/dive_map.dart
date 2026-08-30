import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../l10n/app_strings.dart';
import '../../ssi/dive_site.dart';
import '../theme/app_theme.dart';

/// Where the dive was, on a map, with the assigned site alongside it.
///
/// The question this answers is the one the site matching leaves open: *is
/// that the right place?* A distance in metres is hard to judge; the two
/// points next to a coastline are not.
///
/// **This is the only part of the app that talks to anyone but Garmin and
/// SSI.** Asking for a map tile tells the tile server roughly where this
/// dive was - the same objection that ruled out SSI's own web search as a
/// site lookup. It is a deliberate exception, kept as small as it can be:
/// tiles are fetched only for a dive whose detail view is actually open,
/// never in a list, never in the background, and never with anything
/// attached that would say whose dive it is.
///
/// Offline it degrades to an empty grid rather than an error - the map is
/// an extra, and the coordinates are written out underneath it either way,
/// so nothing is missing without a network.
class DiveMap extends StatelessWidget {
  const DiveMap({
    super.key,
    required this.latitude,
    required this.longitude,
    this.site,
  });

  final double latitude;
  final double longitude;

  /// The site this dive is filed at, drawn as a second marker when it is
  /// somewhere else. Null while none is assigned.
  final DiveSite? site;

  /// Close enough that two markers would sit on top of each other. Below
  /// this the site marker is left out: two pins in the same spot say less
  /// than one.
  static const _sameSpotMetres = 15.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final dive = LatLng(latitude, longitude);
    final site = this.site;
    final sitePoint = site == null
        ? null
        : site.distanceMetresTo(latitude, longitude) < _sameSpotMetres
        ? null
        : LatLng(site.latitude, site.longitude);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: SizedBox(
        height: 180,
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: dive,
                // Close enough to see the coastline the dive was on,
                // wide enough that a site a few hundred metres away is
                // still on screen.
                initialZoom: 14,
                interactionOptions: const InteractionOptions(
                  // Pinch and drag only. A map inside a scrolling list that
                  // also handles single-finger drags would eat the scroll.
                  flags:
                      InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  // OpenStreetMap's tile policy asks for an identifying
                  // agent rather than an anonymous client.
                  userAgentPackageName: 'de.sautermeister.ssiconnect',
                  // No error tile and no retry storm: offline, the grid
                  // simply stays empty.
                  errorTileCallback: (_, _, _) {},
                ),
                if (sitePoint != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [dive, sitePoint],
                        strokeWidth: 2,
                        color: palette.inkMuted.withValues(alpha: 0.8),
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    if (sitePoint != null)
                      Marker(
                        point: sitePoint,
                        width: 32,
                        height: 32,
                        child: Icon(
                          Icons.place,
                          color: palette.inkMuted,
                          size: 28,
                        ),
                      ),
                    Marker(
                      point: dive,
                      width: 32,
                      height: 32,
                      child: Icon(
                        Icons.scuba_diving,
                        color: theme.colorScheme.primary,
                        size: 26,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Required by OpenStreetMap, and the honest place to say who
            // drew this.
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                color: theme.colorScheme.surface.withValues(alpha: 0.75),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                child: Text(
                  AppStrings.of(context).osmAttribution,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
