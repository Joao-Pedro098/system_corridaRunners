import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

class NewsModel {
  static const categories = ['Novidade', 'Dica de Treino', 'Nutrição', 'Aviso', 'Destaque'];

  final String id, titulo, conteudo, categoria, autor;
  final String? subtitulo, imagemUrl, linkOriginal, fonteNome, criadoPor;
  final bool destaque;
  final DateTime createdAt;
  final DateTime? publicadoEm;

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
    this.linkOriginal,
    this.fonteNome,
    this.criadoPor,
    this.publicadoEm,
  });

  factory NewsModel.fromJson(Map<String, dynamic> json) => NewsModel(
    id: json['_id'] as String? ?? '',
    titulo: json['titulo'] as String? ?? '',
    conteudo: json['conteudo'] as String? ?? '',
    categoria: json['categoria'] as String? ?? 'Novidade',
    autor: json['autor'] as String? ?? 'Comunidade de Corridas',
    subtitulo: json['subtitulo'] as String?,
    imagemUrl: json['imagemUrl'] as String?,
    linkOriginal: json['linkOriginal'] as String?,
    fonteNome: json['fonteNome'] as String?,
    criadoPor: json['criadoPor']?.toString(),
    destaque: json['destaque'] as bool? ?? false,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ?? DateTime.now(),
    publicadoEm: DateTime.tryParse(json['publicadoEm'] as String? ?? '')?.toLocal(),
  );

  /// Matéria de outro site: o app mostra só o resumo e leva à fonte original.
  bool get isExternal => linkOriginal != null && linkOriginal!.isNotEmpty;

  DateTime get date => publicadoEm ?? createdAt;

  /// Crédito da matéria externa, sem repetir o nome quando o autor é a própria fonte.
  String get credit {
    final source = fonteNome ?? autor;
    return autor == source ? source : '$autor • $source';
  }

  /// Estimativa de leitura a 200 palavras por minuto.
  int get readingMinutes {
    final words = conteudo.trim().split(RegExp(r'\s+')).length;
    return (words / 200).ceil().clamp(1, 60);
  }
}

class NewsSourceModel {
  final String id, nome;
  final bool ativa;
  final DateTime? ultimaBusca;
  final String? ultimoErro;
  final int totalMaterias;

  const NewsSourceModel({
    required this.id,
    required this.nome,
    required this.ativa,
    required this.totalMaterias,
    this.ultimaBusca,
    this.ultimoErro,
  });

  factory NewsSourceModel.fromJson(Map<String, dynamic> json) => NewsSourceModel(
    id: json['id'] as String? ?? '',
    nome: json['nome'] as String? ?? '',
    ativa: json['ativa'] as bool? ?? true,
    ultimaBusca: DateTime.tryParse(json['ultimaBusca'] as String? ?? '')?.toLocal(),
    ultimoErro: json['ultimoErro'] as String?,
    totalMaterias: (json['totalMaterias'] as num? ?? 0).toInt(),
  );
}

class NewsService {
  NewsService._();

  static List<NewsModel> _news(dynamic list) =>
      (list as List).map((e) => NewsModel.fromJson(e as Map<String, dynamic>)).toList();

  static List<NewsSourceModel> _sources(dynamic list) =>
      (list as List).map((e) => NewsSourceModel.fromJson(e as Map<String, dynamic>)).toList();

  static Future<List<NewsModel>> list({String? categoria}) async => _news(
    (await ApiClient.get(ApiConstants.news, query: categoria == null ? null : {'categoria': categoria}))['dados'],
  );

  /// Uma página da lista e se existe outra depois dela.
  static Future<({List<NewsModel> items, bool hasMore})> page({String? categoria, int page = 1, int limit = 20}) async {
    final data = await ApiClient.get(
      ApiConstants.news,
      query: {'categoria': ?categoria, 'page': '$page', 'limit': '$limit'},
    );
    return (items: _news(data['dados']), hasMore: data['temMais'] as bool? ?? false);
  }

  static Future<void> create(Map<String, dynamic> body) => ApiClient.post(ApiConstants.news, body);

  static Future<void> update(String id, Map<String, dynamic> body) => ApiClient.put('${ApiConstants.news}/$id', body);

  static Future<void> delete(String id) => ApiClient.delete('${ApiConstants.news}/$id');

  static Future<void> setHidden(String id, bool hidden) =>
      ApiClient.put('${ApiConstants.news}/$id/visibility', {'oculta': hidden});

  static Future<List<NewsModel>> hidden() async => _news((await ApiClient.get('${ApiConstants.news}/hidden'))['dados']);

  static Future<List<NewsSourceModel>> sources() async =>
      _sources((await ApiClient.get('${ApiConstants.news}/sources'))['dados']);

  static Future<List<NewsSourceModel>> setSourceActive(String id, bool active) async =>
      _sources((await ApiClient.put('${ApiConstants.news}/sources/$id', {'ativa': active}))['dados']);

  /// A busca abre a página de cada matéria nova para achar a capa, por isso pode demorar.
  static Future<({int novas, List<NewsSourceModel> sources})> syncNow() async {
    final data = await ApiClient.post('${ApiConstants.news}/sources/sync', null, const Duration(seconds: 120));
    return (novas: (data['novas'] as num? ?? 0).toInt(), sources: _sources(data['dados']));
  }
}
