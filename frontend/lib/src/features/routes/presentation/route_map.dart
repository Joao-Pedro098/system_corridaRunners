import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/brand/rr_brand.dart';
import '../../../core/theme/rr_theme.dart';
import '../../../core/widgets/rr_button.dart';
import '../data/route_model.dart';

Widget routeTileLayer() => TileLayer(
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  userAgentPackageName: 'br.com.runnersrun.app',
  maxZoom: 19,
);

Widget routeLines(List<RouteSegment> segments) => PolylineLayer(
  polylines: [
    for (final segment in segments)
      Polyline(
        points: segment.latLngs,
        strokeWidth: segment.straight ? 3 : 5,
        color: segment.straight ? RRPalette.cal950 : RRPalette.tartan500,
        borderStrokeWidth: segment.straight ? 0 : 1.5,
        borderColor: RRPalette.cal50,
        pattern: segment.straight ? StrokePattern.dashed(segments: const [8, 6]) : const StrokePattern.solid(),
      ),
  ],
);

/// Da chegada para a largada: num circuito fechado, a bandeira fica por cima.
List<Marker> routeMarkers(List<LatLng> points) => [
  for (final (i, point) in points.indexed.toList().reversed)
    if (i == 0)
      Marker(point: point, width: 26, height: 26, child: const RouteStartMarker())
    else if (i == points.length - 1)
      Marker(
        point: point,
        width: 18,
        height: 18,
        child: const RouteDot(color: RRPalette.cal950, size: 18),
      )
    else
      Marker(
        point: point,
        width: 14,
        height: 14,
        child: const RouteDot(color: RRPalette.tartan500, size: 14),
      ),
];

Widget routeAttribution() => SimpleAttributionWidget(
  source: const Text('OpenStreetMap'),
  onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright'), mode: LaunchMode.externalApplication),
);

/// Compartilha o traçado em GPX; na web, baixa o arquivo.
Future<void> shareRouteGpx(String name, List<RouteSegment> segments) => SharePlus.instance.share(
  ShareParams(
    files: [
      XFile.fromData(utf8.encode(buildGpx(name, segments)), mimeType: 'application/gpx+xml', name: gpxFileName(name)),
    ],
    fileNameOverrides: [gpxFileName(name)],
  ),
);

class RouteDot extends StatelessWidget {
  final Color color;
  final double size;
  const RouteDot({super.key, required this.color, required this.size});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: RRPalette.cal50, width: 2),
    ),
  );
}

class RouteStartMarker extends StatelessWidget {
  const RouteStartMarker({super.key});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: RRPalette.tartan500,
      shape: BoxShape.circle,
      border: Border.all(color: RRPalette.cal50, width: 2),
    ),
    alignment: Alignment.center,
    child: const RRIcon('largada', size: 14, color: RRPalette.cal950),
  );
}

/// Mapa só para ver um traçado pronto, enquadrado na tela.
class RouteMap extends StatelessWidget {
  final RouteDraft draft;
  final bool interactive;

  /// Os testes não baixam mapas da internet.
  final bool showTiles;

  const RouteMap({super.key, required this.draft, this.interactive = true, this.showTiles = true});

  @override
  Widget build(BuildContext context) {
    final map = FlutterMap(
      options: MapOptions(
        initialCameraFit: CameraFit.coordinates(
          coordinates: [for (final s in draft.segments) ...s.latLngs],
          padding: const EdgeInsets.all(32),
        ),
        minZoom: 3,
        maxZoom: 19,
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all & ~InteractiveFlag.rotate : InteractiveFlag.none,
        ),
      ),
      children: [
        if (showTiles) routeTileLayer(),
        routeLines(draft.segments),
        MarkerLayer(markers: routeMarkers(draft.points)),
        routeAttribution(),
      ],
    );
    // Parado, o mapa deixa o gesto passar para a rolagem da tela.
    return interactive ? map : IgnorePointer(child: map);
  }
}

/// Traçado em tela cheia, com zoom e arraste.
class RouteMapScreen extends StatelessWidget {
  final String title;
  final RouteDraft draft;
  final bool showTiles;
  const RouteMapScreen({super.key, required this.title, required this.draft, this.showTiles = true});

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              color: c.surface,
              child: Row(
                children: [
                  RRIconButton('voltar', tooltip: 'Voltar', onPressed: () => Navigator.maybePop(context)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      title.toUpperCase(),
                      style: RRType.titleM.copyWith(color: c.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RouteMap(draft: draft, showTiles: showTiles),
            ),
          ],
        ),
      ),
    );
  }
}
