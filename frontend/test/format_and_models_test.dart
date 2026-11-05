import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/src/core/utils/format.dart';
import 'package:frontend/src/features/auth/data/models/user_model.dart';
import 'package:frontend/src/features/home/data/notification_model.dart';
import 'package:frontend/src/features/news/data/news_model.dart';
import 'package:frontend/src/features/races/data/race_model.dart';
import 'package:frontend/src/features/workouts/data/workout_model.dart';

void main() {
  group('Fmt', () {
    test('formata números em pt-BR', () {
      expect(Fmt.km(18.2), '18,2');
      expect(Fmt.thousands(1284), '1.284');
      expect(Fmt.thousands(212), '212');
      expect(Fmt.decimal('10,5'), 10.5);
      expect(Fmt.decimal('abc'), isNull);
    });

    test('limpa os tempos que vêm do backend', () {
      expect(Fmt.time('00:52:30'), '52:30');
      expect(Fmt.time('01:38:04'), '1:38:04');
      expect(Fmt.time('12:05:00'), '12:05:00');
      expect(Fmt.pace('05:15 min/km'), '5:15');
    });

    test('calcula pace', () {
      expect(Fmt.paceFrom(10, 3000), '5:00');
      expect(Fmt.paceFrom(0, 3000), '--:--');
    });

    test('datas relativas', () {
      final now = DateTime(2026, 11, 5, 12);
      expect(Fmt.relative(DateTime(2026, 11, 5, 6, 12), now), 'Hoje, 06:12');
      expect(Fmt.relative(DateTime(2026, 11, 4, 18, 40), now), 'Ontem, 18:40');
      expect(Fmt.relative(DateTime(2026, 10, 2, 7, 5), now), '02 Out, 07:05');
    });

    test('iniciais', () {
      expect(Fmt.initials('João Pedro'), 'JP');
      expect(Fmt.initials('Marina'), 'M');
      expect(Fmt.initials(''), '?');
    });
  });

  group('WeekSummary', () {
    WorkoutModel workout(DateTime date, double km) =>
        WorkoutModel.fromJson({'_id': '$date', 'distanciaKm': km, 'dataTreino': date.toIso8601String()});

    test('soma só a semana atual, de segunda a domingo', () {
      final thursday = DateTime(2026, 11, 5, 12);
      final week = WeekSummary.from([
        workout(DateTime(2026, 11, 2, 7), 10), // segunda
        workout(DateTime(2026, 11, 5, 7), 5.5), // quinta
        workout(DateTime(2026, 11, 1, 7), 21), // domingo anterior
      ], thursday);
      expect(week.count, 2);
      expect(week.totalKm, 15.5);
      expect(week.kmByDay[0], 10);
      expect(week.kmByDay[3], 5.5);
      expect(week.kmByDay[6], 0);
    });
  });

  group('WorkoutMonth', () {
    WorkoutModel workout(String id, DateTime date, double km) =>
        WorkoutModel.fromJson({'_id': id, 'distanciaKm': km, 'dataTreino': date.toIso8601String()});

    test('agrupa por mês, do mais recente ao mais antigo, com os totais', () {
      final months = WorkoutMonth.group([
        workout('a', DateTime(2026, 9, 30), 5),
        workout('b', DateTime(2026, 11, 2), 10),
        workout('c', DateTime(2026, 11, 20), 2.5),
        workout('d', DateTime(2025, 11, 20), 21),
      ]);
      expect(months.map((m) => m.month), [DateTime(2026, 11), DateTime(2026, 9), DateTime(2025, 11)]);
      expect(months.first.workouts.map((w) => w.id), ['c', 'b']);
      expect(months.first.totalKm, 12.5);
    });

    test('lista vazia não gera meses', () => expect(WorkoutMonth.group([]), isEmpty));
  });

  group('fotos do treino', () {
    test('caminho do backend vira link completo e link externo não muda', () {
      final w = WorkoutModel.fromJson({
        '_id': '1',
        'fotos': ['/uploads/workouts/a.jpg', 'https://cdn.example.com/b.jpg'],
      });
      expect(w.photoUrls.first, endsWith(':3000/uploads/workouts/a.jpg'));
      expect(w.photoUrls.first, isNot(contains('/api/')));
      expect(w.photoUrls.last, 'https://cdn.example.com/b.jpg');
    });

    test('comentário guarda o id usado para excluir', () {
      final c = WorkoutComment.fromJson({'_id': 'c1', 'autor': 'u1', 'texto': 'oi'});
      expect(c.id, 'c1');
      expect(c.autor.id, 'u1');
    });
  });

  group('notificações', () {
    NotificationModel notice(String tipo, dynamic treino) => NotificationModel.fromJson({
      '_id': 'n1',
      'tipo': tipo,
      'autor': {'_id': 'u2', 'nome': 'Marina'},
      'treino': treino,
      'lida': false,
      'createdAt': '2026-11-05T12:00:00.000Z',
    });

    test('lê treino populado e descreve a ação', () {
      final like = notice('curtida', {'_id': 't1', 'titulo': 'Longão'});
      expect(like.treinoId, 't1');
      expect(like.treinoTitulo, 'Longão');
      expect(like.action, 'curtiu seu treino');
      expect(like.autor.nome, 'Marina');
    });

    test('aviso de seguidor não tem treino', () {
      final follow = notice('seguidor', null);
      expect(follow.treinoId, isNull);
      expect(follow.action, 'começou a seguir você');
    });
  });

  group('seguir', () {
    test('quem o atleta segue sobrevive ao armazenamento local', () {
      final fromApi = UserModel.fromJson({
        '_id': 'u',
        'nome': 'João',
        'email': 'j@x.com',
        'seguindo': ['a', 'b'],
      });
      expect(fromApi.seguindo, 2);
      expect(fromApi.seguindoIds, ['a', 'b']);
      final saved = UserModel.fromJson(fromApi.toJson());
      expect(saved.seguindo, 2);
      expect(saved.seguindoIds, ['a', 'b']);
    });

    test('perfil público traz só as contagens', () {
      final public = UserModel.fromJson({'_id': 'u', 'nome': 'Ana', 'seguidores': 12, 'seguindo': 3});
      expect(public.seguidores, 12);
      expect(public.seguindo, 3);
      expect(public.seguindoIds, isEmpty);
    });
  });

  group('modelos', () {
    test('treino aceita atleta populado ou só o id e mapeia o esforço', () {
      final populated = WorkoutModel.fromJson({
        '_id': '1',
        'atleta': {'_id': 'a', 'nome': 'Marina'},
        'sensacaoEsforco': 'dificil',
      });
      expect(populated.atleta.nome, 'Marina');
      expect(populated.effortLevel, 4);
      expect(WorkoutModel.fromJson({'_id': '2', 'atleta': 'abc'}).atleta.id, 'abc');
    });

    test('prova deriva cores, chamada e elevação do status e das distâncias', () {
      final race = RaceModel.fromJson({
        '_id': 'r',
        'nome': 'Corrida da Serra',
        'data': '2026-11-15T09:00:00.000Z',
        'status': 'concluida',
        'horarioLargada': '06:00',
        'local': {'cidade': 'Parauapebas', 'estado': 'PA'},
        'distancias': [
          {'distanciaKm': 5, 'altimetria': 40},
          {'distanciaKm': 21, 'altimetria': 184},
        ],
        'participantesConfirmados': [
          {'_id': 'u1', 'nome': 'Ana'},
          'u2',
        ],
      });
      expect(race.isOver, isTrue);
      expect(race.canConfirm, isFalse);
      expect(race.tone, RaceTone.ceu);
      expect(race.elevation, 184);
      expect(race.distancias.first.label, '5K');
      expect(race.participantes, ['u1', 'u2']);
      expect(race.locationLine, 'Parauapebas, PA • Largada 06:00');
    });

    test('notícia estima a leitura com no mínimo um minuto', () {
      NewsModel news(String content) => NewsModel.fromJson({'_id': 'n', 'conteudo': content});
      expect(news('curta').readingMinutes, 1);
      expect(news(List.filled(450, 'palavra').join(' ')).readingMinutes, 3);
    });

    test('usuário sobrevive à ida e volta do armazenamento local', () {
      final fromApi = UserModel.fromJson({
        '_id': 'u',
        'nome': 'João',
        'email': 'j@x.com',
        'seguidores': ['a', 'b'],
        'seguindo': ['c'],
        'corridasSalvas': [
          {'_id': 'r1'},
          'r2',
        ],
      });
      expect(fromApi.seguidores, 2);
      final saved = UserModel.fromJson(fromApi.toJson());
      expect(saved.seguidores, 2);
      expect(saved.seguindo, 1);
      expect(saved.corridasSalvas, ['r1', 'r2']);
    });
  });
}
