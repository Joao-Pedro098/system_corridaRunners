import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/rr_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/rr_button.dart';
import '../../../core/widgets/rr_feedback.dart';
import '../../../core/widgets/rr_layout.dart';
import '../../routes/data/route_model.dart';
import '../../routes/presentation/route_map.dart';
import '../data/workout_model.dart';
import 'workouts_provider.dart';

/// Mapa da rota publicada com o treino. Sem rota, não aparece.
class WorkoutRouteSection extends StatefulWidget {
  final WorkoutModel workout;

  /// Os testes não baixam mapas da internet.
  final bool showTiles;

  const WorkoutRouteSection({super.key, required this.workout, this.showTiles = true});

  @override
  State<WorkoutRouteSection> createState() => _WorkoutRouteSectionState();
}

class _WorkoutRouteSectionState extends State<WorkoutRouteSection> {
  RouteDraft? _route;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.workout.rota != null) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final route = await WorkoutsProvider.fullRoute(widget.workout.id);
      if (mounted) setState(() => _route = route);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _export(WorkoutRoute info, RouteDraft route) async {
    try {
      await shareRouteGpx(info.nome, route.segments);
    } catch (_) {
      if (mounted) showRRToast(context, 'Não foi possível exportar o arquivo.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    final info = widget.workout.rota;
    if (info == null) return const SizedBox.shrink();

    final Widget content;
    if (_loading) {
      content = const RRSkeleton(count: 1, height: 240);
    } else if (_error != null || _route == null) {
      content = Row(
        children: [
          Expanded(
            child: Text(
              'Não carregamos a rota. ${_error ?? ''}',
              style: RRType.textS.copyWith(color: c.textSecondary),
            ),
          ),
          RRButton('Tentar de novo', kind: RRButtonKind.ghost, onPressed: _load),
        ],
      );
    } else {
      final route = _route!;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(RRRadius.md),
            child: SizedBox(
              height: 240,
              child: RouteMap(draft: route, interactive: false, showTiles: widget.showTiles),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            [
              '${info.temLinhaReta ? '~' : ''}${Fmt.km(info.distanciaM / 1000)} KM',
              if (info.subidaM > 0) '${info.subidaM} M DE SUBIDA',
            ].join(' • '),
            style: RRType.monoS.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              RRButton(
                'Ampliar mapa',
                kind: RRButtonKind.secondary,
                onPressed: () => rrPush(
                  context,
                  RouteMapScreen(title: info.nome, draft: route, showTiles: widget.showTiles),
                ),
              ),
              RRButton(
                'Baixar GPX',
                icon: 'baixar',
                kind: RRButtonKind.secondary,
                onPressed: () => _export(info, route),
              ),
            ],
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RRSectionHead('Rota: ${info.nome}'),
          const SizedBox(height: 8),
          content,
        ],
      ),
    );
  }
}
