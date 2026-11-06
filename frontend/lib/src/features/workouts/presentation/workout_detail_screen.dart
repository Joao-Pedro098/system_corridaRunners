import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/brand/rr_brand.dart';
import '../../../core/network/api_client.dart';
import '../../../core/motion/rr_motion.dart';
import '../../../core/theme/rr_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/rr_button.dart';
import '../../../core/widgets/rr_feedback.dart';
import '../../../core/widgets/rr_labels.dart';
import '../../../core/widgets/rr_layout.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../data/workout_model.dart';
import 'new_workout_screen.dart';
import 'workout_gallery.dart';
import 'workout_widgets.dart';
import 'workouts_provider.dart';

class WorkoutDetailScreen extends StatefulWidget {
  final WorkoutModel workout;
  final Object? heroTag;
  const WorkoutDetailScreen({super.key, required this.workout, this.heroTag});

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  final _comment = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _comment.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await context.read<WorkoutsProvider>().addComment(widget.workout, text);
      _comment.clear();
    } on ApiException catch (e) {
      if (mounted) showRRToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteComment(WorkoutComment comment) async {
    final workouts = context.read<WorkoutsProvider>();
    final confirmed = await showRRConfirm(
      context,
      title: 'Excluir comentário?',
      text: 'O comentário sai do treino para todo mundo. Essa ação não pode ser desfeita.',
      confirmLabel: 'Excluir',
    );
    if (!confirmed) return;
    try {
      await workouts.deleteComment(widget.workout, comment);
      if (mounted) showRRToast(context, 'Comentário excluído.');
    } on ApiException catch (e) {
      if (mounted) showRRToast(context, e.message, error: true);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showRRConfirm(
      context,
      title: 'Excluir treino?',
      text: 'O treino sai do feed e os seus totais são recalculados. Essa ação não pode ser desfeita.',
      confirmLabel: 'Excluir',
    );
    if (!confirmed || !mounted) return;
    try {
      await context.read<WorkoutsProvider>().delete(widget.workout);
      if (!mounted) return;
      await context.read<AuthProvider>().refreshUser();
      if (!mounted) return;
      showRRToast(context, 'Treino excluído.');
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) showRRToast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    context.watch<WorkoutsProvider>();
    final workout = widget.workout;
    final user = context.select<AuthProvider, String?>((a) => a.user?.id);
    final userType = context.select<AuthProvider, String?>((a) => a.user?.tipo);
    final canDelete = user == workout.atleta.id || userType == 'admin';
    final liked = user != null && workout.curtidas.contains(user);

    return RRSubPage(
      title: 'Treino',
      actions: [
        // O admin modera excluindo, mas só quem correu altera os números do treino.
        if (user == workout.atleta.id)
          RRIconButton(
            'editar',
            tooltip: 'Editar treino',
            onPressed: () => rrPush(context, NewWorkoutScreen(workout: workout)),
          ),
        if (canDelete) RRIconButton('excluir', tooltip: 'Excluir treino', onPressed: _delete),
      ],
      bottom: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _comment,
              maxLength: 500,
              onSubmitted: (_) => _send(),
              style: RRType.textM.copyWith(color: c.textPrimary),
              decoration: const InputDecoration(hintText: 'Escreva um comentário', counterText: ''),
            ),
          ),
          const SizedBox(width: 8),
          RRButton('Enviar', loading: _sending, onPressed: _send),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WorkoutAuthor(workout),
          const SizedBox(height: 16),
          Text(workout.titulo.toUpperCase(), style: RRType.displayS.copyWith(color: c.textPrimary)),
          const SizedBox(height: 16),
          if (workout.photoUrls.isEmpty)
            RouteArt(seed: workout.id, height: 220)
          else
            // Outras fotos recomeçam a galeria, que guarda a posição atual.
            WorkoutGallery(key: ValueKey(workout.fotos.join()), photos: workout.photoUrls, heroTag: widget.heroTag),
          const SizedBox(height: 20),
          WorkoutMetrics(workout),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              RREffort(workout.effortLevel),
              if (workout.altimetria > 0)
                Text('${workout.altimetria} M DE ELEVAÇÃO', style: RRType.monoS.copyWith(color: c.textSecondary)),
            ],
          ),
          if (workout.descricao.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(workout.descricao, style: RRType.textL.copyWith(color: c.textPrimary)),
          ],
          const SizedBox(height: 16),
          RRButton(
            liked ? 'Curtido • ${workout.curtidas.length}' : 'Curtir • ${workout.curtidas.length}',
            kind: RRButtonKind.secondary,
            onPressed: user == null
                ? null
                : () async {
                    try {
                      await context.read<WorkoutsProvider>().toggleLike(workout, user);
                    } on ApiException catch (e) {
                      if (context.mounted) showRRToast(context, e.message, error: true);
                    }
                  },
          ),
          const SizedBox(height: 28),
          RRSectionHead('Comentários (${workout.comentarios.length})'),
          const SizedBox(height: 12),
          if (workout.comentarios.isEmpty)
            Text('Seja a primeira pessoa a comentar.', style: RRType.textM.copyWith(color: c.textSecondary)),
          // Comentários novos entram deslizando e os excluídos fecham o espaço.
          AnimatedSize(
            duration: RRMotion.of(context, RRMotion.base),
            curve: RRMotion.enter,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final comment in workout.comentarios)
                  RRReveal(
                    key: ValueKey(comment.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: c.border)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RRAvatar(comment.autor.nome, url: comment.autor.avatarUrl, size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        comment.autor.nome,
                                        style: RRType.labelS.copyWith(color: c.textPrimary),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (comment.createdAt != null) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        Fmt.relative(comment.createdAt!),
                                        style: RRType.textS.copyWith(color: c.textMuted),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(comment.texto, style: RRType.textM.copyWith(color: c.textPrimary)),
                              ],
                            ),
                          ),
                          // Autor do comentário, dono do treino e admin podem excluir.
                          if (comment.id.isNotEmpty && (canDelete || comment.autor.id == user))
                            RRIconButton(
                              'excluir',
                              tooltip: 'Excluir comentário',
                              size: 18,
                              color: c.textMuted,
                              onPressed: () => _deleteComment(comment),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
