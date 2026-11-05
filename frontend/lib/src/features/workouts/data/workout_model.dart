import '../../../core/constants/api_constants.dart';
import '../../../core/theme/rr_theme.dart';

class AthleteRef {
  final String id, nome;
  final String? avatarUrl, cidade;
  const AthleteRef({required this.id, required this.nome, this.avatarUrl, this.cidade});

  /// Aceita o objeto populado ou apenas o id, que é o que o backend devolve
  /// em algumas respostas.
  factory AthleteRef.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      return AthleteRef(
        id: json['_id'] as String? ?? '',
        nome: json['nome'] as String? ?? 'Atleta',
        avatarUrl: json['avatarUrl'] as String?,
        cidade: json['cidade'] as String?,
      );
    }
    return AthleteRef(id: json?.toString() ?? '', nome: 'Atleta');
  }
}

class WorkoutComment {
  final String id;
  final AthleteRef autor;
  final String texto;
  final DateTime? createdAt;
  const WorkoutComment({required this.id, required this.autor, required this.texto, this.createdAt});

  factory WorkoutComment.fromJson(Map<String, dynamic> json) => WorkoutComment(
    id: json['_id'] as String? ?? '',
    autor: AthleteRef.fromJson(json['autor']),
    texto: json['texto'] as String? ?? '',
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
  );
}

class WorkoutModel {
  /// Valores de `tipoTreino` no backend: (rótulo, tom da etiqueta).
  static const types = <String, (String, RRTone)>{
    'rodagem': ('Rodagem', RRTone.ceu),
    'longao': ('Longão', RRTone.mata),
    'tiro_intervalado': ('Tiro', RRTone.tartan),
    'tempo_run': ('Tempo Run', RRTone.ambar),
    'recuperacao': ('Recuperação', RRTone.neutro),
    'prova': ('Prova', RRTone.carmim),
  };

  /// Valores de `sensacaoEsforco` no backend, do nível 1 ao 5.
  static const efforts = ['muito_facil', 'facil', 'moderado', 'dificil', 'exaustivo'];

  final String id, titulo, descricao, tipoTreino, tempoFormatado, paceMedio, sensacaoEsforco;
  final AthleteRef atleta;
  final double distanciaKm;
  final int duracaoSegundos, altimetria;
  final List<String> fotos;
  final List<String> curtidas;
  final List<WorkoutComment> comentarios;
  final DateTime dataTreino;

  WorkoutModel({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.tipoTreino,
    required this.tempoFormatado,
    required this.paceMedio,
    required this.sensacaoEsforco,
    required this.atleta,
    required this.distanciaKm,
    required this.duracaoSegundos,
    required this.altimetria,
    required this.fotos,
    required this.curtidas,
    required this.comentarios,
    required this.dataTreino,
  });

  factory WorkoutModel.fromJson(Map<String, dynamic> json) => WorkoutModel(
    id: json['_id'] as String? ?? '',
    titulo: json['titulo'] as String? ?? '',
    descricao: json['descricao'] as String? ?? '',
    tipoTreino: json['tipoTreino'] as String? ?? 'rodagem',
    tempoFormatado: json['tempoFormatado'] as String? ?? '',
    paceMedio: json['paceMedio'] as String? ?? '',
    sensacaoEsforco: json['sensacaoEsforco'] as String? ?? 'moderado',
    atleta: AthleteRef.fromJson(json['atleta']),
    distanciaKm: (json['distanciaKm'] as num? ?? 0).toDouble(),
    duracaoSegundos: (json['duracaoSegundos'] as num? ?? 0).toInt(),
    altimetria: (json['altimetria'] as num? ?? 0).toInt(),
    fotos: (json['fotos'] as List? ?? const []).cast<String>(),
    curtidas: (json['curtidas'] as List? ?? const []).map((e) => e.toString()).toList(),
    comentarios: (json['comentarios'] as List? ?? const [])
        .map((e) => WorkoutComment.fromJson(e as Map<String, dynamic>))
        .toList(),
    dataTreino: DateTime.tryParse(json['dataTreino'] as String? ?? '') ?? DateTime.now(),
  );

  /// Fotos com o link completo, prontas para exibir.
  List<String> get photoUrls => fotos.map(ApiConstants.mediaUrl).toList();

  /// Nível de esforço de 1 a 5.
  int get effortLevel {
    final i = efforts.indexOf(sensacaoEsforco);
    return i < 0 ? 3 : i + 1;
  }
}

/// Treinos de um mês, com os totais exibidos no histórico.
class WorkoutMonth {
  final DateTime month;
  final List<WorkoutModel> workouts;
  const WorkoutMonth(this.month, this.workouts);

  double get totalKm => workouts.fold(0, (sum, w) => sum + w.distanciaKm);

  /// Agrupa por mês, do mais recente para o mais antigo.
  static List<WorkoutMonth> group(List<WorkoutModel> workouts) {
    final sorted = [...workouts]..sort((a, b) => b.dataTreino.compareTo(a.dataTreino));
    final months = <WorkoutMonth>[];
    for (final w in sorted) {
      final d = w.dataTreino.toLocal();
      final key = DateTime(d.year, d.month);
      if (months.isEmpty || months.last.month != key) months.add(WorkoutMonth(key, []));
      months.last.workouts.add(w);
    }
    return months;
  }
}

/// Resumo da semana atual (segunda a domingo).
class WeekSummary {
  final double totalKm;
  final int count;
  final List<double> kmByDay;
  const WeekSummary(this.totalKm, this.count, this.kmByDay);

  factory WeekSummary.from(List<WorkoutModel> workouts, [DateTime? now]) {
    final n = now ?? DateTime.now();
    final monday = DateTime(n.year, n.month, n.day).subtract(Duration(days: n.weekday - 1));
    final days = List<double>.filled(7, 0);
    var count = 0;
    for (final w in workouts) {
      final d = w.dataTreino.toLocal();
      final index = DateTime(d.year, d.month, d.day).difference(monday).inDays;
      if (index >= 0 && index < 7) {
        days[index] += w.distanciaKm;
        count++;
      }
    }
    return WeekSummary(days.reduce((a, b) => a + b), count, days);
  }
}
