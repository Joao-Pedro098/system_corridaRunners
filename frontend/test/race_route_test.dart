import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/src/core/network/api_client.dart';
import 'package:frontend/src/core/theme/rr_theme.dart';
import 'package:frontend/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:frontend/src/features/races/data/race_model.dart';
import 'package:frontend/src/features/races/presentation/race_route_section.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _race = RaceModel.fromJson({
  '_id': 'r1',
  'nome': 'Corrida da Serra',
  'data': '2030-03-10T15:00:00.000Z',
  'distancias': [
    {'distanciaKm': 5},
    {'distanciaKm': 10},
  ],
});

const _route = {
  'pontos': [
    {'lat': -6.07, 'lng': -49.9},
    {'lat': -6.08, 'lng': -49.91},
  ],
  'trechos': [
    {
      'coordenadas': [
        [-49.9, -6.07, 200],
        [-49.91, -6.08, 210],
      ],
      'subidaM': 40,
    },
  ],
};

Map<String, dynamic> _raceJson({Object? on5, Object? on10}) => {
  '_id': 'r1',
  'distancias': [
    {'distanciaKm': 5, 'percurso': ?on5},
    {'distanciaKm': 10, 'percurso': ?on10},
  ],
};

http.Response _reply(int status, Map<String, dynamic> body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});

void main() {
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

  Future<void> open(WidgetTester tester, {bool canManage = false}) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: MaterialApp(
          theme: buildRRTheme(Brightness.light),
          home: Scaffold(
            body: SingleChildScrollView(
              child: RaceRouteSection(race: _race, canManage: canManage, showTiles: false),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  test('lê só as distâncias com percurso', () async {
    handler = (_) async => _reply(200, {'sucesso': true, 'dados': _raceJson(on10: _route)});
    final routes = await RaceService.routes('r1');
    expect(routes.keys, [10]);
    expect(routes[10]!.points.length, 2);
    expect(routes[10]!.ascent, 40);
    expect(requests.single.url.path, endsWith('/races/r1'));
  });

  testWidgets('sem percurso, o atleta não vê a seção', (tester) async {
    handler = (_) async => _reply(200, {'sucesso': true, 'dados': _raceJson()});
    await open(tester);
    expect(find.text('PERCURSO'), findsNothing);
    expect(find.text('Percurso'), findsNothing);
    expect(find.byType(FlutterMap), findsNothing);
    expect(find.text('Desenhar percurso'), findsNothing);
  });

  testWidgets('o atleta vê o mapa e só as distâncias que têm percurso', (tester) async {
    handler = (_) async => _reply(200, {'sucesso': true, 'dados': _raceJson(on10: _route)});
    await open(tester);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.textContaining('40 M DE SUBIDA'), findsOneWidget);
    expect(find.text('Baixar GPX'), findsOneWidget);
    // Uma só distância com mapa: não há o que escolher.
    expect(find.text('5K'), findsNothing);
    expect(find.text('Editar percurso'), findsNothing);
    expect(find.text('Remover'), findsNothing);
  });

  testWidgets('se o carregamento falhar, avisa e permite tentar de novo', (tester) async {
    handler = (_) async => _reply(500, {'sucesso': false, 'mensagem': 'Erro no servidor.'});
    await open(tester, canManage: true);
    expect(find.textContaining('Não carregamos o percurso.'), findsOneWidget);
    // Sem saber o que existe, não oferece desenhar por cima.
    expect(find.text('Desenhar percurso'), findsNothing);

    handler = (_) async => _reply(200, {'sucesso': true, 'dados': _raceJson(on5: _route)});
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();
    expect(find.byType(FlutterMap), findsOneWidget);
  });

  testWidgets('o organizador desenha o percurso sem pedir nome e o mapa aparece', (tester) async {
    handler = (request) async {
      if (request.url.path.endsWith('/routes/segment')) {
        return _reply(200, {
          'sucesso': true,
          'dados': {
            'coordenadas': [
              [-49.9, -6.07, 200],
              [-49.91, -6.08, 210],
            ],
            'subidaM': 15,
          },
        });
      }
      return _reply(200, {'sucesso': true, 'dados': _raceJson()});
    };
    await open(tester, canManage: true);
    expect(find.textContaining('ainda não tem percurso'), findsOneWidget);

    await tester.tap(find.text('Desenhar percurso'));
    await tester.pumpAndSettle();
    expect(find.text('PERCURSO 5K'), findsOneWidget);

    final center = tester.getCenter(find.byType(FlutterMap));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tapAt(center + const Offset(60, 60));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Salvar percurso'));
    await tester.pumpAndSettle();

    final saved = requests.last;
    expect(saved.method, 'PUT');
    expect(saved.url.path, endsWith('/races/r1/distancias/5/percurso'));
    final body = jsonDecode(saved.body) as Map<String, dynamic>;
    expect(body.containsKey('nome'), isFalse);
    expect((body['pontos'] as List).length, 2);
    expect((body['trechos'] as List).length, 1);

    expect(find.text('Editar percurso'), findsOneWidget);
    expect(find.textContaining('15 M DE SUBIDA'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('editar abre o traçado salvo e desistir não altera o que está na tela', (tester) async {
    handler = (_) async => _reply(200, {'sucesso': true, 'dados': _raceJson(on5: _route)});
    await open(tester, canManage: true);

    await tester.tap(find.text('Editar percurso'));
    await tester.pumpAndSettle();
    expect(find.text('40 m'), findsOneWidget);

    await tester.tap(find.byTooltip('Desfazer último ponto'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();

    expect(requests.where((r) => r.method == 'PUT'), isEmpty);
    expect(find.textContaining('40 M DE SUBIDA'), findsOneWidget);
  });

  testWidgets('remove depois de confirmar e troca de distância', (tester) async {
    handler = (request) async => _reply(200, {'sucesso': true, 'dados': _raceJson(on5: _route)});
    await open(tester, canManage: true);

    await tester.tap(find.text('10K'));
    await tester.pumpAndSettle();
    expect(find.textContaining('10K ainda não tem percurso'), findsOneWidget);
    expect(find.text('Desenhar percurso'), findsOneWidget);

    await tester.tap(find.text('5K'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remover').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remover').last);
    await tester.pumpAndSettle();

    expect(requests.last.method, 'DELETE');
    expect(requests.last.url.path, endsWith('/races/r1/distancias/5/percurso'));
    expect(find.byType(FlutterMap), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });
}
