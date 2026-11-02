import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/user_model.dart';

class AuthService {
  static const String _tokenKey = 'jwt_token';
  static const String _userKey = 'user_data';

  /// Realizar login
  Future<UserModel> login(String email, String senha) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.login),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'senha': senha,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['sucesso'] == true) {
        final userData = data['dados'];
        final token = userData['token'];

        final user = UserModel.fromJson(userData, token: token);
        await _persistSession(token, user);
        return user;
      } else {
        throw Exception(data['mensagem'] ?? 'Falha ao realizar login.');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Erro de conexão com o servidor. Verifique sua internet.');
    }
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
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.register),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nome': nome.trim(),
          'email': email.trim().toLowerCase(),
          'senha': senha,
          'tipo': tipo,
          'telefone': telefone?.trim(),
          'cidade': cidade?.trim(),
          'estado': estado?.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 && data['sucesso'] == true) {
        final userData = data['dados'];
        final token = userData['token'];

        final user = UserModel.fromJson(userData, token: token);
        await _persistSession(token, user);
        return user;
      } else {
        throw Exception(data['mensagem'] ?? 'Falha ao criar conta.');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Erro de conexão com o servidor. Verifique sua internet.');
    }
  }

  /// Salva token e dados do usuário localmente
  Future<void> _persistSession(String token, UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  /// Carrega o usuário salvo (caso já esteja logado)
  Future<UserModel?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final userJson = prefs.getString(_userKey);

    if (token != null && userJson != null) {
      return UserModel.fromJson(jsonDecode(userJson), token: token);
    }
    return null;
  }

  /// Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}
