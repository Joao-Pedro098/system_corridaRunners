import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/brand/rr_brand.dart';
import '../../../core/motion/rr_motion.dart';
import '../../../core/theme/rr_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/rr_feedback.dart';
import '../../../core/widgets/rr_labels.dart';
import '../../../core/widgets/rr_layout.dart';
import '../data/workout_model.dart';
import 'workout_detail_screen.dart';
import 'workouts_provider.dart';

/// Histórico completo, agrupado por mês. Sem [workouts], mostra os do atleta logado.
class WorkoutHistoryScreen extends StatelessWidget {
  final String title;
  final List<WorkoutModel>? workouts;
  const WorkoutHistoryScreen({super.key, required this.title, this.workouts});

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    final provider = context.watch<WorkoutsProvider>();
    final visible = (workouts ?? provider.mine).where((w) => !provider.isDeleted(w.id)).toList();
    final months = WorkoutMonth.group(visible);

    return RRSubPage(
      title: title,
      child: months.isEmpty
          ? const RREmptyState(title: 'Nenhum treino ainda', text: 'Os treinos publicados aparecem aqui.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final month in months) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          '${Fmt.months[month.month.month - 1]} ${month.month.year}'.toUpperCase(),
                          style: RRType.titleL.copyWith(color: c.textPrimary),
                        ),
                      ),
                      Text(
                        '${month.workouts.length} ${month.workouts.length == 1 ? 'TREINO' : 'TREINOS'} • ${Fmt.km(month.totalKm)} KM',
                        style: RRType.monoS.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final (i, workout) in month.workouts.indexed) ...[
                    RRReveal(key: ValueKey(workout.id), index: i, child: _HistoryRow(workout)),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 20),
                ],
              ],
            ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final WorkoutModel workout;
  const _HistoryRow(this.workout);

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    final type = WorkoutModel.types[workout.tipoTreino] ?? WorkoutModel.types['rodagem']!;
    final art = RouteArt(seed: workout.id, height: 72);
    final photos = workout.photoUrls;
    return RRCard(
      padding: const EdgeInsets.all(12),
      onTap: () => rrPush(context, WorkoutDetailScreen(workout: workout)),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: photos.isEmpty
                ? art
                : ClipRRect(
                    borderRadius: BorderRadius.circular(RRRadius.md),
                    child: Image.network(photos.first, fit: BoxFit.cover, errorBuilder: (_, _, _) => art),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        Fmt.relative(workout.dataTreino),
                        style: RRType.textS.copyWith(color: c.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    RRTag(type.$1, tone: type.$2),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  workout.titulo,
                  style: RRType.labelM.copyWith(color: c.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${Fmt.km(workout.distanciaKm)} KM • ${Fmt.time(workout.tempoFormatado)} • ${Fmt.pace(workout.paceMedio)} /KM',
                  style: RRType.monoS.copyWith(color: c.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
