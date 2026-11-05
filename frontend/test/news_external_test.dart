import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/src/core/network/api_client.dart';
import 'package:frontend/src/core/theme/rr_theme.dart';
import 'package:frontend/src/features/auth/data/models/user_model.dart';
import 'package:frontend/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:frontend/src/features/news/data/news_model.dart';
import 'package:frontend/src/features/news/presentation/news_detail_screen.dart';
import 'package:frontend/src/features/news/presentation/news_screen.dart';
import 'package:frontend/src/features/news/presentation/news_sources_screen.dart';
import 'package:frontend/src/features/news/presentation/news_widgets.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _externalJson() => {
  '_id': 'n1',
  'titulo': 'Treinar devagar ajuda',
  'conteudo': 'Resumo da matéria…',
  'categoria': 'Dica de Treino',
  'autor': 'Ana Lima',
  'fonteNome': 'Webrun',
  'linkOriginal': 'https://webrun.com.br/treinar/',
  'publicadoEm': '2026-11-04T12:00:00.000Z',
  'createdAt': '2026-11-05T12:00:00.000Z',
};

http.Response _ok(Object data) => http.Response.bytes(
  utf8.encode(jsonEncode({'sucesso': true, 'novas': 2, 'dados': data})),
  200,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> _source(String id, {bool ativa = true, String? erro}) => {
  'id': id,
  'nome': id == 'webrun' ? 'Webrun' : 'Contra-Relógio',
  'ativa': ativa,
  'ultimaBusca': '2026-11-05T12:00:00.000Z',
  'ultimoErro': erro,
  'totalMaterias': 3,
};

class _FakeAuth extends AuthProvider {
  final String type;
  _FakeAuth(this.type);

  @override
  UserModel? get user => UserModel.fromJson({'_id': 'u', 'nome': 'Pessoa', 'email': 'p@teste.com', 'tipo': type});
}

void main() {
  final requests = <http.Request>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    requests.clear();
  });

  Future<void> pump(WidgetTester tester, Widget child, {String type = 'atleta'}) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => _FakeAuth(type),
        child: MaterialApp(theme: buildRRTheme(Brightness.light), home: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('modelo', () {
    test('matéria externa usa a data da fonte e dá crédito ao autor e ao site', () {
      final news = NewsModel.fromJson(_externalJson());
      expect(news.isExternal, isTrue);
      expect(news.date.toUtc().day, 4);
      expect(news.credit, 'Ana Lima • Webrun');
    });

    test('não repete o nome quando o autor é a própria fonte', () {
      expect(NewsModel.fromJson({..._externalJson(), 'autor': 'Webrun'}).credit, 'Webrun');
    });

    test('notícia própria continua igual', () {
      final news = NewsModel.fromJson({'_id': 'n', 'createdAt': '2026-11-05T12:00:00.000Z'});
      expect(news.isExternal, isFalse);
      expect(news.date, news.createdAt);
    });
  });

  testWidgets('cartão externo mostra a fonte no lugar do tempo de leitura', (tester) async {
    await pump(tester, Scaffold(body: NewsCard(news: NewsModel.fromJson(_externalJson()))));
    expect(find.textContaining('Webrun •'), findsOneWidget);
    expect(find.textContaining('min de leitura'), findsNothing);
  });

  testWidgets('detalhe externo mostra resumo, crédito e botão para a fonte', (tester) async {
    await pump(tester, NewsDetailScreen(news: NewsModel.fromJson(_externalJson())));
    expect(find.text('Resumo da matéria…'), findsOneWidget);
    expect(find.textContaining('ANA LIMA • WEBRUN'), findsOneWidget);
    expect(find.text('Ler matéria completa no Webrun'), findsOneWidget);
    expect(find.textContaining('pertencem ao site original'), findsOneWidget);
    expect(find.byTooltip('Ocultar matéria'), findsNothing);
  });

  testWidgets('notícia própria não mostra botão de fonte', (tester) async {
    await pump(
      tester,
      NewsDetailScreen(
        news: NewsModel.fromJson({'_id': 'n', 'titulo': 'Própria', 'conteudo': 'Texto', 'autor': 'Equipe'}),
      ),
    );
    expect(find.textContaining('Ler matéria completa'), findsNothing);
    expect(find.textContaining('site original'), findsNothing);
  });

  testWidgets('admin oculta a matéria depois de confirmar', (tester) async {
    ApiClient.client = MockClient((request) async {
      requests.add(request);
      return _ok({});
    });
    await pump(tester, NewsDetailScreen(news: NewsModel.fromJson(_externalJson())), type: 'admin');
    await tester.tap(find.byTooltip('Ocultar matéria'));
    await tester.pumpAndSettle();
    expect(requests, isEmpty, reason: 'nada acontece antes de confirmar');

    await tester.tap(find.text('Ocultar'));
    await tester.pumpAndSettle();
    expect(requests.single.method, 'PUT');
    expect(requests.single.url.path, endsWith('/news/n1/visibility'));
    expect(jsonDecode(requests.single.body), {'oculta': true});
    await tester.pump(const Duration(seconds: 5));
  });

  group('fontes', () {
    void serve({List<Map<String, dynamic>>? synced}) {
      ApiClient.client = MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        if (path.endsWith('/hidden')) return _ok([_externalJson()]);
        if (path.endsWith('/sync')) return _ok(synced ?? [_source('webrun')]);
        if (request.method == 'PUT' && path.endsWith('/sources/webrun')) {
          return _ok([_source('webrun', ativa: false)]);
        }
        if (request.method == 'PUT') return _ok({});
        return _ok([_source('webrun'), _source('contra-relogio')]);
      });
    }

    testWidgets('lista as fontes e desliga uma', (tester) async {
      serve();
      await pump(tester, const NewsSourcesScreen(), type: 'admin');
      expect(find.text('Webrun'), findsWidgets); // também aparece na matéria oculta
      expect(find.text('Contra-Relógio'), findsOneWidget);

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      final put = requests.last;
      expect(put.url.path, endsWith('/news/sources/webrun'));
      expect(jsonDecode(put.body), {'ativa': false});
      expect(find.textContaining('Desligada'), findsOneWidget);
    });

    testWidgets('mostra matéria oculta e permite trazê-la de volta', (tester) async {
      serve();
      await pump(tester, const NewsSourcesScreen(), type: 'admin');
      expect(find.text('Treinar devagar ajuda'), findsOneWidget);

      await tester.tap(find.text('Mostrar'));
      await tester.pumpAndSettle();
      expect(requests.last.url.path, endsWith('/news/n1/visibility'));
      expect(jsonDecode(requests.last.body), {'oculta': false});
      expect(find.text('Treinar devagar ajuda'), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('buscar agora informa o resultado e mostra a falha da fonte', (tester) async {
      serve(synced: [_source('webrun', erro: 'HTTP 503')]);
      await pump(tester, const NewsSourcesScreen(), type: 'admin');
      await tester.tap(find.text('Buscar agora'));
      await tester.pumpAndSettle();
      expect(find.text('Não foi possível ler 1 fonte.'), findsOneWidget);
      expect(find.text('Falha na última leitura: HTTP 503'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('carregar mais', () {
    Map<String, dynamic> item(int i) => {
      '_id': 'n$i',
      'titulo': 'Matéria $i',
      'conteudo': 'Resumo',
      'createdAt': '2026-11-05T12:00:00.000Z',
    };

    http.Response pageResponse(List<int> ids, {required bool more}) => http.Response.bytes(
      utf8.encode(jsonEncode({'sucesso': true, 'temMais': more, 'dados': ids.map(item).toList()})),
      200,
      headers: {'content-type': 'application/json'},
    );

    testWidgets('acrescenta a próxima página, sem repetir, e o botão some no fim', (tester) async {
      ApiClient.client = MockClient((request) async {
        requests.add(request);
        return request.url.queryParameters['page'] == '1'
            ? pageResponse([1, 2], more: true)
            : pageResponse([2, 3], more: false);
      });
      await pump(tester, const Scaffold(body: NewsScreen()));
      expect(find.text('Matéria 2'), findsOneWidget);
      expect(find.text('Matéria 3'), findsNothing);

      await tester.tap(find.text('Carregar mais'));
      await tester.pumpAndSettle();
      expect(requests.last.url.queryParameters['page'], '2');
      expect(find.text('Matéria 1'), findsOneWidget);
      expect(find.text('Matéria 2'), findsOneWidget);
      expect(find.text('Matéria 3'), findsOneWidget);
      expect(find.text('Carregar mais'), findsNothing);
    });

    testWidgets('sem outra página, não mostra o botão', (tester) async {
      ApiClient.client = MockClient((_) async => pageResponse([1], more: false));
      await pump(tester, const Scaffold(body: NewsScreen()));
      expect(find.text('Carregar mais'), findsNothing);
    });

    testWidgets('falha ao carregar mantém a lista e permite tentar de novo', (tester) async {
      var fail = true;
      ApiClient.client = MockClient((request) async {
        if (request.url.queryParameters['page'] == '1') return pageResponse([1], more: true);
        if (fail) throw Exception('sem rede');
        return pageResponse([2], more: false);
      });
      await pump(tester, const Scaffold(body: NewsScreen()));
      await tester.tap(find.text('Carregar mais'));
      await tester.pumpAndSettle();
      expect(find.text('Matéria 1'), findsOneWidget);
      expect(find.text('Carregar mais'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));

      fail = false;
      await tester.tap(find.text('Carregar mais'));
      await tester.pumpAndSettle();
      expect(find.text('Matéria 2'), findsOneWidget);
    });

    testWidgets('trocar de categoria recomeça da primeira página', (tester) async {
      ApiClient.client = MockClient((request) async {
        requests.add(request);
        if (request.url.queryParameters['categoria'] == 'Nutrição') return pageResponse([9], more: false);
        return request.url.queryParameters['page'] == '1'
            ? pageResponse([1], more: true)
            : pageResponse([2], more: false);
      });
      await pump(tester, const Scaffold(body: NewsScreen()));
      await tester.tap(find.text('Carregar mais'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nutrição'));
      await tester.pumpAndSettle();
      expect(requests.last.url.queryParameters['page'], '1');
      expect(find.text('Matéria 9'), findsOneWidget);
      expect(find.text('Matéria 1'), findsNothing);
    });
  });

  testWidgets('capa que não carrega dá lugar à arte da marca', (tester) async {
    await pump(
      tester,
      Scaffold(
        body: NewsCover(
          NewsModel.fromJson({..._externalJson(), 'imagemUrl': 'https://x.test/a.jpg'}),
          width: 80,
          height: 80,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsOneWidget);
  });
}
