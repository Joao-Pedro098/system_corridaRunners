import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/rr_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/rr_button.dart';
import '../../../core/widgets/rr_feedback.dart';
import '../../../core/widgets/rr_field.dart';
import '../../../core/widgets/rr_layout.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../data/route_model.dart';
import 'route_map.dart';

/// Parauapebas, enquanto o corredor não pede a própria localização.
const _defaultCenter = LatLng(-6.0675, -49.9020);
const _defaultPaceSeconds = 360;

/// Ritmo médio dos treinos da pessoa, quando ele parece plausível, em segundos por km.
int routePaceSeconds(Map<String, dynamic>? stats) {
  final km = (stats?['totalKm'] as num?)?.toDouble() ?? 0;
  final seconds = (stats?['tempoTotalSegundos'] as num?)?.toDouble() ?? 0;
  if (km <= 0 || seconds <= 0) return _defaultPaceSeconds;
  final pace = seconds / km;
  return pace >= 180 && pace <= 1200 ? pace.round() : _defaultPaceSeconds;
}

String routeDuration(int seconds) {
  final minutes = (seconds / 60).round();
  if (minutes < 60) return '$minutes min';
  return '${minutes ~/ 60}h ${(minutes % 60).toString().padLeft(2, '0')}';
}

/// Mapa para traçar uma rota: cada toque liga um novo ponto pelas ruas.
class RoutePlannerScreen extends StatefulWidget {
  /// Rota salva para abrir; sem ela, começa uma nova.
  final String? routeId;

  /// Os testes não baixam mapas da internet.
  final bool showTiles;

  /// Desenho do percurso de uma prova: quem abre decide como salvar,
  /// sem pedir nome. O planejador já começa em [initial] e mostra [title].
  final String? title;
  final RouteDraft? initial;
  final Future<void> Function(RouteDraft draft)? onSave;

  const RoutePlannerScreen({super.key, this.routeId, this.showTiles = true, this.title, this.initial, this.onSave});

  @override
  State<RoutePlannerScreen> createState() => _RoutePlannerScreenState();
}

class _RoutePlannerScreenState extends State<RoutePlannerScreen> {
  final _map = MapController();
  late RouteDraft _draft = widget.initial?.copy() ?? RouteDraft();
  late String? _name = widget.title;
  String? _loadError, _lastWarning;
  LatLng? _me;

  /// Pontos tocados que ainda esperam o trecho: os toques são atendidos em ordem.
  final _pending = <LatLng>[];
  Future<void> _queue = Future.value();
  bool _loading = false, _saving = false, _locating = false, _dirty = false;

  @override
  void initState() {
    super.initState();
    if (widget.routeId != null) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final route = await RouteService.get(widget.routeId!);
      if (!mounted) return;
      setState(() {
        _draft = route.draft;
        _name = route.nome;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _tap(LatLng point) {
    if (_draft.points.length + _pending.length >= RouteDraft.maxPoints) {
      showRRToast(context, 'A rota pode ter até ${RouteDraft.maxPoints} pontos.', error: true);
      return;
    }
    if (_draft.isEmpty && _pending.isEmpty) {
      setState(() {
        _draft.start(point);
        _dirty = true;
      });
      return;
    }
    setState(() => _pending.add(point));
    _queue = _queue.then((_) => _route(point));
  }

  Future<void> _route(LatLng to) async {
    final from = _draft.points.last;
    RouteSegment segment;
    try {
      segment = await RouteService.segment(from, to);
    } on ApiException catch (e) {
      segment = RouteSegment.straightLine(from, to);
      if (mounted && e.message != _lastWarning) {
        _lastWarning = e.message;
        showRRToast(context, 'Trecho em linha reta. ${e.message}', error: true);
      }
    }
    if (!mounted) return;
    setState(() {
      _pending.removeAt(0);
      _draft.addSegment(to, segment);
      _dirty = true;
    });
  }

  bool get _busy => _pending.isNotEmpty;

  void _undo() => setState(() {
    _draft.undo();
    _dirty = true;
  });

  Future<void> _clear() async {
    final confirmed = await showRRConfirm(
      context,
      title: 'Limpar a rota?',
      text: 'Todos os pontos marcados serão apagados do mapa.',
      confirmLabel: 'Limpar',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _draft.clear();
      _dirty = true;
    });
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) showRRToast(context, 'Sem permissão para usar sua localização.', error: true);
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(timeLimit: Duration(seconds: 10)),
      );
      if (!mounted) return;
      final point = LatLng(position.latitude, position.longitude);
      setState(() => _me = point);
      _map.move(point, 15);
    } catch (_) {
      if (mounted) showRRToast(context, 'Não foi possível encontrar sua localização.', error: true);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _export() async {
    final name = _name ?? 'Rota RunnersRun';
    try {
      await shareRouteGpx(name, _draft.segments);
    } catch (_) {
      if (mounted) showRRToast(context, 'Não foi possível exportar o arquivo.', error: true);
    }
  }

  Future<void> _save() async {
    final onSave = widget.onSave;
    final name = onSave != null
        ? _name
        : await showDialog<String>(
            context: context,
            builder: (_) => _RouteNameDialog(initial: _name),
          );
    if ((onSave == null && name == null) || !mounted) return;
    setState(() => _saving = true);
    try {
      if (onSave != null) {
        await onSave(_draft);
      } else if (widget.routeId == null) {
        await RouteService.create(name!, _draft);
      } else {
        await RouteService.update(widget.routeId!, name!, _draft);
      }
      if (!mounted) return;
      setState(() => _dirty = false);
      showRRToast(context, onSave != null ? 'Percurso salvo!' : 'Rota salva!');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showRRToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _leave() async {
    final confirmed = await showRRConfirm(
      context,
      title: 'Descartar alterações?',
      text: 'Os pontos que você marcou desde o último salvamento serão perdidos.',
      confirmLabel: 'Descartar',
    );
    if (confirmed && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: c.canvas,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                color: c.surface,
                child: Row(
                  children: [
                    RRIconButton('voltar', tooltip: 'Voltar', onPressed: () => Navigator.maybePop(context)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        (_name ?? 'Nova rota').toUpperCase(),
                        style: RRType.titleM.copyWith(color: c.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    RRIconButton('alvo', tooltip: 'Minha localização', onPressed: _locating ? null : _locate),
                  ],
                ),
              ),
              if (_loading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (_loadError != null)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: RRErrorState(message: _loadError!, onRetry: _load),
                  ),
                )
              else ...[
                Expanded(child: _buildMap(c)),
                _buildPanel(c),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMap(RRColors c) {
    final points = _draft.points;
    final hasRoute = points.length > 1;
    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: points.isNotEmpty ? points.first : _defaultCenter,
        initialZoom: 14,
        minZoom: 3,
        maxZoom: 19,
        initialCameraFit: hasRoute
            ? CameraFit.coordinates(
                coordinates: [for (final s in _draft.segments) ...s.latLngs],
                padding: const EdgeInsets.all(48),
              )
            : null,
        // Sem zoom por toque duplo: quem marca pontos em sequência daria zoom sem querer.
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate & ~InteractiveFlag.doubleTapZoom,
        ),
        onTap: (_, point) => _tap(point),
      ),
      children: [
        if (widget.showTiles) routeTileLayer(),
        routeLines(_draft.segments),
        MarkerLayer(
          markers: [
            if (_me != null)
              Marker(
                point: _me!,
                width: 18,
                height: 18,
                child: const RouteDot(color: RRPalette.ceu300, size: 18),
              ),
            ...routeMarkers(points),
            for (final point in _pending)
              Marker(
                point: point,
                width: 14,
                height: 14,
                child: const RouteDot(color: RRPalette.cal400, size: 14),
              ),
          ],
        ),
        routeAttribution(),
      ],
    );
  }

  Widget _buildPanel(RRColors c) {
    final draft = _draft;
    final pace = routePaceSeconds(context.select<AuthProvider, Map<String, dynamic>?>((a) => a.user?.estatisticas));
    final km = draft.meters / 1000;
    final paceLabel = '${pace ~/ 60}:${(pace % 60).toString().padLeft(2, '0')}/KM';
    final String hint;
    if (draft.isEmpty) {
      hint = 'Toque no mapa para marcar a largada.';
    } else if (!draft.canSave) {
      hint = 'Agora toque no próximo ponto da rota.';
    } else if (draft.hasStraightSegment) {
      hint = 'Trechos tracejados estão em linha reta, então a distância é aproximada e a subida fica incompleta.';
    } else {
      hint = 'A rota segue o mapa, mas não avalia segurança. Prefira ruas movimentadas e iluminadas.';
    }

    return Container(
      color: c.surface,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: RRCentered(
        maxWidth: 720,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: _Stat('DISTÂNCIA', '${Fmt.km(km)} km')),
                Expanded(child: _Stat('SUBIDA', draft.canSave ? '${draft.ascent.round()} m' : '—')),
                Expanded(child: _Stat('A $paceLabel', draft.canSave ? routeDuration((km * pace).round()) : '—')),
              ],
            ),
            const SizedBox(height: 10),
            Text(hint, style: RRType.textS.copyWith(color: c.textSecondary)),
            const SizedBox(height: 12),
            Row(
              children: [
                RRIconButton(
                  'desfazer',
                  tooltip: 'Desfazer último ponto',
                  onPressed: draft.isEmpty || _busy ? null : _undo,
                ),
                RRIconButton(
                  'circuito',
                  tooltip: 'Fechar o circuito',
                  onPressed: draft.canClose && !_busy ? () => _tap(draft.points.first) : null,
                ),
                RRIconButton('excluir', tooltip: 'Limpar a rota', onPressed: draft.isEmpty || _busy ? null : _clear),
                RRIconButton('baixar', tooltip: 'Exportar GPX', onPressed: draft.canSave && !_busy ? _export : null),
                const SizedBox(width: 8),
                Expanded(
                  child: RRButton(
                    widget.onSave != null ? 'Salvar percurso' : 'Salvar rota',
                    expand: true,
                    loading: _saving,
                    onPressed: draft.canSave && !_busy ? _save : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: RRType.monoS.copyWith(color: c.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: RRType.dataM.copyWith(color: c.textPrimary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _RouteNameDialog extends StatefulWidget {
  final String? initial;
  const _RouteNameDialog({this.initial});

  @override
  State<_RouteNameDialog> createState() => _RouteNameDialogState();
}

class _RouteNameDialogState extends State<_RouteNameDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) Navigator.pop(context, _name.text.trim());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('SALVAR ROTA', style: RRType.titleM.copyWith(color: context.rr.textPrimary)),
    content: Form(
      key: _form,
      child: RRField(
        controller: _name,
        label: 'Nome da rota',
        hint: 'Volta do parque',
        onSubmitted: (_) => _submit(),
        validator: (value) {
          final length = value?.trim().length ?? 0;
          return length < 3 || length > 60 ? 'Use de 3 a 60 letras' : null;
        },
      ),
    ),
    actions: [
      OverflowBar(
        spacing: 8,
        children: [
          RRButton('Cancelar', kind: RRButtonKind.ghost, onPressed: () => Navigator.pop(context)),
          RRButton('Salvar', onPressed: _submit),
        ],
      ),
    ],
  );
}
