import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/brand/rr_brand.dart';
import '../../../core/motion/rr_motion.dart';
import '../../../core/theme/rr_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/rr_feedback.dart';
import '../../../core/widgets/rr_labels.dart';
import '../../../core/widgets/rr_layout.dart';
import '../../../core/network/api_client.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../profile/presentation/athlete_screen.dart';
import '../data/workout_model.dart';
import 'workout_detail_screen.dart';
import 'workout_gallery.dart';
import 'workouts_provider.dart';

/// Resumo da semana: bloco sempre em Asfalto, nos dois temas.
class WeekSummaryCard extends StatelessWidget {
  final WeekSummary week;
  const WeekSummaryCard({super.key, required this.week});

  @override
  Widget build(BuildContext context) {
    const days = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];
    final maxKm = week.kmByDay.reduce((a, b) => a > b ? a : b);
    final label = week.count == 1 ? '1 treino' : '${week.count} treinos';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RRPalette.cal950,
        borderRadius: BorderRadius.circular(RRRadius.lg),
        border: Border.all(color: RRPalette.cal800),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('SUA SEMANA', style: RRType.monoS.copyWith(color: RRPalette.cal300)),
              Text(label.toUpperCase(), style: RRType.monoS.copyWith(color: RRPalette.cal300)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: RRCountUp(
                    value: week.totalKm,
                    builder: (_, km) => Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: Fmt.km(km),
                            style: RRType.dataXL.copyWith(color: RRPalette.cal50),
                          ),
                          TextSpan(
                            text: ' KM',
                            style: RRType.titleM.copyWith(color: RRPalette.tartan500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Semantics(
                label: 'Quilômetros por dia da semana',
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < 7; i++)
                      Padding(
                        padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // As barras crescem em sequência, de segunda a domingo.
                            TweenAnimationBuilder<double>(
                              tween: Tween(
                                begin: RRMotion.reduced(context) ? null : 4,
                                end: week.kmByDay[i] > 0 ? 8 + 36 * week.kmByDay[i] / maxKm : 4,
                              ),
                              duration: RRMotion.of(context, Duration(milliseconds: 420 + 60 * i)),
                              curve: RRMotion.enter,
                              builder: (_, height, _) => Container(
                                width: 8,
                                height: height,
                                color: week.kmByDay[i] > 0 ? RRPalette.tartan500 : RRPalette.cal700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(days[i], style: RRType.monoS.copyWith(color: RRPalette.cal400)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String value, label;
  final String? unit;
  const _Metric(this.value, this.label, [this.unit]);

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: RRType.dataM.copyWith(color: c.textPrimary),
                ),
                if (unit != null)
                  TextSpan(
                    text: ' ${unit!.toUpperCase()}',
                    style: RRType.monoS.copyWith(color: c.textSecondary),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label.toUpperCase(), style: RRType.monoS.copyWith(color: c.textMuted)),
      ],
    );
  }
}

/// Primeira foto do treino com a contagem, ou a arte de percurso sem fotos.
class WorkoutCover extends StatelessWidget {
  final WorkoutModel workout;
  final double height;
  final Object? heroTag;
  const WorkoutCover(this.workout, {super.key, this.height = 136, this.heroTag});

  @override
  Widget build(BuildContext context) {
    final art = RouteArt(points: workout.rota?.resumo, height: height);
    final photos = workout.photoUrls;
    if (photos.isEmpty) return art;
    return ClipRRect(
      borderRadius: BorderRadius.circular(RRRadius.md),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            heroTag == null
                ? Image.network(photos.first, fit: BoxFit.cover, errorBuilder: (_, _, _) => art)
                : Hero(
                    tag: heroTag!,
                    child: Image.network(photos.first, fit: BoxFit.cover, errorBuilder: (_, _, _) => art),
                  ),
            if (photos.length > 1)
              Positioned(
                right: 8,
                bottom: 8,
                child: PhotoBadge(icon: 'foto', label: '${photos.length}'),
              ),
          ],
        ),
      ),
    );
  }
}

class WorkoutMetrics extends StatelessWidget {
  final WorkoutModel workout;
  const WorkoutMetrics(this.workout, {super.key});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: _Metric(Fmt.km(workout.distanciaKm), 'Distância', 'km')),
      const SizedBox(width: 8),
      Expanded(child: _Metric(Fmt.time(workout.tempoFormatado), 'Tempo')),
      const SizedBox(width: 8),
      Expanded(child: _Metric(Fmt.pace(workout.paceMedio), 'Pace', '/km')),
    ],
  );
}

class WorkoutAuthor extends StatelessWidget {
  final WorkoutModel workout;
  const WorkoutAuthor(this.workout, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    final type = WorkoutModel.types[workout.tipoTreino] ?? WorkoutModel.types['rodagem']!;
    final city = workout.atleta.cidade;
    final meta = Fmt.relative(workout.dataTreino) + (city == null || city.isEmpty ? '' : ' • $city');
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: workout.atleta.id.isEmpty ? null : () => rrPush(context, AthleteScreen(userId: workout.atleta.id)),
            child: Row(
              children: [
                RRAvatar(workout.atleta.nome, url: workout.atleta.avatarUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workout.atleta.nome,
                        style: RRType.labelM.copyWith(color: c.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        meta,
                        style: RRType.textS.copyWith(color: c.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        RRTag(type.$1, tone: type.$2),
      ],
    );
  }
}

class WorkoutCard extends StatefulWidget {
  final WorkoutModel workout;
  const WorkoutCard(this.workout, {super.key});

  @override
  State<WorkoutCard> createState() => _WorkoutCardState();
}

class _WorkoutCardState extends State<WorkoutCard> {
  // Identidade única por cartão: o mesmo treino pode aparecer em várias listas.
  final _heroTag = Object();

  @override
  Widget build(BuildContext context) {
    final workout = widget.workout;
    final c = context.rr;
    final userId = context.select<AuthProvider, String?>((a) => a.user?.id);
    final liked = userId != null && workout.curtidas.contains(userId);
    void open() => rrPush(context, WorkoutDetailScreen(workout: workout, heroTag: _heroTag));

    return RRCard(
      onTap: open,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WorkoutAuthor(workout),
          const SizedBox(height: 12),
          Text(workout.titulo, style: RRType.titleS.copyWith(color: c.textPrimary)),
          const SizedBox(height: 12),
          WorkoutCover(workout, heroTag: _heroTag),
          const SizedBox(height: 16),
          WorkoutMetrics(workout),
          const SizedBox(height: 8),
          Row(
            children: [
              RREffort(workout.effortLevel),
              const Spacer(),
              _LikeAction(
                value: workout.curtidas.length,
                liked: liked,
                onTap: userId == null
                    ? null
                    : () async {
                        try {
                          await context.read<WorkoutsProvider>().toggleLike(workout, userId);
                        } on ApiException catch (e) {
                          if (context.mounted) showRRToast(context, e.message, error: true);
                        }
                      },
              ),
              _Action(
                icon: 'comentar',
                value: workout.comentarios.length,
                color: c.textSecondary,
                tooltip: 'Comentar',
                onTap: open,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Contador que troca de número deslizando.
class _RollingCount extends StatelessWidget {
  final int value;
  final Color color;
  const _RollingCount(this.value, this.color);

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: RRMotion.of(context, RRMotion.base),
    switchInCurve: RRMotion.enter,
    transitionBuilder: (child, animation) => ClipRect(
      child: SlideTransition(
        position: Tween(begin: const Offset(0, .7), end: Offset.zero).animate(animation),
        child: FadeTransition(opacity: animation, child: child),
      ),
    ),
    child: Text(
      '$value',
      key: ValueKey(value),
      style: RRType.labelS.copyWith(color: color),
    ),
  );
}

/// Curtida: o coração pula e solta faíscas só no momento de curtir.
class _LikeAction extends StatefulWidget {
  final int value;
  final bool liked;
  final VoidCallback? onTap;
  const _LikeAction({required this.value, required this.liked, required this.onTap});

  @override
  State<_LikeAction> createState() => _LikeActionState();
}

class _LikeActionState extends State<_LikeAction> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));

  void _tap() {
    if (!widget.liked) {
      HapticFeedback.lightImpact();
      if (!RRMotion.reduced(context)) _controller.forward(from: 0);
    }
    widget.onTap?.call();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    final color = widget.liked ? c.accent : c.textSecondary;
    return Tooltip(
      message: widget.liked ? 'Remover curtida' : 'Curtir',
      child: RRPressable(
        pressedScale: .9,
        enabled: widget.onTap != null,
        child: InkWell(
          onTap: widget.onTap == null ? null : _tap,
          borderRadius: BorderRadius.circular(RRRadius.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 6),
                SizedBox.square(
                  dimension: 20,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (_, _) {
                      final t = _controller.value;
                      final pop = 1 + .45 * math.sin(math.min(t * 1.6, 1) * math.pi);
                      return CustomPaint(
                        painter: _controller.isAnimating ? _SparksPainter(t, c.accent) : null,
                        child: Transform.scale(
                          scale: pop,
                          child: RRIcon('curtir', size: 20, color: color, filled: widget.liked),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 4),
                _RollingCount(widget.value, color),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SparksPainter extends CustomPainter {
  final double t;
  final Color color;
  const _SparksPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final eased = Curves.easeOut.transform(t);
    final paint = Paint()
      ..color = color.withValues(alpha: 1 - t)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2;
    for (var i = 0; i < 7; i++) {
      final a = i / 7 * math.pi * 2 - math.pi / 2;
      final from = 10 + 8 * eased, to = from + 5 * (1 - t);
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(center + dir * from, center + dir * to, paint);
    }
  }

  @override
  bool shouldRepaint(_SparksPainter old) => old.t != t;
}

class _Action extends StatelessWidget {
  final String icon, tooltip;
  final int value;
  final Color color;
  final VoidCallback? onTap;
  const _Action({
    required this.icon,
    required this.value,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RRRadius.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 6),
            RRIcon(icon, size: 20, color: color),
            const SizedBox(width: 4),
            _RollingCount(value, color),
            const SizedBox(width: 6),
          ],
        ),
      ),
    ),
  );
}
