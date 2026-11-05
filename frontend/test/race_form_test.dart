import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/src/core/network/api_client.dart';
import 'package:frontend/src/core/theme/rr_theme.dart';
import 'package:frontend/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:frontend/src/features/races/data/race_model.dart';
import 'package:frontend/src/features/races/presentation/race_form_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

RaceModel _race() => RaceModel.fromJson({
  '_id': 'r1',
  'nome': 'Corrida da Serra',
  'status': 'inscricoes_abertas',
  'data': '2030-03-10T15:00:00.000Z',
  'horarioLargada': '06:00',
  'criadoPor': 'u1',
  'local': {'cidade': 'Marabá', 'estado': 'PA'},
  'distancias': [
    {'distanciaKm': 5, 'altimetria': 40},
    {'distanciaKm': 10},
  ],
  'participantesConfirmados': ['a', 'b'],
});

void main() {
  final requests = <http.Request>[];
  RaceModel? popped;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    requests.clear();
    popped = null;
    ApiClient.client = MockClient((request) async {
      requests.add(request);
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'sucesso': true,
            'dados': {'_id': 'r1', 'nome': 'Novo nome', 'data': '2030-03-10T15:00:00.000Z'},
          }),
        ),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
  });

  Future<void> open(WidgetTester tester, {RaceModel? race}) async {
    tester.view.physicalSize = const Size(1200, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => RacesBus()),
        ],
        child: MaterialApp(
          theme: buildRRTheme(Brightness.light),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                popped = await Navigator.of(context)
                    .push<RaceModel>(MaterialPageRoute(builder: (_) => RaceFormScreen(race: race)));
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('sem dados, destaca os erros e não chama o servidor', (tester) async {
    await open(tester);
    await tester.tap(find.text('Publicar no calendário'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Informe o nome, com pelo menos 3 letras'), findsOneWidget);
    expect(find.text('Escolha a data da prova'), findsOneWidget);
    expect(find.text('Escolha ao menos uma distância'), findsOneWidget);
    expect(requests, isEmpty);
  });

  testWidgets('a prévia acompanha o que é digitado', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextFormField).first, 'Night Run');
    await tester.pump();
    expect(find.text('NIGHT RUN'), findsOneWidget);
  });

  testWidgets('ao editar, carrega os dados e envia PUT com distâncias e elevação', (tester) async {
    await open(tester, race: _race());
    expect(find.text('Corrida da Serra'), findsOneWidget);
    expect(find.text('Salvar alterações'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Novo nome');
    await tester.pump();
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();

    expect(requests.single.method, 'PUT');
    expect(requests.single.url.path, endsWith('/races/r1'));
    final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
    expect(body['nome'], 'Novo nome');
    expect(body['horarioLargada'], '06:00');
    expect(body['local']['estado'], 'PA');
    expect(body['distancias'], [
      {'distanciaKm': 5, 'categoria': '5K', 'altimetria': 40},
      {'distanciaKm': 10, 'categoria': '10K', 'altimetria': 0},
    ]);
    expect(popped?.nome, 'Novo nome');
  });

  testWidgets('link que não é http não é aceito', (tester) async {
    await open(tester, race: _race());
    final link = find.ancestor(of: find.text('LINK DE INSCRIÇÃO — OPCIONAL'), matching: find.byType(Column)).first;
    await tester.enterText(find.descendant(of: link, matching: find.byType(TextFormField)), 'javascript:alert(1)');
    await tester.tap(find.text('Salvar alterações'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Use um link completo, com https://'), findsOneWidget);
    expect(requests, isEmpty);
  });

  testWidgets('sair com alterações pede confirmação; sem alterações, sai direto', (tester) async {
    await open(tester, race: _race());
    await tester.enterText(find.byType(TextFormField).first, 'Mudei');
    await tester.pump();
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('DESCARTAR ALTERAÇÕES?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Mudei'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Corrida da Serra');
    await tester.pump();
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('abrir'), findsOneWidget);
  });

  testWidgets('prova sem horário salvo permite escolher a largada', (tester) async {
    final race = RaceModel.fromJson({
      '_id': 'r2',
      'nome': 'Sem horário',
      'horarioLargada': '',
      'data': '2030-03-10T15:00:00.000Z',
      'local': {'cidade': 'Marabá', 'estado': 'PA'},
      'distancias': [
        {'distanciaKm': 5},
      ],
    });
    await open(tester, race: race);
    expect(find.text('Escolher'), findsOneWidget);
    await tester.tap(find.text('Escolher'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(TimePickerDialog), findsOneWidget);
  });

  test('modelo da prova lê dono e monta o link da capa', () {
    final race = RaceModel.fromJson({'_id': 'r', 'nome': 'X', 'criadoPor': 'u9', 'bannerUrl': '/uploads/races/a.jpg'});
    expect(race.criadoPor, 'u9');
    expect(race.bannerPath, '/uploads/races/a.jpg');
    expect(race.coverUrl, endsWith('/uploads/races/a.jpg'));
    expect(RaceModel.fromJson({'_id': 'r', 'nome': 'X', 'bannerUrl': ''}).coverUrl, isNull);
  });
}
