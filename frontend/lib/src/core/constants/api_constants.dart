import 'package:flutter/foundation.dart';

class ApiConstants {
  // Para apontar para outro servidor ou para um celular físico na mesma rede:
  // flutter run --dart-define=API_URL=http://192.168.0.2:3000/api
  static const String _override = String.fromEnvironment('API_URL');

  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    // O emulador Android enxerga a máquina em 10.0.2.2
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api';
    }
    return 'http://localhost:3000/api';
  }

  /// O backend guarda as fotos como "/uploads/...": aqui viram um link completo.
  static String mediaUrl(String path) {
    if (!path.startsWith('/')) return path;
    return baseUrl.replaceFirst(RegExp(r'/api/?$'), '') + path;
  }

  // Endpoints de Autenticação
  static String get login => '$baseUrl/auth/login';
  static String get register => '$baseUrl/auth/register';
  static String get me => '$baseUrl/auth/me';
  static String get profile => '$baseUrl/auth/profile';

  // Endpoints de Treinos / Comunidade
  static String get workoutsFeed => '$baseUrl/workouts/feed';
  static String get workouts => '$baseUrl/workouts';

  // Endpoints de Corridas e Notícias
  static String get races => '$baseUrl/races';
  static String get news => '$baseUrl/news';
  static String get workoutPhotos => '$baseUrl/workouts/photos';
  static String get notifications => '$baseUrl/notifications';
  static String toggleFollow(String id) => '$baseUrl/auth/users/$id/toggle-follow';
  static String raceAction(String id, String action) => '$baseUrl/auth/races/$id/$action';
}
