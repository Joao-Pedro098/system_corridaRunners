import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/brand/rr_brand.dart';
import '../../../core/motion/rr_motion.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/rr_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/rr_button.dart';
import '../../../core/widgets/rr_feedback.dart';
import '../../../core/widgets/rr_labels.dart';
import '../../../core/widgets/rr_layout.dart';
import '../../profile/presentation/athlete_screen.dart';
import '../../workouts/presentation/workout_detail_screen.dart';
import '../../workouts/presentation/workouts_provider.dart';
import '../data/notification_model.dart';

/// Sino com a contagem de não lidas, usado na barra do celular e na web.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    final unread = context.select<NotificationsProvider, int>((p) => p.unread);
    return Semantics(
      label: unread == 0 ? 'Notificações' : 'Notificações, $unread não lidas',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          RRIconButton(
            'notificacao',
            tooltip: 'Notificações',
            onPressed: () => rrPush(context, const NotificationsScreen()),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: IgnorePointer(
              child: AnimatedScale(
                scale: unread > 0 ? 1 : 0,
                duration: RRMotion.of(context, RRMotion.base),
                curve: unread > 0 ? RRMotion.pop : Curves.easeIn,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(RRRadius.full)),
                  alignment: Alignment.center,
                  child: ExcludeSemantics(
                    child: Text(
                      unread > 9 ? '9+' : '$unread',
                      style: RRType.labelS.copyWith(color: c.onAccent, fontSize: 11, height: 1),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationsProvider>().open();
    });
  }

  Future<void> _open(NotificationModel notification) async {
    if (notification.treinoId == null) {
      await rrPush(context, AthleteScreen(userId: notification.autor.id));
      return;
    }
    try {
      final workout = await WorkoutsProvider.byId(notification.treinoId!);
      if (mounted) await rrPush(context, WorkoutDetailScreen(workout: workout));
    } on ApiException catch (e) {
      if (mounted) showRRToast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationsProvider>();
    final Widget body;
    if (provider.loading && provider.items.isEmpty) {
      body = const RRSkeleton(count: 4, height: 96);
    } else if (provider.error != null) {
      body = RRErrorState(message: provider.error!, onRetry: provider.open);
    } else if (provider.items.isEmpty) {
      body = const RREmptyState(title: 'Tudo em dia', text: 'Curtidas, comentários e novos seguidores aparecem aqui.');
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, notification) in provider.items.indexed)
            RRReveal(
              key: ValueKey(notification.id),
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _NotificationRow(notification, onTap: () => _open(notification)),
              ),
            ),
        ],
      );
    }
    return RRSubPage(title: 'Notificações', child: body);
  }
}

class _NotificationRow extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;
  const _NotificationRow(this.notification, {required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    final title = notification.treinoTitulo;
    return RRCard(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          RRAvatar(notification.autor.nome, url: notification.autor.avatarUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: notification.autor.nome,
                        style: RRType.labelM.copyWith(color: c.textPrimary),
                      ),
                      TextSpan(
                        text: ' ${notification.action}',
                        style: RRType.textM.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (title != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: RRType.textS.copyWith(color: c.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  Fmt.relative(notification.createdAt).toUpperCase(),
                  style: RRType.monoS.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
          if (!notification.lida) ...[
            const SizedBox(width: 8),
            Semantics(
              label: 'Nova',
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
              ),
            ),
          ],
          const SizedBox(width: 4),
          RRIcon('avancar', size: 18, color: c.textMuted),
        ],
      ),
    );
  }
}
