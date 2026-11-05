import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../data/workout_model.dart';

/// Estado do feed e dos treinos do atleta logado.
class WorkoutsProvider extends ChangeNotifier {
  final List<WorkoutModel> feed = [];
  List<WorkoutModel> mine = [];
  bool loading = false, loadingMore = false, hasMore = false;
  String? error;
  int _page = 1;

  /// Treinos excluídos nesta sessão, para sumirem de listas já carregadas.
  final Set<String> _deleted = {};
  bool isDeleted(String id) => _deleted.contains(id);

  /// O mesmo treino pode estar no feed e em "meus treinos" como objetos
  /// diferentes: as alterações valem para todas as cópias.
  Iterable<WorkoutModel> _copies(WorkoutModel workout) => <WorkoutModel>{
    workout,
    ...feed.where((w) => w.id == workout.id),
    ...mine.where((w) => w.id == workout.id),
  };

  WeekSummary get week => WeekSummary.from(mine);

  static List<WorkoutModel> _parse(Map<String, dynamic> data) =>
      (data['dados'] as List).map((e) => WorkoutModel.fromJson(e as Map<String, dynamic>)).toList();

  Future<void> loadFeed() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final data = await ApiClient.get(ApiConstants.workoutsFeed, query: {'page': '1', 'limit': '20'});
      feed
        ..clear()
        ..addAll(_parse(data));
      _page = 1;
      hasMore = _page < (data['paginasTotal'] as num? ?? 1);
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (loadingMore || !hasMore) return;
    loadingMore = true;
    notifyListeners();
    try {
      final data = await ApiClient.get(ApiConstants.workoutsFeed, query: {'page': '${_page + 1}', 'limit': '20'});
      feed.addAll(_parse(data));
      _page++;
      hasMore = _page < (data['paginasTotal'] as num? ?? 1);
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> loadMine(String userId) async {
    try {
      mine = await byUser(userId);
      notifyListeners();
    } on ApiException {
      // O resumo da semana é complementar: se falhar, o feed segue funcionando.
    }
  }

  static Future<List<WorkoutModel>> byUser(String userId) async =>
      _parse(await ApiClient.get('${ApiConstants.workouts}/user/$userId'));

  static Future<WorkoutModel> byId(String id) async {
    final data = await ApiClient.get('${ApiConstants.workouts}/$id');
    return WorkoutModel.fromJson(data['dados'] as Map<String, dynamic>);
  }

  /// Envia as fotos e devolve os caminhos para usar ao publicar.
  Future<List<String>> uploadPhotos(List<XFile> photos) async {
    final files = <http.MultipartFile>[
      for (final photo in photos)
        http.MultipartFile.fromBytes(
          'fotos',
          await photo.readAsBytes(),
          filename: photo.name,
          contentType: MediaType.parse(photo.mimeType ?? 'image/jpeg'),
        ),
    ];
    final data = await ApiClient.upload(ApiConstants.workoutPhotos, files);
    return (data['dados'] as List).cast<String>();
  }

  Future<void> publish(Map<String, dynamic> body) async {
    final data = await ApiClient.post(ApiConstants.workouts, body);
    final created = WorkoutModel.fromJson(data['dados'] as Map<String, dynamic>);
    feed.insert(0, created);
    mine = [created, ...mine];
    notifyListeners();
  }

  /// Curte de forma otimista e desfaz se o servidor recusar.
  Future<void> toggleLike(WorkoutModel workout, String userId) async {
    final liked = workout.curtidas.contains(userId);
    void apply(bool like) {
      for (final w in _copies(workout)) {
        w.curtidas.remove(userId);
        if (like) w.curtidas.add(userId);
      }
      notifyListeners();
    }

    apply(!liked);
    try {
      await ApiClient.post('${ApiConstants.workouts}/${workout.id}/like');
    } on ApiException {
      apply(liked);
      rethrow;
    }
  }

  Future<void> addComment(WorkoutModel workout, String text) async {
    final data = await ApiClient.post('${ApiConstants.workouts}/${workout.id}/comments', {'texto': text});
    _setComments(workout, data['dados'] as List);
  }

  Future<void> deleteComment(WorkoutModel workout, WorkoutComment comment) async {
    final data = await ApiClient.delete('${ApiConstants.workouts}/${workout.id}/comments/${comment.id}');
    _setComments(workout, data['dados'] as List);
  }

  void _setComments(WorkoutModel workout, List json) {
    final comments = json.map((e) => WorkoutComment.fromJson(e as Map<String, dynamic>)).toList();
    for (final w in _copies(workout)) {
      w.comentarios
        ..clear()
        ..addAll(comments);
    }
    notifyListeners();
  }

  Future<void> delete(WorkoutModel workout) async {
    await ApiClient.delete('${ApiConstants.workouts}/${workout.id}');
    _deleted.add(workout.id);
    feed.removeWhere((w) => w.id == workout.id);
    mine = mine.where((w) => w.id != workout.id).toList();
    notifyListeners();
  }

  void clear() {
    feed.clear();
    mine = [];
    error = null;
    hasMore = false;
    _deleted.clear();
  }
}
