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
class DiveMap extends StatefulWidget {
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

  /// How close the map opens when there is nothing to frame. Street level:
  /// the entry point and the coastline it sits on, which is what the
  /// question "is that the right place?" is answered with.
  static const _soloZoom = 16.0;

  /// The tightest the automatic framing goes. Without it, a site matched
  /// twenty metres away would open zoomed so far in that the coast is off
  /// screen - technically the best fit, and useless.
  static const _fitMaxZoom = 16.0;

  @override
  State<DiveMap> createState() => _DiveMapState();
}

class _DiveMapState extends State<DiveMap> {
  final _controller = MapController();

  /// Where the map opens, and where the recentre button puts it back.
  CameraFit? _fitFor(LatLng dive, LatLng? sitePoint) => sitePoint == null
      ? null
      : CameraFit.bounds(
          bounds: LatLngBounds(dive, sitePoint),
          // Room for the markers themselves, which are drawn above their
          // point and would otherwise touch the edge.
          padding: const EdgeInsets.all(32),
          maxZoom: DiveMap._fitMaxZoom,
        );

  void _recentre(LatLng dive, LatLng? sitePoint) {
    final fit = _fitFor(dive, sitePoint);
    if (fit == null) {
      _controller.move(dive, DiveMap._soloZoom);
    } else {
      _controller.fitCamera(fit);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final palette = theme.extension<AppPalette>()!;
    final latitude = widget.latitude;
    final longitude = widget.longitude;
    final dive = LatLng(latitude, longitude);
    final site = widget.site;
    final sitePoint = site == null
        ? null
        : site.distanceMetresTo(latitude, longitude) < DiveMap._sameSpotMetres
        ? null
        : LatLng(site.latitude, site.longitude);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: SizedBox(
        height: 180,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: dive,
                initialZoom: DiveMap._soloZoom,
                // With a site assigned, the useful view is the one holding
                // both points - a fixed zoom either cuts off the site or
                // wastes the frame on open water.
                initialCameraFit: _fitFor(dive, sitePoint),
                interactionOptions: const InteractionOptions(
                  // Everything except rotation, which is disorienting on a
                  // map this small and easy to trigger by accident. Dragging
                  // the map therefore does not scroll the page - the cost of
                  // a map that can be moved at all, and the reason the
                  // recentre button exists.
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
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
            // Panning has no edges, so there has to be a way back. Always
            // there rather than appearing once the map has moved: a control
            // that shows up only when needed is one nobody knows about.
            Positioned(
              right: 4,
              top: 4,
              child: Material(
                color: theme.colorScheme.surface.withValues(alpha: 0.85),
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.my_location, size: 18),
                  tooltip: s.centreOnDive,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _recentre(dive, sitePoint),
                ),
              ),
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
                  s.osmAttribution,
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
