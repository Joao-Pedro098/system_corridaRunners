import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/src/core/network/api_client.dart';
import 'package:frontend/src/core/theme/rr_theme.dart';
import 'package:frontend/src/core/widgets/rr_labels.dart';
import 'package:frontend/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:frontend/src/features/auth/presentation/screens/change_password_screen.dart';
import 'package:frontend/src/features/profile/presentation/edit_profile_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _userJson({String avatar = ''}) => {
  '_id': 'u1',
  'nome': 'Pessoa Teste',
  'email': 'p@teste.com',
  'tipo': 'atleta',
  'avatarUrl': avatar,
};

http.Response _reply(int status, Map<String, dynamic> body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});

void main() {
  final requests = <http.BaseRequest>[];
  final bodies = <String>[];
  var avatar = '';
  late AuthProvider auth;
  http.Response Function(http.Request)? override;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    requests.clear();
    bodies.clear();
    avatar = '';
    override = null;
    ApiClient.token = null;
    ApiClient.client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/auth/login')) {
        return _reply(200, {
          'sucesso': true,
          'dados': {..._userJson(avatar: avatar), 'token': 'token-antigo'},
        });
      }
      if (path.endsWith('/auth/me')) return _reply(200, {'sucesso': true, 'dados': _userJson(avatar: avatar)});
      requests.add(request);
      bodies.add(request.body);
      final custom = override?.call(request);
      if (custom != null) return custom;
      if (path.endsWith('/auth/password')) return _reply(200, {'sucesso': true, 'token': 'token-novo'});
      if (path.endsWith('/auth/avatar')) {
        avatar = request.method == 'DELETE' ? '' : '/uploads/avatars/u1-nova.png';
        return _reply(200, {'sucesso': true, 'dados': _userJson(avatar: avatar)});
      }
      return _reply(200, {'sucesso': true, 'dados': _userJson(avatar: avatar)});
    });
    auth = AuthProvider();
    await auth.login('p@teste.com', 'senha-atual');
  });

  Future<void> open(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
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

  Future<void> fill(WidgetTester tester, String current, String next, String confirm) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), current);
    await tester.enterText(fields.at(1), next);
    await tester.enterText(fields.at(2), confirm);
    await tester.tap(find.text('Alterar senha').last);
    await tester.pumpAndSettle();
  }

  group('troca de senha', () {
    testWidgets('confere os campos antes de enviar', (tester) async {
      await open(tester, const ChangePasswordScreen());

      await fill(tester, 'senha-atual', '123', '123');
      expect(find.text('A senha deve ter no mínimo 6 caracteres'), findsOneWidget);

      await fill(tester, 'senha-atual', 'senha-atual', 'senha-atual');
      expect(find.text('A nova senha precisa ser diferente da atual'), findsOneWidget);

      await fill(tester, 'senha-atual', 'senha-nova', 'outra-coisa');
      expect(find.text('As senhas não são iguais'), findsOneWidget);

      expect(requests, isEmpty);
    });

    testWidgets('envia as senhas e passa a usar o token novo', (tester) async {
      await open(tester, const ChangePasswordScreen());
      expect(ApiClient.token, 'token-antigo');

      await fill(tester, 'senha-atual', 'senha-nova', 'senha-nova');

      expect(requests.single.method, 'PUT');
      expect(requests.single.url.path, endsWith('/auth/password'));
      expect(jsonDecode(bodies.single), {'senhaAtual': 'senha-atual', 'novaSenha': 'senha-nova'});
      expect(ApiClient.token, 'token-novo');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('jwt_token'), 'token-novo');
      expect(find.text('abrir'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('senha atual errada avisa, fica na tela e não encerra a sessão', (tester) async {
      override = (_) => _reply(400, {'sucesso': false, 'mensagem': 'A senha atual está incorreta.'});
      await open(tester, const ChangePasswordScreen());

      await fill(tester, 'errada', 'senha-nova', 'senha-nova');

      expect(find.text('A senha atual está incorreta.'), findsOneWidget);
      expect(find.text('abrir'), findsNothing);
      expect(auth.isAuthenticated, isTrue);
      expect(ApiClient.token, 'token-antigo');
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('foto de perfil', () {
    test('o envio usa o campo foto e atualiza o usuário', () async {
      final file = XFile.fromData(utf8.encode('imagem'), name: 'foto.png', mimeType: 'image/png');
      await auth.uploadAvatar(file);

      final request = requests.single as http.Request;
      expect(request.method, 'POST');
      expect(request.url.path, endsWith('/auth/avatar'));
      expect(request.headers['content-type'], contains('multipart/form-data'));
      expect(request.body, contains('name="foto"'));
      expect(request.headers['Authorization'], 'Bearer token-antigo');
      expect(auth.user?.avatarUrl, '/uploads/avatars/u1-nova.png');
    });

    testWidgets('o avatar enviado vira um link completo do servidor', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildRRTheme(Brightness.light),
          home: const RRAvatar('Pessoa', url: '/uploads/avatars/u1-nova.png'),
        ),
      );
      final image = tester.widget<Image>(find.byType(Image)).image as NetworkImage;
      expect(image.url, startsWith('http'));
      expect(image.url, endsWith('/uploads/avatars/u1-nova.png'));
    });

    testWidgets('sem foto, oferece adicionar; não existe mais o campo de link', (tester) async {
      await open(tester, const EditProfileScreen());
      expect(find.text('Adicionar foto'), findsOneWidget);
      expect(find.text('Remover foto'), findsNothing);
      expect(find.text('LINK DA FOTO'), findsNothing);
    });

    testWidgets('remover pede confirmação, vale na hora e salvar o perfil não envia a foto', (tester) async {
      avatar = '/uploads/avatars/u1-antiga.png';
      await auth.refreshUser();
      await open(tester, const EditProfileScreen());
      expect(find.text('Trocar foto'), findsOneWidget);

      await tester.tap(find.text('Remover foto'));
      await tester.pumpAndSettle();
      expect(requests, isEmpty);

      await tester.tap(find.text('Remover'));
      await tester.pumpAndSettle();
      expect(requests.single.method, 'DELETE');
      expect(requests.single.url.path, endsWith('/auth/avatar'));
      expect(find.text('Adicionar foto'), findsOneWidget);
      expect(auth.user?.avatarUrl, isEmpty);

      // O aviso cobre o botão até sumir.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salvar alterações'));
      await tester.pumpAndSettle();
      expect(requests.last.url.path, endsWith('/auth/profile'));
      expect((jsonDecode(bodies.last) as Map).containsKey('avatarUrl'), isFalse);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('a tela de perfil leva à troca de senha', (tester) async {
      await open(tester, const EditProfileScreen());
      await tester.ensureVisible(find.text('Alterar senha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alterar senha'));
      await tester.pumpAndSettle();
      expect(find.byType(ChangePasswordScreen), findsOneWidget);
    });
  });
}
