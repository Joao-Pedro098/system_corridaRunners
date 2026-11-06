import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../data/models/user_model.dart';
import '../../data/services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    // Token expirado ou inválido encerra a sessão.
    ApiClient.onUnauthorized = logout;
    checkAuthStatus();
  }

  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();
    try {
      _user = await _authService.getSavedUser();
    } catch (_) {
      _user = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    if (_user != null) await refreshUser();
  }

  /// Atualiza totais, seguidores e provas salvas a partir do servidor.
  Future<void> refreshUser() async {
    if (_user == null) return;
    try {
      _user = await _authService.me();
      notifyListeners();
    } on ApiException {
      // Mantém os dados locais: o app segue utilizável sem conexão momentânea.
    }
  }

  Future<void> updateProfile(Map<String, dynamic> body) async {
    _user = await _authService.updateProfile(body);
    notifyListeners();
  }

  Future<void> changePassword(String current, String next) => _authService.changePassword(current, next);

  Future<void> uploadAvatar(XFile file) async {
    _user = await _authService.uploadAvatar(file);
    notifyListeners();
  }

  Future<void> removeAvatar() async {
    _user = await _authService.removeAvatar();
    notifyListeners();
  }

  Future<bool> login(String email, String senha, {bool remember = true}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _authService.login(email, senha, remember: remember);
      _isLoading = false;
      notifyListeners();
      await refreshUser();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String nome,
    required String email,
    required String senha,
    String tipo = 'atleta',
    String? telefone,
    String? cidade,
    String? estado,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await _authService.register(
        nome: nome,
        email: email,
        senha: senha,
        tipo: tipo,
        telefone: telefone,
        cidade: cidade,
        estado: estado,
      );
      _isLoading = false;
      notifyListeners();
      await refreshUser();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Segue ou deixa de seguir. Devolve o novo total de seguidores do atleta.
  Future<int> toggleFollow(String userId) async {
    final data = await ApiClient.post(ApiConstants.toggleFollow(userId));
    await refreshUser();
    return (data['totalSeguidores'] as num? ?? 0).toInt();
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
