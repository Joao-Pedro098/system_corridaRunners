import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/brand/rr_brand.dart';
import '../../../core/motion/rr_motion.dart';
import '../../../core/theme/rr_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/rr_button.dart';
import '../../../core/widgets/rr_feedback.dart';
import '../../../core/widgets/rr_labels.dart';
import '../../../core/widgets/rr_layout.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../home/presentation/notifications_screen.dart';
import '../../news/data/news_model.dart';
import '../../news/presentation/news_widgets.dart';
import '../../races/data/race_model.dart';
import '../../races/presentation/race_widgets.dart';
import 'new_workout_screen.dart';
import 'workout_widgets.dart';
import 'workouts_provider.dart';

class FeedScreen extends StatelessWidget {
  final VoidCallback onOpenNews;
  final VoidCallback onOpenProfile;
  const FeedScreen({super.key, required this.onOpenNews, required this.onOpenProfile});

  void _publish(BuildContext context) => rrPush(context, const NewWorkoutScreen());

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutsProvider>();
    final user = context.select<AuthProvider, String>((a) => a.user?.nome ?? 'Corredor');

    Widget feedBody(int columns) {
      if (provider.loading && provider.feed.isEmpty) return RRSkeleton(columns: columns, count: columns * 2);
      if (provider.error != null && provider.feed.isEmpty) {
        return RRErrorState(message: provider.error!, onRetry: provider.loadFeed);
      }
      if (provider.feed.isEmpty) {
        return RREmptyState(
          title: 'Sua primeira rota começa aqui',
          text: 'Publique um treino com distância e tempo para aparecer no feed.',
          actionLabel: 'Publicar treino',
          onAction: () => _publish(context),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RRGrid(
            columns: columns,
            gap: columns > 1 ? 20 : 16,
            children: [for (final w in provider.feed) WorkoutCard(w, key: ValueKey(w.id))],
          ),
          if (provider.hasMore) ...[
            const SizedBox(height: 16),
            Center(
              child: RRButton(
                'Carregar mais',
                kind: RRButtonKind.secondary,
                loading: provider.loadingMore,
                onPressed: provider.loadMore,
              ),
            ),
          ],
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, box) {
        // Coluna direita só quando há espaço para ela sem apertar os cartões.
        if (box.maxWidth >= 1000) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: provider.loadFeed,
                  child: ListView(
                    padding: const EdgeInsets.all(32),
                    children: [
                      _DesktopHeader(title: '${Fmt.greeting()}, ${Fmt.firstName(user)}', onAvatar: onOpenProfile),
                      const SizedBox(height: 20),
                      feedBody(2),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 372,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(0, 32, 32, 32),
                  children: [
                    WeekSummaryCard(week: provider.week),
                    const SizedBox(height: 16),
                    const _NextRace(),
                    _Tips(onOpenNews: onOpenNews),
                  ],
                ),
              ),
            ],
          );
        }
        final desktop = RRBreakpoints.isDesktop(context);
        return RefreshIndicator(
          onRefresh: provider.loadFeed,
          child: ListView(
            padding: EdgeInsets.all(desktop ? 32 : 16),
            children: [
              RRCentered(
                maxWidth: 640,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (desktop) ...[
                      _DesktopHeader(title: '${Fmt.greeting()}, ${Fmt.firstName(user)}', onAvatar: onOpenProfile),
                      const SizedBox(height: 20),
                    ],
                    WeekSummaryCard(week: provider.week),
                    const SizedBox(height: 16),
                    const RRSectionHead('Feed de treinos', action: 'Recentes'),
                    const SizedBox(height: 16),
                    feedBody(1),
                    // Espaço para o botão flutuante não cobrir o último cartão.
                    if (!desktop) const SizedBox(height: 72),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DesktopHeader extends StatelessWidget {
  final String title;
  final VoidCallback onAvatar;
  const _DesktopHeader({required this.title, required this.onAvatar});

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    final user = context.watch<AuthProvider>().user;
    return Row(
      children: [
        Expanded(
          child: Text(title.toUpperCase(), style: RRType.displayM.copyWith(color: c.textPrimary)),
        ),
        const NotificationBell(),
        const SizedBox(width: 8),
        InkWell(
          onTap: onAvatar,
          customBorder: const CircleBorder(),
          child: RRAvatar(user?.nome ?? '', url: user?.avatarUrl),
        ),
      ],
    );
  }
}

/// Próxima prova na coluna direita da web.
class _NextRace extends StatefulWidget {
  const _NextRace();

  @override
  State<_NextRace> createState() => _NextRaceState();
}

class _NextRaceState extends State<_NextRace> {
  RaceModel? _race;
  late final RacesBus _bus = context.read<RacesBus>();

  @override
  void initState() {
    super.initState();
    _bus.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _bus.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final races = await RaceService.list();
      final now = DateTime.now();
      final next = races.where((r) => r.data.isAfter(now) && r.status != 'cancelada');
      if (mounted) setState(() => _race = next.isEmpty ? null : next.first);
    } catch (_) {
      // Bloco complementar: sem prova, a coluna apenas não o exibe.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_race == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RRSectionHead('Próxima prova'),
          const SizedBox(height: 16),
          RaceCard(race: _race!, onChanged: (r) => setState(() => _race = r)),
        ],
      ),
    );
  }
}

class _Tips extends StatefulWidget {
  final VoidCallback onOpenNews;
  const _Tips({required this.onOpenNews});

  @override
  State<_Tips> createState() => _TipsState();
}

class _TipsState extends State<_Tips> {
  NewsModel? _news;

  @override
  void initState() {
    super.initState();
    NewsService.list()
        .then((items) {
          if (mounted && items.isNotEmpty) setState(() => _news = items.first);
        })
        .catchError((_) {
          // Bloco complementar: sem notícia, a coluna apenas não o exibe.
        });
  }

  @override
  Widget build(BuildContext context) {
    if (_news == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RRSectionHead('Dicas', action: 'Ver todas', onAction: widget.onOpenNews),
        const SizedBox(height: 16),
        NewsCard(news: _news!),
      ],
    );
  }
}

/// Botão flutuante de publicar treino (mobile).
class PublishFab extends StatelessWidget {
  const PublishFab({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    return Tooltip(
      message: 'Publicar treino',
      child: RRPressable(
        pressedScale: .9,
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(RRRadius.md), boxShadow: RRShadow.e2),
          child: Material(
            color: c.accent,
            borderRadius: BorderRadius.circular(RRRadius.md),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => rrPush(context, const NewWorkoutScreen()),
              child: SizedBox(
                width: 56,
                height: 56,
                child: Center(child: RRIcon('mais', color: c.onAccent)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
