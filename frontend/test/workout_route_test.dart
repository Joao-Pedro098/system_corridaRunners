import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/src/core/brand/rr_brand.dart';
import 'package:frontend/src/core/network/api_client.dart';
import 'package:frontend/src/core/theme/rr_theme.dart';
import 'package:frontend/src/features/auth/data/models/user_model.dart';
import 'package:frontend/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:frontend/src/features/auth/presentation/screens/login_screen.dart';
import 'package:frontend/src/features/workouts/data/workout_model.dart';
import 'package:frontend/src/features/workouts/presentation/new_workout_screen.dart';
import 'package:frontend/src/features/workouts/presentation/workout_detail_screen.dart';
import 'package:frontend/src/features/workouts/presentation/workout_widgets.dart';
import 'package:frontend/src/features/workouts/presentation/workouts_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuth extends AuthProvider {
  @override
  UserModel? get user => UserModel.fromJson({'_id': 'dono', 'nome': 'Pessoa', 'email': 'p@teste.com', 'tipo': 'atleta'});

  @override
  Future<void> refreshUser() async {}
}

const _resumo = [
  [-49.9, -6.07],
  [-49.91, -6.08],
];

Map<String, dynamic> _route({bool full = false}) => {
  'nome': 'Volta do parque',
  'distanciaM': 5230,
  'subidaM': 40,
  'temLinhaReta': false,
  'resumo': _resumo,
  if (full) ...{
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
  },
};

Map<String, dynamic> _workout({Object? rota}) => {
  '_id': 'w1',
  'titulo': 'Longão',
  'tipoTreino': 'longao',
  'distanciaKm': 10,
  'duracaoSegundos': 3000,
  'tempoFormatado': '00:50:00',
  'paceMedio': '05:00 min/km',
  'dataTreino': '2026-10-20T12:00:00.000Z',
  'atleta': {'_id': 'dono', 'nome': 'Dona'},
  'rota': ?rota,
};

http.Response _ok(Object data) => http.Response.bytes(
  utf8.encode(jsonEncode({'sucesso': true, 'dados': data})),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  final requests = <http.Request>[];
  late Future<http.Response> Function(http.Request) handler;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    requests.clear();
    handler = (_) async => _ok(_workout());
    ApiClient.client = MockClient((request) async {
      requests.add(request);
      return handler(request);
    });
  });

  Future<void> open(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(create: (_) => _FakeAuth()),
          ChangeNotifierProvider<WorkoutsProvider>(create: (_) => WorkoutsProvider()),
        ],
        child: MaterialApp(
          theme: buildRRTheme(Brightness.light),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  Future<void> tapRouteLine(WidgetTester tester) async {
    final line = find.textContaining(RegExp('rota', caseSensitive: false)).first;
    await tester.ensureVisible(line);
    await tester.pumpAndSettle();
    await tester.tap(line);
    await tester.pumpAndSettle();
  }

  Future<void> fillRequired(WidgetTester tester) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Treino com rota');
    await tester.enterText(fields.at(2), '30');
    await tester.pump();
  }

  group('cartão', () {
    Future<List<List<double>>?> pointsOf(WidgetTester tester, Map<String, dynamic> json) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildRRTheme(Brightness.light),
          home: Scaffold(body: WorkoutCover(WorkoutModel.fromJson(json))),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      return tester.widget<RouteArt>(find.byType(RouteArt)).points;
    }

    testWidgets('com rota, desenha o traçado real', (tester) async {
      expect(await pointsOf(tester, _workout(rota: _route())), _resumo);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sem rota, não inventa trajeto', (tester) async {
      expect(await pointsOf(tester, _workout()), isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('pontos todos no mesmo lugar não quebram o desenho', (tester) async {
      final same = {
        ..._route(),
        'resumo': [
          [-49.9, -6.07],
          [-49.9, -6.07],
        ],
      };
      await pointsOf(tester, _workout(rota: same));
      expect(tester.takeException(), isNull);
    });
  });

  group('detalhe', () {
    testWidgets('com rota, busca o traçado completo e mostra o mapa', (tester) async {
      handler = (_) async => _ok(_workout(rota: _route(full: true)));
      await open(tester, WorkoutDetailScreen(workout: WorkoutModel.fromJson(_workout(rota: _route())), showTiles: false));
      expect(requests.single.url.path, endsWith('/workouts/w1'));
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.textContaining('40 M DE SUBIDA'), findsOneWidget);
      expect(find.text('Baixar GPX'), findsOneWidget);
    });

    testWidgets('sem rota, não busca nada nem mostra mapa ou arte', (tester) async {
      await open(tester, WorkoutDetailScreen(workout: WorkoutModel.fromJson(_workout()), showTiles: false));
      expect(requests, isEmpty);
      expect(find.byType(FlutterMap), findsNothing);
      expect(find.byType(RouteArt), findsNothing);
    });
  });

  group('formulário', () {
    final saved = [
      {'_id': 'r1', 'nome': 'Volta do parque', 'distanciaM': 5230, 'subidaM': 40, 'temLinhaReta': false},
    ];

    testWidgets('escolher a rota avisa da publicação, sugere a distância e envia só o id', (tester) async {
      handler = (request) async => request.method == 'GET' ? _ok(saved) : _ok(_workout(rota: _route()));
      await open(tester, const NewWorkoutScreen());
      expect(find.textContaining('ficam visíveis para todos'), findsNothing);

      await tapRouteLine(tester);
      await tester.tap(find.text('Volta do parque'));
      await tester.pumpAndSettle();

      expect(find.textContaining('ficam visíveis para todos'), findsOneWidget);
      final fields = tester.widgetList<TextFormField>(find.byType(TextFormField)).map((f) => f.controller!.text);
      expect(fields, contains('5,23'));

      await fillRequired(tester);
      await tester.tap(find.text('Publicar treino').last);
      await tester.pumpAndSettle();

      final body = jsonDecode(requests.last.body) as Map<String, dynamic>;
      expect(requests.last.method, 'POST');
      expect(body['rotaId'], 'r1');
      expect(body.containsKey('rota'), isFalse);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('não troca a distância que a pessoa já digitou', (tester) async {
      handler = (_) async => _ok(saved);
      await open(tester, const NewWorkoutScreen());
      await tester.enterText(find.byType(TextFormField).at(1), '12');
      await tapRouteLine(tester);
      await tester.tap(find.text('Volta do parque'));
      await tester.pumpAndSettle();
      final fields = tester.widgetList<TextFormField>(find.byType(TextFormField)).map((f) => f.controller!.text);
      expect(fields, contains('12'));
      expect(fields, isNot(contains('5,23')));
    });

    testWidgets('sem rotas salvas, orienta a criar uma', (tester) async {
      handler = (_) async => _ok(const []);
      await open(tester, const NewWorkoutScreen());
      await tapRouteLine(tester);
      expect(find.text('Você ainda não tem rotas. Planeje uma na aba Rotas.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('editar sem mexer na rota não a envia; fechar a lista não a retira', (tester) async {
      handler = (request) async => request.method == 'GET' ? _ok(saved) : _ok(_workout(rota: _route()));
      await open(tester, NewWorkoutScreen(workout: WorkoutModel.fromJson(_workout(rota: _route()))));
      expect(find.textContaining('ficam visíveis para todos'), findsOneWidget);

      await tapRouteLine(tester);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.textContaining('ficam visíveis para todos'), findsOneWidget);

      await tester.tap(find.text('Salvar alterações'));
      await tester.pumpAndSettle();
      expect((jsonDecode(requests.last.body) as Map).containsKey('rotaId'), isFalse);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('escolher "Sem rota" retira a rota do treino', (tester) async {
      final workout = WorkoutModel.fromJson(_workout(rota: _route()));
      handler = (request) async => request.method == 'GET' ? _ok(saved) : _ok(_workout());
      await open(tester, NewWorkoutScreen(workout: workout));

      await tapRouteLine(tester);
      await tester.tap(find.text('Sem rota'));
      await tester.pumpAndSettle();
      expect(find.textContaining('ficam visíveis para todos'), findsNothing);

      await tester.tap(find.text('Salvar alterações'));
      await tester.pumpAndSettle();
      final body = jsonDecode(requests.last.body) as Map<String, dynamic>;
      expect(body.containsKey('rotaId'), isTrue);
      expect(body['rotaId'], isNull);
      expect(workout.rota, isNull);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  testWidgets('a tela de login não promete recuperar a senha', (tester) async {
    await open(tester, const LoginScreen());
    expect(find.text('Esqueceu a senha?'), findsNothing);
    expect(find.text('Lembrar de mim'), findsOneWidget);
  });
}
