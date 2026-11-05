import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

class NewsModel {
  static const categories = ['Novidade', 'Dica de Treino', 'Nutrição', 'Aviso', 'Destaque'];

  final String id, titulo, conteudo, categoria, autor;
  final String? subtitulo, imagemUrl;
  final bool destaque;
  final DateTime createdAt;

  const NewsModel({
    required this.id,
    required this.titulo,
    required this.conteudo,
    required this.categoria,
    required this.autor,
    required this.destaque,
    required this.createdAt,
    this.subtitulo,
    this.imagemUrl,
  });

  factory NewsModel.fromJson(Map<String, dynamic> json) => NewsModel(
    id: json['_id'] as String? ?? '',
    titulo: json['titulo'] as String? ?? '',
    conteudo: json['conteudo'] as String? ?? '',
    categoria: json['categoria'] as String? ?? 'Novidade',
    autor: json['autor'] as String? ?? 'Comunidade de Corridas',
    subtitulo: json['subtitulo'] as String?,
    imagemUrl: json['imagemUrl'] as String?,
    destaque: json['destaque'] as bool? ?? false,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ?? DateTime.now(),
  );

  /// Estimativa de leitura a 200 palavras por minuto.
  int get readingMinutes {
    final words = conteudo.trim().split(RegExp(r'\s+')).length;
    return (words / 200).ceil().clamp(1, 60);
  }
}

class NewsService {
  NewsService._();

  static Future<List<NewsModel>> list({String? categoria}) async {
    final data = await ApiClient.get(ApiConstants.news, query: categoria == null ? null : {'categoria': categoria});
    return (data['dados'] as List).map((e) => NewsModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> create(Map<String, dynamic> body) => ApiClient.post(ApiConstants.news, body);
}
