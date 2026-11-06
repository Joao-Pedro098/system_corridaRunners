import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/src/core/network/api_client.dart';
import 'package:frontend/src/core/theme/rr_theme.dart';
import 'package:frontend/src/core/widgets/rr_layout.dart';
import 'package:frontend/src/features/auth/data/models/user_model.dart';
import 'package:frontend/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:frontend/src/features/news/data/news_model.dart';
import 'package:frontend/src/features/news/presentation/news_detail_screen.dart';
import 'package:frontend/src/features/workouts/data/workout_model.dart';
import 'package:frontend/src/features/workouts/presentation/new_workout_screen.dart';
import 'package:frontend/src/features/workouts/presentation/workout_detail_screen.dart';
import 'package:frontend/src/features/workouts/presentation/workouts_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuth extends AuthProvider {
  final String id, type;
  _FakeAuth(this.id, this.type);

  @override
  UserModel? get user => UserModel.fromJson({'_id': id, 'nome': 'Pessoa', 'email': 'p@teste.com', 'tipo': type});

  @override
  Future<void> refreshUser() async {}
}

Map<String, dynamic> _workoutJson({
  String titulo = 'Longão',
  num km = 10.5,
  int seconds = 3725,
  List<String> fotos = const [],
}) => {
  '_id': 'w1',
  'titulo': titulo,
  'descricao': 'Bom treino',
  'tipoTreino': 'longao',
  'distanciaKm': km,
  'duracaoSegundos': seconds,
  'tempoFormatado': '01:02:05',
  'paceMedio': '05:55 min/km',
  'altimetria': 80,
  'sensacaoEsforco': 'dificil',
  'fotos': fotos,
  'dataTreino': '2026-10-20T12:00:00.000Z',
  'atleta': {'_id': 'dono', 'nome': 'Dona'},
  'curtidas': ['fa'],
  'comentarios': const [],
};

Map<String, dynamic> _newsJson({String? criadoPor = 'dono', String? link}) => {
  '_id': 'n1',
  'titulo': 'Aviso importante',
  'subtitulo': 'Sub',
  'conteudo': 'Texto da notícia',
  'categoria': 'Aviso',
  'autor': 'Equipe',
  'destaque': true,
  'criadoPor': ?criadoPor,
  'linkOriginal': ?link,
};

http.Response _ok(Object data) => http.Response.bytes(
  utf8.encode(jsonEncode({'sucesso': true, 'dados': data})),
  200,
  headers: {'content-type': 'application/json'},
);

http.Response _fail(int status, String message) => http.Response.bytes(
  utf8.encode(jsonEncode({'sucesso': false, 'mensagem': message})),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  final requests = <http.Request>[];
  late Future<http.Response> Function(http.Request) handler;
  bool? popped;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    requests.clear();
    popped = null;
    handler = (_) async => _ok({});
    ApiClient.client = MockClient((request) async {
      requests.add(request);
      return handler(request);
    });
  });

  /// Abre a tela por cima de outra, como no app, para testar a volta.
  Future<void> open(
    WidgetTester tester,
    Widget page, {
    String id = 'dono',
    String type = 'atleta',
    WorkoutsProvider? workouts,
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(create: (_) => _FakeAuth(id, type)),
          ChangeNotifierProvider<WorkoutsProvider>(create: (_) => workouts ?? WorkoutsProvider()),
        ],
        child: MaterialApp(
          theme: buildRRTheme(Brightness.light),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => page));
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

  group('edição de treino', () {
    testWidgets('quem publicou vê editar e excluir', (tester) async {
      await open(tester, WorkoutDetailScreen(workout: WorkoutModel.fromJson(_workoutJson())));
      expect(find.byTooltip('Editar treino'), findsOneWidget);
      expect(find.byTooltip('Excluir treino'), findsOneWidget);
    });

    testWidgets('o admin modera excluindo, mas não edita', (tester) async {
      await open(tester, WorkoutDetailScreen(workout: WorkoutModel.fromJson(_workoutJson())), id: 'adm', type: 'admin');
      expect(find.byTooltip('Editar treino'), findsNothing);
      expect(find.byTooltip('Excluir treino'), findsOneWidget);
    });

    testWidgets('outra pessoa não vê nenhuma das ações', (tester) async {
      await open(tester, WorkoutDetailScreen(workout: WorkoutModel.fromJson(_workoutJson())), id: 'outra');
      expect(find.byTooltip('Editar treino'), findsNothing);
      expect(find.byTooltip('Excluir treino'), findsNothing);
    });

    testWidgets('o formulário abre preenchido e envia os valores por PUT', (tester) async {
      final workout = WorkoutModel.fromJson(_workoutJson());
      handler = (_) async => _ok(_workoutJson(titulo: 'Longão editado'));
      await open(tester, NewWorkoutScreen(workout: workout));

      expect(find.text('Salvar alterações'), findsOneWidget);
      final values = tester
          .widgetList<TextFormField>(find.byType(TextFormField))
          .map((field) => field.controller!.text)
          .toList();
      expect(values, containsAll(['Longão', '10,5', '01', '02', '05', '80', 'Bom treino']));

      await tester.enterText(find.widgetWithText(TextFormField, 'Longão').first, 'Longão editado');
      await tester.tap(find.text('Salvar alterações'));
      await tester.pumpAndSettle();

      final request = requests.single;
      expect(request.method, 'PUT');
      expect(request.url.path, endsWith('/workouts/w1'));
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['titulo'], 'Longão editado');
      expect(body['distanciaKm'], 10.5);
      expect(body['duracaoSegundos'], 3725);
      expect(body['altimetria'], 80);
      expect(body['tipoTreino'], 'longao');
      expect(body['sensacaoEsforco'], 'dificil');
      expect(body['fotos'], isEmpty);

      expect(find.text('abrir'), findsOneWidget);
      expect(workout.titulo, 'Longão editado');
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('remover uma foto antiga mantém as outras e libera a vaga', (tester) async {
      final paths = ['/uploads/workouts/a.png', '/uploads/workouts/b.png', '/uploads/workouts/c.png', '/uploads/workouts/d.png'];
      handler = (_) async => _ok(_workoutJson(fotos: paths.sublist(1)));
      await open(tester, NewWorkoutScreen(workout: WorkoutModel.fromJson(_workoutJson(fotos: paths))));
      expect(find.text('4 DE 4'), findsOneWidget);
      expect(find.text('Adicionar'), findsNothing);

      await tester.tap(find.byTooltip('Remover foto 1'));
      await tester.pumpAndSettle();
      expect(find.text('3 DE 4'), findsOneWidget);
      expect(find.text('Adicionar'), findsOneWidget);

      await tester.tap(find.text('Salvar alterações'));
      await tester.pumpAndSettle();
      expect((jsonDecode(requests.single.body) as Map)['fotos'], paths.sublist(1));
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('se o servidor recusar, fica no formulário e não altera o treino', (tester) async {
      final workout = WorkoutModel.fromJson(_workoutJson());
      handler = (_) async => _fail(400, 'Informe uma distância válida.');
      await open(tester, NewWorkoutScreen(workout: workout));
      await tester.tap(find.text('Salvar alterações'));
      await tester.pumpAndSettle();
      expect(find.text('Salvar alterações'), findsOneWidget);
      expect(find.text('Informe uma distância válida.'), findsOneWidget);
      expect(workout.titulo, 'Longão');
      await tester.pump(const Duration(seconds: 5));
    });

    test('a edição vale para todas as cópias do treino e mantém curtidas', () async {
      handler = (request) async => request.method == 'PUT'
          ? _ok(_workoutJson(titulo: 'Novo', km: 5, seconds: 1800))
          : _ok([_workoutJson()]);
      final provider = WorkoutsProvider();
      await provider.loadFeed();
      await provider.loadMine('dono');
      final outsider = WorkoutModel.fromJson(_workoutJson());

      await provider.update(outsider, {'titulo': 'Novo'});

      for (final w in [outsider, provider.feed.single, provider.mine.single]) {
        expect(w.titulo, 'Novo');
        expect(w.distanciaKm, 5);
        expect(w.curtidas, ['fa']);
      }
    });

    testWidgets('a data salva fora do intervalo normal não quebra o calendário', (tester) async {
      final old = {..._workoutJson(), 'dataTreino': '2010-01-01T12:00:00.000Z'};
      await open(tester, NewWorkoutScreen(workout: WorkoutModel.fromJson(old)));
      await tester.ensureVisible(find.byType(RRInfoLine).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(RRInfoLine).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });
  });

  group('edição de notícia', () {
    testWidgets('quem publicou vê editar e excluir', (tester) async {
      await open(tester, NewsDetailScreen(news: NewsModel.fromJson(_newsJson())), type: 'organizador');
      expect(find.byTooltip('Editar notícia'), findsOneWidget);
      expect(find.byTooltip('Excluir notícia'), findsOneWidget);
    });

    testWidgets('outro organizador não vê as ações', (tester) async {
      await open(tester, NewsDetailScreen(news: NewsModel.fromJson(_newsJson())), id: 'outra', type: 'organizador');
      expect(find.byTooltip('Editar notícia'), findsNothing);
      expect(find.byTooltip('Excluir notícia'), findsNothing);
    });

    testWidgets('o admin altera notícia antiga, sem dono', (tester) async {
      await open(tester, NewsDetailScreen(news: NewsModel.fromJson(_newsJson(criadoPor: null))), id: 'adm', type: 'admin');
      expect(find.byTooltip('Editar notícia'), findsOneWidget);
      expect(find.byTooltip('Excluir notícia'), findsOneWidget);
    });

    testWidgets('matéria externa só pode ser ocultada', (tester) async {
      await open(
        tester,
        NewsDetailScreen(news: NewsModel.fromJson(_newsJson(link: 'https://exemplo.com/x'))),
        id: 'adm',
        type: 'admin',
      );
      expect(find.byTooltip('Ocultar matéria'), findsOneWidget);
      expect(find.byTooltip('Editar notícia'), findsNothing);
      expect(find.byTooltip('Excluir notícia'), findsNothing);
    });

    testWidgets('editar abre preenchido, envia por PUT e volta para a lista recarregar', (tester) async {
      await open(tester, NewsDetailScreen(news: NewsModel.fromJson(_newsJson())), type: 'organizador');
      await tester.tap(find.byTooltip('Editar notícia'));
      await tester.pumpAndSettle();
      expect(find.text('Salvar alterações'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Texto da notícia'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Aviso importante'), 'Aviso corrigido');
      await tester.tap(find.text('Salvar alterações'));
      await tester.pumpAndSettle();

      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(requests.single.method, 'PUT');
      expect(requests.single.url.path, endsWith('/news/n1'));
      expect(body['titulo'], 'Aviso corrigido');
      expect(body['conteudo'], 'Texto da notícia');
      expect(body['categoria'], 'Aviso');
      expect(body['destaque'], isTrue);
      expect(popped, isTrue);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('desistir de editar não envia nada e continua na notícia', (tester) async {
      await open(tester, NewsDetailScreen(news: NewsModel.fromJson(_newsJson())), type: 'organizador');
      await tester.tap(find.byTooltip('Editar notícia'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Voltar').last);
      await tester.pumpAndSettle();
      expect(requests, isEmpty);
      expect(find.byTooltip('Editar notícia'), findsOneWidget);
      expect(popped, isNull);
    });

    testWidgets('exclui só depois de confirmar', (tester) async {
      await open(tester, NewsDetailScreen(news: NewsModel.fromJson(_newsJson())), type: 'organizador');
      await tester.tap(find.byTooltip('Excluir notícia'));
      await tester.pumpAndSettle();
      expect(requests, isEmpty);

      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      expect(requests.single.method, 'DELETE');
      expect(requests.single.url.path, endsWith('/news/n1'));
      expect(popped, isTrue);
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
