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
/// tiles are fetched only for a dive whose detail view is actually open -
/// which since the detail view became swipeable includes the one being
/// swiped to, because the page builds as it comes in. Still only dives
/// somebody is actually looking at: never a list, never the background,
/// and never with anything attached that would say whose dive it is.
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
    this.otherSites = const [],
    this.onSiteTap,
  });

  final double latitude;
  final double longitude;

  /// The site this dive is filed at, drawn as a second marker when it is
  /// somewhere else. Null while none is assigned.
  final DiveSite? site;

  /// Other known sites worth showing for orientation, nearest first. Drawn
  /// in a lighter red, under the two markers that matter, and never framed
  /// by the opening view - they are context, not the subject. Which ones,
  /// and how many, is the caller's decision; see [otherSitesRadiusMetres]
  /// and [otherSitesShown].
  final List<DiveSite> otherSites;

  /// Called when one of [otherSites] is tapped, with that site.
  ///
  /// The pin already names the place; tapping it is the shortest way there
  /// is to say "that one" - shorter than the picker, and from the one view
  /// that shows why it is the right answer. Only the neighbours respond:
  /// the dive's own pin is where you already are.
  final ValueChanged<DiveSite>? onSiteTap;

  /// Close enough that two markers would sit on top of each other. Below
  /// this the site marker is left out: two pins in the same spot say less
  /// than one.
  static const _sameSpotMetres = 15.0;

  /// How close the map opens when there is nothing to frame. Street level:
  /// the entry point and the coastline it sits on, which is what the
  /// question "is that the right place?" is answered with.
  static const _soloZoom = 16.0;

  /// Marker colours do not follow the app theme, and that is deliberate:
  /// OpenStreetMap's standard tiles are light in both themes, so a marker
  /// tinted for a dark interface would be a pale icon on a pale map. These
  /// are chosen against the tiles instead - deep orange, green and dark red
  /// carry on beige land and blue water alike, and each sits on a white
  /// disc so there is contrast even over a dark harbour.
  ///
  /// The diver takes the green once the dive has a site, and that is the
  /// same green the transferred tick uses: on this page green means "this
  /// part is settled". Orange is the open state - a dive without a site
  /// goes to SSI without a `site:`, which is the one thing the map is there
  /// to help decide.
  static const _diverColour = Color(0xFFE65100);
  static const _diverSettledColour = AppColors.settled;
  static const _siteColour = Color(0xFF7F1416);
  static const _otherSiteColour = Color(0xFFE0736C);
  static const _lineColour = Color(0xCC37474F);

  /// How far a site may be and still be worth drawing for orientation.
  ///
  /// Fifteen kilometres is about as far as one goes by boat for a dive, so
  /// a site inside it is plausibly the same trip. Beyond that the pins say
  /// nothing about where this dive was, and at the zoom the map opens on
  /// they would be off screen anyway - drawn only to be found by someone
  /// zooming out far enough to have lost the point.
  static const otherSitesRadiusMetres = 15000.0;

  /// Enough to show the neighbourhood, few enough that the map does not
  /// turn into a field of pins on a coast that has been dived a lot.
  static const otherSitesShown = 3;

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

  /// Wraps a neighbour's marker so tapping it assigns that site. Left
  /// alone when nobody is listening, so the map stays usable as a picture.
  Widget _tappable(DiveSite site, Widget child) {
    final onSiteTap = widget.onSiteTap;
    if (onSiteTap == null) return child;
    return GestureDetector(
      // Opaque, so the whole marker box answers rather than only the
      // pixels the icon happens to paint.
      behavior: HitTestBehavior.opaque,
      onTap: () => onSiteTap(site),
      child: child,
    );
  }

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
                        color: DiveMap._lineColour,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    // First, so they end up under everything that matters.
                    for (final other in widget.otherSites) ...[
                      Marker(
                        point: LatLng(other.latitude, other.longitude),
                        width: 30,
                        height: 30,
                        alignment: Alignment.topCenter,
                        child: _tappable(
                          other,
                          const _MapPin(
                            icon: Icons.place,
                            colour: DiveMap._otherSiteColour,
                            size: 30,
                          ),
                        ),
                      ),
                      Marker(
                        point: LatLng(other.latitude, other.longitude),
                        width: 140,
                        height: 24,
                        alignment: Alignment.bottomCenter,
                        // The name is part of the same target: a 30-pixel
                        // disc is a small thing to hit on a boat.
                        child: _tappable(
                          other,
                          _MapLabel(text: other.name, muted: true),
                        ),
                      ),
                    ],
                    if (sitePoint != null) ...[
                      Marker(
                        point: sitePoint,
                        width: 34,
                        height: 34,
                        // The tip of the teardrop is its bottom edge, so
                        // the marker sits above the point rather than on
                        // it - otherwise the pin points somewhere else.
                        alignment: Alignment.topCenter,
                        child: const IgnorePointer(
                          child: _MapPin(
                            icon: Icons.place,
                            colour: DiveMap._siteColour,
                          ),
                        ),
                      ),
                      Marker(
                        point: sitePoint,
                        width: 160,
                        height: 26,
                        // Below the point, so the label reads as belonging
                        // to the pin above it without covering it.
                        alignment: Alignment.bottomCenter,
                        child: IgnorePointer(
                          child: _MapLabel(text: site!.name),
                        ),
                      ),
                    ],
                    Marker(
                      point: dive,
                      width: 34,
                      height: 34,
                      // Drawn last, so it is on top of everything - which
                      // would also make it swallow taps meant for a
                      // neighbour's label underneath. Nothing here is
                      // interactive, so nothing here takes a pointer.
                      child: IgnorePointer(
                        child: _MapPin(
                          icon: Icons.scuba_diving,
                          colour: site == null
                              ? DiveMap._diverColour
                              : DiveMap._diverSettledColour,
                        ),
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

/// One marker: a coloured icon on a white disc, so it reads over water,
/// land and the dark blur of a harbour alike.
class _MapPin extends StatelessWidget {
  const _MapPin({required this.icon, required this.colour, this.size = 34});

  final IconData icon;
  final Color colour;

  /// The disc's diameter. The neighbours are drawn a little smaller, so
  /// which pin is the point of the map stays readable at a glance.
  final double size;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 3,
          offset: Offset(0, 1),
        ),
      ],
    ),
    child: Center(
      child: Icon(icon, color: colour, size: size * 0.65),
    ),
  );
}

/// The site's name under its pin.
///
/// On its own background rather than straight onto the map: place names are
/// already printed on the tiles, and text over text is unreadable. Clipped
/// to one line - the map says where, the card above says what.
class _MapLabel extends StatelessWidget {
  const _MapLabel({required this.text, this.muted = false});

  final String text;

  /// Quieter, for a site that is only there for orientation - so the name
  /// of the site this dive is actually filed at still reads as the one
  /// that counts.
  final bool muted;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: muted ? 0.75 : 0.9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: muted ? const Color(0xFF5A5F63) : const Color(0xFF1A1C1E),
          fontSize: muted ? 10 : 11,
          fontWeight: muted ? FontWeight.w500 : FontWeight.w600,
        ),
      ),
    ),
  );
}
