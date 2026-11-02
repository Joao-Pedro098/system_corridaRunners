import 'package:flutter/foundation.dart';

class ApiConstants {
  // Para Web e Windows Desktop usamos localhost:3000
  // Para Emulador Android usa-se 10.0.2.2:3000
  // Para celular físico na mesma rede Wi-Fi, pode usar o IP da máquina (ex: 192.168.0.2)
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    }
    // Caso padrão para desktop / testes
    return 'http://localhost:3000/api';
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
}
