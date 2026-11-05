import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../../../../core/brand/rr_brand.dart';
import '../../../../core/motion/rr_motion.dart';
import '../../../../core/theme/rr_theme.dart';
import '../../../../core/widgets/rr_button.dart';
import '../../../../core/widgets/rr_labels.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../news/presentation/news_screen.dart';
import '../../../profile/presentation/profile_screen.dart';
import '../../../races/presentation/events_screen.dart';
import '../../../routes/presentation/my_routes_screen.dart';
import '../../../workouts/presentation/feed_screen.dart';
import '../../../workouts/presentation/new_workout_screen.dart';
import '../../../workouts/presentation/workouts_provider.dart';
import '../../data/notification_model.dart';
import '../notifications_screen.dart';

const _destinations = [
  ('Comunidade', 'comunidade'),
  ('Eventos', 'calendario'),
  ('Notícias', 'noticias'),
  ('Rotas', 'rota'),
  ('Perfil', 'perfil'),
];

/// Posição da aba Perfil em [_destinations].
const _profileTab = 4;

/// Área logada: barra inferior no mobile e barra lateral na web.
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final _tab = ValueNotifier<int>(0);
  // A chave preserva o estado das abas se a janela cruzar o ponto de quebra.
  final _tabsKey = GlobalKey();
  final _desktopNavigator = GlobalKey<NavigatorState>();
  // Navegadores internos precisam do próprio controlador de Hero.
  final _heroController = MaterialApp.createMaterialHeroController();
  bool _fabVisible = true;
  NotificationsProvider? _notifications;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final workouts = context.read<WorkoutsProvider>();
      workouts.loadFeed();
      final id = context.read<AuthProvider>().user?.id;
      if (id != null) workouts.loadMine(id);
      _notifications = context.read<NotificationsProvider>()..startPolling();
    });
  }

  @override
  void dispose() {
    _notifications?.stopPolling();
    _tab.dispose();
    super.dispose();
  }

  void _select(int index) {
    _tab.value = index;
    _fabVisible = true;
    // Na web, trocar de destino fecha telas internas abertas.
    _desktopNavigator.currentState?.popUntil((route) => route.isFirst);
  }

  Widget _tabs() => _Tabs(key: _tabsKey, tab: _tab, onOpenNews: () => _select(2), onOpenProfile: () => _select(_profileTab));

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    if (RRBreakpoints.isDesktop(context)) {
      return Scaffold(
        backgroundColor: c.canvas,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ValueListenableBuilder<int>(
              valueListenable: _tab,
              builder: (_, active, _) => _Sidebar(
                active: active,
                onSelect: _select,
                onPublish: () => _desktopNavigator.currentState?.push(
                  RRPageRoute(builder: (_) => const NewWorkoutScreen(), instant: RRMotion.reduced(context)),
                ),
              ),
            ),
            Expanded(
              child: HeroControllerScope(
                controller: _heroController,
                child: Navigator(
                  key: _desktopNavigator,
                  onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => _tabs()),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable: _tab,
      builder: (context, active, child) => Scaffold(
        backgroundColor: c.canvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(onAvatar: () => _select(_profileTab)),
              Expanded(
                // Ao rolar para baixo o botão sai da frente do conteúdo.
                child: NotificationListener<UserScrollNotification>(
                  onNotification: (n) {
                    final visible = n.direction == ScrollDirection.idle
                        ? _fabVisible
                        : n.direction == ScrollDirection.forward;
                    if (visible != _fabVisible && n.metrics.axis == Axis.vertical) {
                      setState(() => _fabVisible = visible);
                    }
                    return false;
                  },
                  child: Stack(
                    children: [
                      Positioned.fill(child: child!),
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: AnimatedScale(
                          scale: active == 0 && _fabVisible ? 1 : 0,
                          duration: RRMotion.of(context, RRMotion.base),
                          curve: active == 0 && _fabVisible ? RRMotion.pop : Curves.easeIn,
                          child: IgnorePointer(ignoring: active != 0 || !_fabVisible, child: const PublishFab()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _BottomBar(active: active, onSelect: _select),
      ),
      child: _tabs(),
    );
  }
}

class _Tabs extends StatefulWidget {
  final ValueNotifier<int> tab;
  final VoidCallback onOpenNews, onOpenProfile;
  const _Tabs({super.key, required this.tab, required this.onOpenNews, required this.onOpenProfile});

  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> with SingleTickerProviderStateMixin {
  late final _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 220), value: 1);
  late final _opacity = CurvedAnimation(parent: _fade, curve: RRMotion.enter);

  @override
  void initState() {
    super.initState();
    widget.tab.addListener(_onTab);
  }

  void _onTab() {
    if (RRMotion.reduced(context)) return;
    _fade.forward(from: .25);
  }

  @override
  void dispose() {
    widget.tab.removeListener(_onTab);
    _opacity.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.rr.canvas,
    child: FadeTransition(
      opacity: _opacity,
      child: ValueListenableBuilder<int>(
        valueListenable: widget.tab,
        builder: (_, active, _) => IndexedStack(
          index: active,
          children: [
            FeedScreen(onOpenNews: widget.onOpenNews, onOpenProfile: widget.onOpenProfile),
            const EventsScreen(),
            const NewsScreen(),
            const MyRoutesScreen(),
            const ProfileScreen(),
          ],
        ),
      ),
    ),
  );
}

class _TopBar extends StatelessWidget {
  final VoidCallback onAvatar;
  const _TopBar({required this.onAvatar});

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    final user = context.watch<AuthProvider>().user;
    return Container(
      height: 60,
      padding: const EdgeInsets.only(left: 16, right: 12),
      color: c.surface,
      child: Row(
        children: [
          const RRLockup(height: 24),
          const Spacer(),
          const NotificationBell(),
          const SizedBox(width: 4),
          Tooltip(
            message: 'Perfil',
            child: InkWell(
              onTap: onAvatar,
              customBorder: const CircleBorder(),
              child: RRAvatar(user?.nome ?? '', url: user?.avatarUrl, size: 32),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int active;
  final ValueChanged<int> onSelect;
  const _BottomBar({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    return Container(
      color: c.surface,
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      child: SizedBox(
        height: 76,
        child: Stack(
          children: [
            Positioned.fill(
              child: Row(
                children: [
                  for (var i = 0; i < _destinations.length; i++)
                    Expanded(
                      child: Semantics(
                        selected: i == active,
                        button: true,
                        child: InkWell(
                          onTap: () => onSelect(i),
                          child: Column(
                            children: [
                              const SizedBox(height: 15),
                              AnimatedScale(
                                scale: i == active ? 1.14 : 1,
                                duration: RRMotion.of(context, RRMotion.base),
                                curve: RRMotion.pop,
                                child: RRIcon(
                                  _destinations[i].$2,
                                  size: 22,
                                  color: i == active ? c.textPrimary : c.textMuted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              AnimatedDefaultTextStyle(
                                duration: RRMotion.of(context, RRMotion.base),
                                style: (i == active ? RRType.labelS : RRType.textS).copyWith(
                                  color: i == active ? c.textPrimary : c.textSecondary,
                                ),
                                child: Text(_destinations[i].$1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // O traço Tartan corre até o destino ativo, como numa raia.
            AnimatedAlign(
              duration: RRMotion.of(context, RRMotion.slow),
              curve: RRMotion.enter,
              alignment: Alignment(-1 + 2 * active / (_destinations.length - 1), -1),
              child: FractionallySizedBox(
                widthFactor: 1 / _destinations.length,
                child: Center(heightFactor: 1, child: Container(width: 32, height: 3, color: c.accent)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final int active;
  final ValueChanged<int> onSelect;
  final VoidCallback onPublish;
  const _Sidebar({required this.active, required this.onSelect, required this.onPublish});

  @override
  Widget build(BuildContext context) => Container(
    width: 256,
    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
    color: RRPalette.cal950,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(8, 0, 8, 32),
          child: Align(
            alignment: Alignment.centerLeft,
            child: RRLockup(height: 26, symbolColor: RRPalette.tartan500, wordColor: RRPalette.cal50),
          ),
        ),
        // A faixa de destaque desliza entre os destinos.
        Stack(
          children: [
            AnimatedPositioned(
              duration: RRMotion.of(context, RRMotion.slow),
              curve: RRMotion.enter,
              top: active * 48.0,
              left: 0,
              right: 0,
              height: 44,
              child: DecoratedBox(
                decoration: BoxDecoration(color: RRPalette.cal800, borderRadius: BorderRadius.circular(RRRadius.md)),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < _destinations.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Semantics(
                      selected: i == active,
                      button: true,
                      child: Material(
                        type: MaterialType.transparency,
                        borderRadius: BorderRadius.circular(RRRadius.md),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => onSelect(i),
                          hoverColor: i == active ? Colors.transparent : RRPalette.cal900,
                          highlightColor: RRPalette.cal50.withValues(alpha: .06),
                          splashColor: RRPalette.cal50.withValues(alpha: .1),
                          child: SizedBox(
                            height: 44,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                children: [
                                  RRIcon(
                                    _destinations[i].$2,
                                    size: 22,
                                    color: i == active ? RRPalette.tartan400 : RRPalette.cal400,
                                  ),
                                  const SizedBox(width: 12),
                                  AnimatedDefaultTextStyle(
                                    duration: RRMotion.of(context, RRMotion.base),
                                    style: RRType.labelM.copyWith(
                                      color: i == active ? RRPalette.cal50 : RRPalette.cal300,
                                    ),
                                    child: Text(_destinations[i].$1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 20),
        RRButton('Publicar treino', kind: RRButtonKind.accent, expand: true, onPressed: onPublish),
      ],
    ),
  );
}
