import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/user_model.dart';

class AuthService {
  static const String _tokenKey = 'jwt_token';
  static const String _userKey = 'user_data';

  /// Realizar login. Com [remember] falso, a sessão dura até fechar o app.
  Future<UserModel> login(String email, String senha, {bool remember = true}) async {
    final data = await ApiClient.post(ApiConstants.login, {'email': email.trim().toLowerCase(), 'senha': senha});
    return _startSession(data['dados'] as Map<String, dynamic>, remember: remember);
  }

  /// Realizar cadastro
  Future<UserModel> register({
    required String nome,
    required String email,
    required String senha,
    String tipo = 'atleta',
    String? telefone,
    String? cidade,
    String? estado,
  }) async {
    final data = await ApiClient.post(ApiConstants.register, {
      'nome': nome.trim(),
      'email': email.trim().toLowerCase(),
      'senha': senha,
      'tipo': tipo,
      'telefone': telefone?.trim(),
      'cidade': cidade?.trim(),
      'estado': estado?.trim(),
    });
    return _startSession(data['dados'] as Map<String, dynamic>);
  }

  /// Busca os dados atuais do atleta logado.
  Future<UserModel> me() async {
    final data = await ApiClient.get(ApiConstants.me);
    final user = UserModel.fromJson(data['dados'] as Map<String, dynamic>, token: ApiClient.token);
    await _updateSavedUser(user);
    return user;
  }

  /// Atualiza perfil e recordes pessoais.
  Future<UserModel> updateProfile(Map<String, dynamic> body) async {
    final data = await ApiClient.put(ApiConstants.profile, body);
    final user = UserModel.fromJson(data['dados'] as Map<String, dynamic>, token: ApiClient.token);
    await _updateSavedUser(user);
    return user;
  }

  Future<UserModel> _startSession(Map<String, dynamic> json, {bool remember = true}) async {
    final token = json['token'] as String;
    final user = UserModel.fromJson(json, token: token);
    ApiClient.token = token;
    if (remember) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_userKey, jsonEncode(user.toJson()));
    }
    return user;
  }

  /// Só regrava se a sessão estiver salva neste aparelho.
  Future<void> _updateSavedUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_tokenKey)) {
      await prefs.setString(_userKey, jsonEncode(user.toJson()));
    }
  }

  /// Carrega o usuário salvo (caso já esteja logado)
  Future<UserModel?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final userJson = prefs.getString(_userKey);

    if (token != null && userJson != null) {
      ApiClient.token = token;
      return UserModel.fromJson(jsonDecode(userJson) as Map<String, dynamic>, token: token);
    }
    return null;
  }

  /// Logout
  Future<void> logout() async {
    ApiClient.token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}
