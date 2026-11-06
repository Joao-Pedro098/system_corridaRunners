import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

const _earthRadiusM = 6371000.0;

double _radians(double degrees) => degrees * math.pi / 180;

/// Distância em metros entre dois pontos [longitude, latitude].
double haversineMeters(List<double> a, List<double> b) {
  final dLat = _radians(b[1] - a[1]);
  final dLng = _radians(b[0] - a[0]);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(_radians(a[1])) * math.cos(_radians(b[1])) * math.pow(math.sin(dLng / 2), 2);
  return 2 * _earthRadiusM * math.asin(math.min(1, math.sqrt(h)));
}

/// Pedaço da rota entre dois pontos marcados.
class RouteSegment {
  /// [longitude, latitude] ou [longitude, latitude, altitude], como no GeoJSON.
  final List<List<double>> coords;
  final double ascent;

  /// O serviço de ruas não respondeu: o trecho liga os pontos diretamente.
  final bool straight;

  const RouteSegment({required this.coords, this.ascent = 0, this.straight = false});

  factory RouteSegment.straightLine(LatLng from, LatLng to) => RouteSegment(
    coords: [
      [from.longitude, from.latitude],
      [to.longitude, to.latitude],
    ],
    straight: true,
  );

  factory RouteSegment.fromJson(Map<String, dynamic> json) => RouteSegment(
    coords: (json['coordenadas'] as List? ?? const [])
        .map((c) => (c as List).map((v) => (v as num).toDouble()).toList())
        .toList(),
    ascent: (json['subidaM'] as num? ?? 0).toDouble(),
    straight: json['emLinhaReta'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {'coordenadas': coords, 'subidaM': ascent, 'emLinhaReta': straight};

  double get meters {
    var total = 0.0;
    for (var i = 1; i < coords.length; i++) {
      total += haversineMeters(coords[i - 1], coords[i]);
    }
    return total;
  }

  List<LatLng> get latLngs => [for (final c in coords) LatLng(c[1], c[0])];
}

/// Rota em construção no mapa: N pontos ligados por N-1 trechos.
class RouteDraft {
  static const maxPoints = 100;

  final List<LatLng> points;
  final List<RouteSegment> segments;

  RouteDraft({List<LatLng>? points, List<RouteSegment>? segments}) : points = points ?? [], segments = segments ?? [];

  factory RouteDraft.fromJson(Map<String, dynamic> json) => RouteDraft(
    points: [
      for (final p in json['pontos'] as List? ?? const [])
        LatLng(((p as Map)['lat'] as num).toDouble(), (p['lng'] as num).toDouble()),
    ],
    segments: [for (final s in json['trechos'] as List? ?? const []) RouteSegment.fromJson(s as Map<String, dynamic>)],
  );

  /// Cópia para editar sem mexer no original.
  RouteDraft copy() => RouteDraft(points: [...points], segments: [...segments]);

  bool get isEmpty => points.isEmpty;
  bool get canSave => segments.isNotEmpty;
  bool get isFull => points.length >= maxPoints;
  bool get hasStraightSegment => segments.any((s) => s.straight);

  /// Fechar o circuito só faz sentido com a rota já saindo da largada.
  bool get canClose => segments.isNotEmpty && !_endsAtStart;
  bool get _endsAtStart => points.length > 1 && points.first == points.last;

  double get meters => segments.fold(0, (sum, s) => sum + s.meters);
  double get ascent => segments.fold(0, (sum, s) => sum + s.ascent);

  void start(LatLng point) => points.add(point);

  void addSegment(LatLng to, RouteSegment segment) {
    points.add(to);
    segments.add(segment);
  }

  void undo() {
    if (points.isEmpty) return;
    points.removeLast();
    if (segments.isNotEmpty) segments.removeLast();
  }

  void clear() {
    points.clear();
    segments.clear();
  }

  /// O nome só existe nas rotas salvas; o percurso de uma prova não tem.
  Map<String, dynamic> toJson([String? name]) => {
    'nome': ?name,
    'pontos': [
      for (final p in points) {'lat': p.latitude, 'lng': p.longitude},
    ],
    'trechos': [for (final s in segments) s.toJson()],
  };
}

String _escapeXml(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

/// Arquivo GPX 1.1 com o traçado, para usar em relógios e outros apps.
String buildGpx(String name, List<RouteSegment> segments) {
  final points = StringBuffer();
  for (final segment in segments) {
    for (final (i, c) in segment.coords.indexed) {
      // O primeiro ponto de um trecho repete o último do anterior.
      if (i == 0 && !identical(segment, segments.first)) continue;
      final elevation = c.length > 2 ? '<ele>${c[2]}</ele>' : '';
      points.writeln('      <trkpt lat="${c[1]}" lon="${c[0]}">$elevation</trkpt>');
    }
  }
  final title = _escapeXml(name);
  return '<?xml version="1.0" encoding="UTF-8"?>\n'
      '<gpx version="1.1" creator="RunnersRun" xmlns="http://www.topografix.com/GPX/1/1">\n'
      '  <metadata><name>$title</name></metadata>\n'
      '  <trk>\n'
      '    <name>$title</name>\n'
      '    <trkseg>\n'
      '$points'
      '    </trkseg>\n'
      '  </trk>\n'
      '</gpx>\n';
}

/// Nome de arquivo seguro a partir do nome da rota.
String gpxFileName(String name) {
  final slug = name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  return '${slug.isEmpty ? 'rota' : slug}.gpx';
}

class RouteSummary {
  final String id, nome;
  final int distanciaM, subidaM;
  final bool temLinhaReta;

  const RouteSummary({
    required this.id,
    required this.nome,
    required this.distanciaM,
    required this.subidaM,
    required this.temLinhaReta,
  });

  factory RouteSummary.fromJson(Map<String, dynamic> json) => RouteSummary(
    id: json['_id'] as String? ?? '',
    nome: json['nome'] as String? ?? '',
    distanciaM: (json['distanciaM'] as num? ?? 0).toInt(),
    subidaM: (json['subidaM'] as num? ?? 0).toInt(),
    temLinhaReta: json['temLinhaReta'] as bool? ?? false,
  );
}

class RouteDetail {
  final String id, nome;
  final RouteDraft draft;
  const RouteDetail({required this.id, required this.nome, required this.draft});

  factory RouteDetail.fromJson(Map<String, dynamic> json) => RouteDetail(
    id: json['_id'] as String? ?? '',
    nome: json['nome'] as String? ?? '',
    draft: RouteDraft.fromJson(json),
  );
}

class RouteService {
  RouteService._();

  static String get _base => '${ApiConstants.baseUrl}/routes';

  static Future<RouteSegment> segment(LatLng from, LatLng to) async {
    final data = await ApiClient.post('$_base/segment', {
      'de': {'lat': from.latitude, 'lng': from.longitude},
      'para': {'lat': to.latitude, 'lng': to.longitude},
    });
    return RouteSegment.fromJson(data['dados'] as Map<String, dynamic>);
  }

  static Future<List<RouteSummary>> mine() async {
    final data = await ApiClient.get(_base);
    return (data['dados'] as List).map((e) => RouteSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<RouteDetail> get(String id) async =>
      RouteDetail.fromJson((await ApiClient.get('$_base/$id'))['dados'] as Map<String, dynamic>);

  static Future<void> create(String name, RouteDraft draft) => ApiClient.post(_base, draft.toJson(name));

  static Future<void> update(String id, String name, RouteDraft draft) =>
      ApiClient.put('$_base/$id', draft.toJson(name));

  static Future<void> delete(String id) => ApiClient.delete('$_base/$id');
}
