import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/src/core/network/api_client.dart';
import 'package:frontend/src/core/theme/rr_theme.dart';
import 'package:frontend/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:frontend/src/features/routes/data/route_model.dart';
import 'package:frontend/src/features/routes/presentation/my_routes_screen.dart';
import 'package:frontend/src/features/routes/presentation/route_planner_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _a = LatLng(-6.07, -49.9);
const _b = LatLng(-6.08, -49.91);
const _c = LatLng(-6.09, -49.92);

RouteSegment _segment(LatLng from, LatLng to, {double ascent = 10, bool straight = false}) => RouteSegment(
  coords: [
    [from.longitude, from.latitude, 200],
    [to.longitude, to.latitude, 210],
  ],
  ascent: ascent,
  straight: straight,
);

http.Response _ok(Object data, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode({'sucesso': true, 'dados': data})),
  status,
  headers: {'content-type': 'application/json'},
);

http.Response _fail(int status, String message) => http.Response.bytes(
  utf8.encode(jsonEncode({'sucesso': false, 'mensagem': message})),
  status,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> _segmentJson() => {
  'coordenadas': [
    [-49.9, -6.07, 200],
    [-49.905, -6.075, 205],
    [-49.91, -6.08, 210],
  ],
  'subidaM': 10,
};

void main() {
  group('distância', () {
    test('calcula metros entre coordenadas conhecidas', () {
      // Um grau de latitude tem cerca de 111,2 km.
      expect(haversineMeters([0, 0], [0, 1]), closeTo(111195, 50));
      expect(haversineMeters([-49.9, -6.07], [-49.9, -6.07]), 0);
    });

    test('segue a soma de todos os trechos', () {
      final draft = RouteDraft()
        ..start(_a)
        ..addSegment(_b, _segment(_a, _b))
        ..addSegment(_c, _segment(_b, _c));
      expect(draft.meters, closeTo(3120, 30));
      expect(draft.ascent, 20);
    });
  });

  group('rascunho da rota', () {
    test('desfazer retira o ponto e o trecho, sem desalinhar', () {
      final draft = RouteDraft()
        ..start(_a)
        ..addSegment(_b, _segment(_a, _b));
      draft.undo();
      expect(draft.points, [_a]);
      expect(draft.segments, isEmpty);
      expect(draft.canSave, isFalse);
      draft.undo();
      expect(draft.isEmpty, isTrue);
      draft.undo();
      expect(draft.isEmpty, isTrue);
    });

    test('só permite fechar o circuito depois de sair da largada e uma vez', () {
      final draft = RouteDraft()..start(_a);
      expect(draft.canClose, isFalse);
      draft.addSegment(_b, _segment(_a, _b));
      expect(draft.canClose, isTrue);
      draft.addSegment(_a, _segment(_b, _a));
      expect(draft.canClose, isFalse);
    });

    test('envia pontos e trechos no formato da API', () {
      final json =
          (RouteDraft()
                ..start(_a)
                ..addSegment(_b, _segment(_a, _b, straight: true)))
              .toJson('Treino');
      expect(json['nome'], 'Treino');
      expect(json['pontos'], [
        {'lat': -6.07, 'lng': -49.9},
        {'lat': -6.08, 'lng': -49.91},
      ]);
      expect((json['trechos'] as List).single['emLinhaReta'], isTrue);
    });

    test('abre uma rota salva', () {
      final route = RouteDetail.fromJson({
        '_id': 'r1',
        'nome': 'Parque',
        'pontos': [
          {'lat': -6.07, 'lng': -49.9},
          {'lat': -6.08, 'lng': -49.91},
        ],
        'trechos': [_segmentJson()],
      });
      expect(route.draft.points.length, 2);
      expect(route.draft.segments.single.coords.length, 3);
      expect(route.draft.ascent, 10);
    });
  });

  group('GPX', () {
    test('tem altitude, não repete a emenda dos trechos e escapa o nome', () {
      final gpx = buildGpx('Rua <A> & "B"', [_segment(_a, _b), _segment(_b, _c)]);
      expect(gpx, contains('<name>Rua &lt;A&gt; &amp; &quot;B&quot;</name>'));
      expect(gpx, contains('<trkpt lat="-6.07" lon="-49.9"><ele>200.0</ele></trkpt>'));
      expect(RegExp('<trkpt').allMatches(gpx).length, 3);
    });

    test('trecho sem altitude não leva o campo', () {
      final gpx = buildGpx('X', [RouteSegment.straightLine(_a, _b)]);
      expect(gpx, isNot(contains('<ele>')));
      expect(RegExp('<trkpt').allMatches(gpx).length, 2);
    });

    test('monta um nome de arquivo seguro', () {
      expect(gpxFileName('Volta do Parque 2'), 'volta-do-parque-2.gpx');
      expect(gpxFileName('../../etc'), 'etc.gpx');
      expect(gpxFileName('***'), 'rota.gpx');
    });
  });

  group('estimativa', () {
    test('usa o ritmo dos treinos, quando plausível', () {
      expect(routePaceSeconds({'totalKm': 100, 'tempoTotalSegundos': 30000}), 300);
      expect(routePaceSeconds(null), 360);
      expect(routePaceSeconds({'totalKm': 0, 'tempoTotalSegundos': 0}), 360);
      expect(routePaceSeconds({'totalKm': 100, 'tempoTotalSegundos': 100}), 360);
    });

    test('formata a duração', () {
      expect(routeDuration(1800), '30 min');
      expect(routeDuration(3900), '1h 05');
    });
  });

  group('telas', () {
    final requests = <http.Request>[];
    late Future<http.Response> Function(http.Request) handler;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      requests.clear();
      ApiClient.client = MockClient((request) async {
        requests.add(request);
        return handler(request);
      });
    });

    Future<void> pump(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AuthProvider(),
          child: MaterialApp(theme: buildRRTheme(Brightness.light), home: child),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// Abre o planejador por cima de uma tela, como no app.
    Future<void> pumpPlanner(WidgetTester tester, {String? id}) async {
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => RoutePlannerScreen(routeId: id, showTiles: false))),
            child: const Text('abrir'),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    Future<void> tapMap(WidgetTester tester, Offset offset) async {
      await tester.tapAt(tester.getCenter(find.byType(FlutterMap)) + offset);
      // O mapa espera para saber se é um toque duplo.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
    }

    testWidgets('o primeiro toque marca a largada sem chamar o serviço; o segundo pede o trecho', (tester) async {
      handler = (_) async => _ok(_segmentJson());
      await pumpPlanner(tester);
      expect(find.text('Toque no mapa para marcar a largada.'), findsOneWidget);

      await tapMap(tester, Offset.zero);
      expect(requests, isEmpty);
      expect(find.text('Agora toque no próximo ponto da rota.'), findsOneWidget);

      await tapMap(tester, const Offset(60, 60));
      expect(requests.single.url.path, endsWith('/routes/segment'));
      expect(find.text('10 m'), findsOneWidget);
      expect(find.textContaining('não avalia segurança'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('toques rápidos no mesmo lugar marcam pontos, sem virar zoom', (tester) async {
      handler = (_) async => _ok(_segmentJson());
      await pumpPlanner(tester);
      final center = tester.getCenter(find.byType(FlutterMap));
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tapAt(center + const Offset(8, 8));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();
      expect(requests.length, 1);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('se o serviço falhar, liga em linha reta e avisa', (tester) async {
      handler = (_) async => _fail(503, 'O traçado pelas ruas ainda não foi configurado no servidor.');
      await pumpPlanner(tester);
      await tapMap(tester, Offset.zero);
      await tapMap(tester, const Offset(60, 60));
      expect(find.textContaining('Trecho em linha reta.'), findsOneWidget);
      expect(find.textContaining('linha reta, então a distância é aproximada'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('salvar pede o nome, valida e envia a rota', (tester) async {
      handler = (request) async => request.url.path.endsWith('/segment') ? _ok(_segmentJson()) : _ok({}, 201);
      await pumpPlanner(tester);
      await tapMap(tester, Offset.zero);
      await tapMap(tester, const Offset(60, 60));

      await tester.tap(find.text('Salvar rota'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(find.text('Use de 3 a 60 letras'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'Volta do parque');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      final body = jsonDecode(requests.last.body) as Map<String, dynamic>;
      expect(requests.last.method, 'POST');
      expect(body['nome'], 'Volta do parque');
      expect((body['pontos'] as List).length, 2);
      expect((body['trechos'] as List).length, 1);
      expect(find.text('abrir'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('sair com pontos marcados pede confirmação', (tester) async {
      handler = (_) async => _ok(_segmentJson());
      await pumpPlanner(tester);
      await tapMap(tester, Offset.zero);
      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();
      expect(find.text('DESCARTAR ALTERAÇÕES?'), findsOneWidget);
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      expect(find.text('abrir'), findsOneWidget);
    });

    testWidgets('abre uma rota salva sem pedir trechos de novo e salva com PUT', (tester) async {
      handler = (request) async => request.method == 'GET'
          ? _ok({
              '_id': 'r1',
              'nome': 'Parque',
              'pontos': [
                {'lat': -6.07, 'lng': -49.9},
                {'lat': -6.08, 'lng': -49.91},
              ],
              'trechos': [_segmentJson()],
            })
          : _ok({});
      await pumpPlanner(tester, id: 'r1');
      expect(find.text('PARQUE'), findsOneWidget);
      expect(find.text('10 m'), findsOneWidget);
      expect(requests.single.method, 'GET');

      await tester.tap(find.text('Salvar rota'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(requests.last.method, 'PUT');
      expect(requests.last.url.path, endsWith('/routes/r1'));
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('lista as rotas e exclui depois de confirmar', (tester) async {
      handler = (request) async => request.method == 'DELETE'
          ? _ok({})
          : _ok([
              {'_id': 'r1', 'nome': 'Parque', 'distanciaM': 5230, 'subidaM': 40, 'temLinhaReta': false},
              {'_id': 'r2', 'nome': 'Orla', 'distanciaM': 3000, 'subidaM': 0, 'temLinhaReta': true},
            ]);
      await pump(tester, const Scaffold(body: MyRoutesScreen()));
      expect(find.text('5,2 KM • 40 M DE SUBIDA'), findsOneWidget);
      expect(find.text('~3,0 KM'), findsOneWidget);

      await tester.tap(find.byTooltip('Excluir Orla'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      expect(requests.last.method, 'DELETE');
      expect(requests.last.url.path, endsWith('/routes/r2'));
      expect(find.text('Orla'), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('sem rotas, convida a planejar a primeira', (tester) async {
      handler = (_) async => _ok([]);
      await pump(tester, const Scaffold(body: MyRoutesScreen()));
      expect(find.text('Planejar rota'), findsOneWidget);
      expect(find.text('Nova rota'), findsNothing);
    });
  });
}
