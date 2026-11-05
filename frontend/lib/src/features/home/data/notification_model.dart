import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../workouts/data/workout_model.dart';

class NotificationModel {
  final String id, tipo;
  final AthleteRef autor;
  final String? treinoId, treinoTitulo;
  final DateTime createdAt;

  /// Mantida em memória para destacar o que era novo ao abrir a tela.
  final bool lida;

  const NotificationModel({
    required this.id,
    required this.tipo,
    required this.autor,
    required this.createdAt,
    required this.lida,
    this.treinoId,
    this.treinoTitulo,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final treino = json['treino'];
    return NotificationModel(
      id: json['_id'] as String? ?? '',
      tipo: json['tipo'] as String? ?? '',
      autor: AthleteRef.fromJson(json['autor']),
      treinoId: treino is Map ? treino['_id'] as String? : treino as String?,
      treinoTitulo: treino is Map ? treino['titulo'] as String? : null,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      lida: json['lida'] as bool? ?? false,
    );
  }

  String get action => switch (tipo) {
    'curtida' => 'curtiu seu treino',
    'comentario' => 'comentou no seu treino',
    'seguidor' => 'começou a seguir você',
    _ => 'interagiu com você',
  };
}

/// Sino e lista de notificações. Consulta o servidor de tempos em tempos enquanto
/// a área logada está aberta.
class NotificationsProvider extends ChangeNotifier {
  static const _interval = Duration(seconds: 60);

  List<NotificationModel> items = [];
  int unread = 0;
  bool loading = false;
  String? error;
  Timer? _timer;

  void startPolling() {
    _timer?.cancel();
    refreshUnread();
    _timer = Timer.periodic(_interval, (_) => refreshUnread());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
    items = [];
    unread = 0;
    error = null;
  }

  Future<void> refreshUnread() async {
    try {
      final data = await ApiClient.get('${ApiConstants.notifications}/unread-count');
      final count = (data['naoLidas'] as num? ?? 0).toInt();
      if (count != unread) {
        unread = count;
        notifyListeners();
      }
    } on ApiException {
      // O contador é complementar: tenta de novo na próxima consulta.
    }
  }

  /// Carrega a lista e marca tudo como lido no servidor.
  Future<void> open() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final data = await ApiClient.get(ApiConstants.notifications);
      items = (data['dados'] as List).map((e) => NotificationModel.fromJson(e as Map<String, dynamic>)).toList();
      if (unread > 0 || items.any((n) => !n.lida)) {
        await ApiClient.post('${ApiConstants.notifications}/read-all');
      }
      unread = 0;
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
