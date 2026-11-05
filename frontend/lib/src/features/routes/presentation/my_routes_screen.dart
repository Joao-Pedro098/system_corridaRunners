import 'package:flutter/material.dart';

import '../../../core/brand/rr_brand.dart';
import '../../../core/motion/rr_motion.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/rr_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/rr_button.dart';
import '../../../core/widgets/rr_feedback.dart';
import '../../../core/widgets/rr_layout.dart';
import '../data/route_model.dart';
import 'route_planner_screen.dart';

/// Aba Rotas: as rotas privadas do corredor e a entrada para planejar uma nova.
class MyRoutesScreen extends StatefulWidget {
  const MyRoutesScreen({super.key});

  @override
  State<MyRoutesScreen> createState() => _MyRoutesScreenState();
}

class _MyRoutesScreenState extends State<MyRoutesScreen> {
  List<RouteSummary> _routes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final routes = await RouteService.mine();
      if (mounted) setState(() => _routes = routes);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open([String? id]) async {
    final saved = await rrPush<bool>(context, RoutePlannerScreen(routeId: id));
    if (saved == true) _load();
  }

  Future<void> _delete(RouteSummary route) async {
    final confirmed = await showRRConfirm(
      context,
      title: 'Excluir rota?',
      text: '"${route.nome}" será apagada. Essa ação não pode ser desfeita.',
      confirmLabel: 'Excluir',
    );
    if (!confirmed || !mounted) return;
    try {
      await RouteService.delete(route.id);
      if (!mounted) return;
      setState(() => _routes = _routes.where((r) => r.id != route.id).toList());
      showRRToast(context, 'Rota excluída.');
    } on ApiException catch (e) {
      if (mounted) showRRToast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    final desktop = RRBreakpoints.isDesktop(context);

    final Widget body;
    if (_loading && _routes.isEmpty) {
      body = const RRSkeleton(count: 3, height: 124);
    } else if (_error != null) {
      body = RRErrorState(message: _error!, onRetry: _load);
    } else if (_routes.isEmpty) {
      body = RREmptyState(
        title: 'Trace sua primeira rota',
        text: 'Toque no mapa para ligar os pontos pelas ruas e veja a distância, a subida e o tempo estimado.',
        actionLabel: 'Planejar rota',
        onAction: _open,
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, route) in _routes.indexed)
            RRReveal(
              key: ValueKey(route.id),
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _RouteRow(route: route, onOpen: () => _open(route.id), onDelete: () => _delete(route)),
              ),
            ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.all(desktop ? 32 : 16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text('MINHAS\nROTAS', style: RRType.displayM.copyWith(color: c.textPrimary)),
              ),
              if (_routes.isNotEmpty) RRButton('Nova rota', icon: 'mais', onPressed: _open),
            ],
          ),
          const SizedBox(height: 8),
          Text('Só você vê as rotas que salva aqui.', style: RRType.textS.copyWith(color: c.textSecondary)),
          const SizedBox(height: 16),
          body,
        ],
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final RouteSummary route;
  final VoidCallback onOpen, onDelete;
  const _RouteRow({required this.route, required this.onOpen, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    final details = [
      '${route.temLinhaReta ? '~' : ''}${Fmt.km(route.distanciaM / 1000)} KM',
      if (route.subidaM > 0) '${route.subidaM} M DE SUBIDA',
    ].join(' • ');
    return RRCard(
      padding: const EdgeInsets.all(12),
      onTap: onOpen,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: RRPalette.tartan500, borderRadius: BorderRadius.circular(RRRadius.md)),
            child: const RRIcon('rota', size: 24, color: RRPalette.cal950),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  route.nome,
                  style: RRType.labelM.copyWith(color: c.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  details,
                  style: RRType.monoS.copyWith(color: c.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          RRIconButton('excluir', tooltip: 'Excluir ${route.nome}', size: 20, onPressed: onDelete),
        ],
      ),
    );
  }
}
