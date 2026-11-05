import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/rr_theme.dart';

class RaceDistance {
  final num km;
  final String? categoria;
  final int altimetria;
  const RaceDistance({required this.km, this.categoria, this.altimetria = 0});

  factory RaceDistance.fromJson(Map<String, dynamic> json) => RaceDistance(
    km: json['distanciaKm'] as num? ?? 0,
    categoria: json['categoria'] as String?,
    altimetria: (json['altimetria'] as num? ?? 0).toInt(),
  );

  String get label => '${km == km.roundToDouble() ? km.toInt() : km}K';
}

/// Cores de capa do cartão: (fundo, raias, texto).
class RaceTone {
  final Color background, lanes, foreground;
  const RaceTone(this.background, this.lanes, this.foreground);

  static const asfalto = RaceTone(RRPalette.cal950, RRPalette.tartan500, RRPalette.cal50);
  static const tartan = RaceTone(RRPalette.tartan500, RRPalette.cal950, RRPalette.cal950);
  static const mata = RaceTone(RRPalette.mata700, RRPalette.mata300, RRPalette.cal50);
  static const ceu = RaceTone(RRPalette.ceu300, RRPalette.cal950, RRPalette.cal950);
}

class RaceModel {
  /// Valores de `status` no backend: (rótulo, tom da etiqueta).
  static const statuses = <String, (String, RRTone)>{
    'agendada': ('Agendada', RRTone.ceu),
    'inscricoes_abertas': ('Inscrições abertas', RRTone.mata),
    'inscricoes_encerradas': ('Inscrições encerradas', RRTone.ambar),
    'em_andamento': ('Em andamento', RRTone.tartan),
    'concluida': ('Concluída', RRTone.neutro),
    'cancelada': ('Cancelada', RRTone.carmim),
  };

  final String id, nome, status;
  final String? descricao, horarioLargada, cidade, estado, endereco, linkInscricao, preco;
  final String? kitLocal, kitData, kitHorario, kitObservacoes;
  final String? regulamentoUrl, resultadosUrl, fotosUrl, certificadoUrl;
  final String? organizadorNome, organizadorContato;
  final String? criadoPor, bannerPath;
  final DateTime data;
  final List<RaceDistance> distancias;
  final List<String> participantes;

  RaceModel({
    required this.id,
    required this.nome,
    required this.status,
    required this.data,
    required this.distancias,
    required this.participantes,
    this.descricao,
    this.horarioLargada,
    this.cidade,
    this.estado,
    this.endereco,
    this.linkInscricao,
    this.preco,
    this.kitLocal,
    this.kitData,
    this.kitHorario,
    this.kitObservacoes,
    this.regulamentoUrl,
    this.resultadosUrl,
    this.fotosUrl,
    this.certificadoUrl,
    this.organizadorNome,
    this.organizadorContato,
    this.criadoPor,
    this.bannerPath,
  });

  factory RaceModel.fromJson(Map<String, dynamic> json) {
    final local = json['local'] as Map<String, dynamic>? ?? const {};
    final kit = json['retiradaKit'] as Map<String, dynamic>? ?? const {};
    final after = json['posCorrida'] as Map<String, dynamic>? ?? const {};
    final organizer = json['organizador'] as Map<String, dynamic>? ?? const {};
    return RaceModel(
      id: json['_id'] as String? ?? '',
      nome: json['nome'] as String? ?? '',
      status: json['status'] as String? ?? 'agendada',
      descricao: json['descricao'] as String?,
      data: DateTime.tryParse(json['data'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      horarioLargada: json['horarioLargada'] as String?,
      cidade: local['cidade'] as String?,
      estado: local['estado'] as String?,
      endereco: local['endereco'] as String?,
      distancias: (json['distancias'] as List? ?? const [])
          .map((e) => RaceDistance.fromJson(e as Map<String, dynamic>))
          .toList(),
      linkInscricao: json['linkInscricao'] as String?,
      preco: json['preco'] as String?,
      kitLocal: kit['local'] as String?,
      kitData: kit['data'] as String?,
      kitHorario: kit['horario'] as String?,
      kitObservacoes: kit['observacoes'] as String?,
      regulamentoUrl: json['regulamentoUrl'] as String?,
      resultadosUrl: after['linkResultadosChip'] as String?,
      fotosUrl: after['linkGaleriaFotos'] as String?,
      certificadoUrl: after['linkCertificado'] as String?,
      organizadorNome: organizer['nome'] as String?,
      organizadorContato: organizer['contato'] as String?,
      criadoPor: json['criadoPor']?.toString(),
      bannerPath: json['bannerUrl'] as String?,
      // O backend devolve os participantes populados ou apenas os ids.
      participantes: (json['participantesConfirmados'] as List? ?? const [])
          .map((p) => p is Map ? p['_id'].toString() : p.toString())
          .toList(),
    );
  }

  /// Link completo da capa enviada pelo organizador, se houver.
  String? get coverUrl => bannerPath == null || bannerPath!.isEmpty ? null : ApiConstants.mediaUrl(bannerPath!);

  String get statusLabel => (statuses[status] ?? statuses['agendada']!).$1;
  RRTone get statusTone => (statuses[status] ?? statuses['agendada']!).$2;
  bool get isOver => status == 'concluida';
  bool get canConfirm => status == 'inscricoes_abertas' || status == 'agendada' || status == 'em_andamento';
  bool get isClosed => !canConfirm;

  RaceTone get tone => switch (status) {
    'inscricoes_abertas' || 'em_andamento' => RaceTone.tartan,
    'inscricoes_encerradas' => RaceTone.mata,
    'concluida' => RaceTone.ceu,
    _ => RaceTone.asfalto,
  };

  String get cityLine => [cidade, estado].where((v) => v != null && v.isNotEmpty).join(', ');

  String get locationLine {
    final start = horarioLargada == null || horarioLargada!.isEmpty ? '' : ' • Largada $horarioLargada';
    return '$cityLine$start';
  }

  int get elevation => distancias.fold(0, (max, d) => d.altimetria > max ? d.altimetria : max);
}

class RaceService {
  RaceService._();

  static Future<List<RaceModel>> list({String? busca, int? distancia, int? mes, int? ano}) async {
    final data = await ApiClient.get(
      ApiConstants.races,
      query: {
        'limit': '60',
        if (busca != null && busca.isNotEmpty) 'busca': busca,
        if (distancia != null) 'distancia': '$distancia',
        if (mes != null) 'mes': '$mes',
        if (ano != null) 'ano': '$ano',
      },
    );
    return (data['dados'] as List).map((e) => RaceModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<bool> togglePresence(String id) async =>
      (await ApiClient.post(ApiConstants.raceAction(id, 'toggle-presence')))['confirmado'] as bool;

  static Future<bool> toggleSave(String id) async =>
      (await ApiClient.post(ApiConstants.raceAction(id, 'toggle-save')))['salva'] as bool;

  static Future<RaceModel> create(Map<String, dynamic> body) async =>
      RaceModel.fromJson((await ApiClient.post(ApiConstants.races, body))['dados'] as Map<String, dynamic>);

  static Future<RaceModel> update(String id, Map<String, dynamic> body) async =>
      RaceModel.fromJson((await ApiClient.put('${ApiConstants.races}/$id', body))['dados'] as Map<String, dynamic>);

  static Future<void> delete(String id) => ApiClient.delete('${ApiConstants.races}/$id');

  /// Provas cadastradas pelo organizador logado.
  static Future<List<RaceModel>> mine() async {
    final data = await ApiClient.get('${ApiConstants.races}/mine');
    return (data['dados'] as List).map((e) => RaceModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Envia a capa e devolve o caminho para salvar na prova.
  static Future<String> uploadCover(XFile file) async {
    final data = await ApiClient.upload('${ApiConstants.races}/cover', [
      http.MultipartFile.fromBytes(
        'capa',
        await file.readAsBytes(),
        filename: file.name,
        contentType: MediaType.parse(file.mimeType ?? 'image/jpeg'),
      ),
    ]);
    return data['dados'] as String;
  }

  /// Provas favoritadas pelo atleta logado.
  static Future<List<RaceModel>> saved() async {
    final data = await ApiClient.get(ApiConstants.me);
    final user = data['dados'] as Map<String, dynamic>;
    return (user['corridasSalvas'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(RaceModel.fromJson)
        .toList();
  }
}

/// Avisa as telas abertas de que alguma prova foi criada, alterada ou excluída.
class RacesBus extends ChangeNotifier {
  void changed() => notifyListeners();
}
