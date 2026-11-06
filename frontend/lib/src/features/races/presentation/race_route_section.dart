import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/rr_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/rr_button.dart';
import '../../../core/widgets/rr_feedback.dart';
import '../../../core/widgets/rr_layout.dart';
import '../../routes/data/route_model.dart';
import '../../routes/presentation/route_map.dart';
import '../../routes/presentation/route_planner_screen.dart';
import '../data/race_model.dart';

/// Mapa do percurso na tela da prova. Quem gerencia a prova desenha cada
/// distância; os demais só veem a seção se houver algum percurso.
class RaceRouteSection extends StatefulWidget {
  final RaceModel race;
  final bool canManage;

  /// Os testes não baixam mapas da internet.
  final bool showTiles;

  const RaceRouteSection({super.key, required this.race, required this.canManage, this.showTiles = true});

  @override
  State<RaceRouteSection> createState() => _RaceRouteSectionState();
}

class _RaceRouteSectionState extends State<RaceRouteSection> {
  Map<num, RouteDraft> _routes = {};
  bool _loading = true;
  String? _error;
  num? _selected;

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
      final routes = await RaceService.routes(widget.race.id);
      if (mounted) setState(() => _routes = routes);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _draw(RaceDistance distance) => rrPush<bool>(
    context,
    RoutePlannerScreen(
      title: 'Percurso ${distance.label}',
      initial: _routes[distance.km],
      showTiles: widget.showTiles,
      onSave: (draft) async {
        await RaceService.saveRoute(widget.race.id, distance.km, draft);
        if (mounted) setState(() => _routes[distance.km] = draft);
      },
    ),
  );

  Future<void> _remove(RaceDistance distance) async {
    final confirmed = await showRRConfirm(
      context,
      title: 'Remover percurso?',
      text: 'O mapa de ${distance.label} sai da página da prova. Essa ação não pode ser desfeita.',
      confirmLabel: 'Remover',
    );
    if (!confirmed || !mounted) return;
    try {
      await RaceService.removeRoute(widget.race.id, distance.km);
      if (!mounted) return;
      setState(() => _routes.remove(distance.km));
      showRRToast(context, 'Percurso removido.');
    } on ApiException catch (e) {
      if (mounted) showRRToast(context, e.message, error: true);
    }
  }

  Future<void> _export(RaceDistance distance, RouteDraft route) async {
    try {
      await shareRouteGpx('${widget.race.nome} ${distance.label}', route.segments);
    } catch (_) {
      if (mounted) showRRToast(context, 'Não foi possível exportar o arquivo.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    // Sem carregar não dá para saber se já há percurso: nada de botão "desenhar" ainda.
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 20),
        child: RRSkeleton(count: 1, height: 260),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Row(
          children: [
            Expanded(
              child: Text('Não carregamos o percurso. $_error', style: RRType.textS.copyWith(color: c.textSecondary)),
            ),
            RRButton('Tentar de novo', kind: RRButtonKind.ghost, onPressed: _load),
          ],
        ),
      );
    }

    final options = widget.race.distancias.where((d) => widget.canManage || _routes.containsKey(d.km)).toList();
    if (options.isEmpty) return const SizedBox.shrink();
    final distance = options.firstWhere(
      (d) => d.km == _selected,
      // Abre na primeira distância que já tem mapa.
      orElse: () => options.firstWhere((d) => _routes.containsKey(d.km), orElse: () => options.first),
    );
    final route = _routes[distance.km];

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RRSectionHead('Percurso'),
          const SizedBox(height: 8),
          if (options.length > 1) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in options)
                  RRButton(
                    option.label,
                    size: RRButtonSize.s,
                    kind: option.km == distance.km ? RRButtonKind.primary : RRButtonKind.secondary,
                    onPressed: () => setState(() => _selected = option.km),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (route == null)
            Text('${distance.label} ainda não tem percurso.', style: RRType.textM.copyWith(color: c.textSecondary))
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(RRRadius.md),
              child: SizedBox(
                height: 260,
                // Cada distância enquadra o próprio traçado.
                child: RouteMap(
                  key: ValueKey(distance.km),
                  draft: route,
                  interactive: false,
                  showTiles: widget.showTiles,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              [
                '${route.hasStraightSegment ? '~' : ''}${Fmt.km(route.meters / 1000)} KM',
                if (route.ascent > 0) '${route.ascent.round()} M DE SUBIDA',
              ].join(' • '),
              style: RRType.monoS.copyWith(color: c.textSecondary),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (route != null) ...[
                RRButton(
                  'Ampliar mapa',
                  kind: RRButtonKind.secondary,
                  onPressed: () => rrPush(
                    context,
                    RouteMapScreen(
                      title: 'Percurso ${distance.label}',
                      draft: route,
                      showTiles: widget.showTiles,
                    ),
                  ),
                ),
                RRButton(
                  'Baixar GPX',
                  icon: 'baixar',
                  kind: RRButtonKind.secondary,
                  onPressed: () => _export(distance, route),
                ),
              ],
              if (widget.canManage) ...[
                RRButton(
                  route == null ? 'Desenhar percurso' : 'Editar percurso',
                  kind: route == null ? RRButtonKind.primary : RRButtonKind.secondary,
                  onPressed: () => _draw(distance),
                ),
                if (route != null)
                  RRButton('Remover', kind: RRButtonKind.ghost, onPressed: () => _remove(distance)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
