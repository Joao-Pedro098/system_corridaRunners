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
import '../data/race_model.dart';
import 'race_detail_screen.dart';
import 'race_form_screen.dart';

/// Provas cadastradas pelo organizador logado.
class MyRacesScreen extends StatefulWidget {
  const MyRacesScreen({super.key});

  @override
  State<MyRacesScreen> createState() => _MyRacesScreenState();
}

class _MyRacesScreenState extends State<MyRacesScreen> {
  List<RaceModel> _races = [];
  bool _loading = true;
  String? _error;
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
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final races = await RaceService.mine();
      if (mounted) setState(() => _races = races);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcoming = _races.where((r) => !r.data.isBefore(today)).toList();
    final past = _races.where((r) => r.data.isBefore(today)).toList().reversed.toList();

    final Widget body;
    if (_loading && _races.isEmpty) {
      body = const RRSkeleton(count: 3, height: 112);
    } else if (_error != null) {
      body = RRErrorState(message: _error!, onRetry: _load);
    } else if (_races.isEmpty) {
      body = RREmptyState(
        title: 'Sua primeira prova começa aqui',
        text: 'Cadastre uma prova e ela entra no calendário para os corredores da região.',
        actionLabel: 'Cadastrar prova',
        onAction: () => rrPush(context, const RaceFormScreen()),
      );
    } else {
      List<Widget> group(String title, List<RaceModel> races) => [
        RRSectionHead('$title (${races.length})'),
        const SizedBox(height: 12),
        for (final (i, race) in races.indexed)
          RRReveal(
            key: ValueKey(race.id),
            index: i,
            child: Padding(padding: const EdgeInsets.only(bottom: 8), child: _MyRaceRow(race)),
          ),
        const SizedBox(height: 20),
      ];
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (upcoming.isNotEmpty) ...group('Próximas', upcoming),
          if (past.isNotEmpty) ...group('Já aconteceram', past),
        ],
      );
    }

    return RRSubPage(
      title: 'Minhas provas',
      bottom: _races.isEmpty
          ? null
          : RRButton(
              'Cadastrar nova prova',
              icon: 'mais',
              size: RRButtonSize.l,
              expand: true,
              onPressed: () => rrPush(context, const RaceFormScreen()),
            ),
      child: body,
    );
  }
}

class _MyRaceRow extends StatelessWidget {
  final RaceModel race;
  const _MyRaceRow(this.race);

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    final tone = race.tone;
    final going = race.participantes.length;
    return RRCard(
      padding: const EdgeInsets.all(12),
      onTap: () => rrPush(context, RaceDetailScreen(race: race)),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 72,
            decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(RRRadius.md)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(race.data.day.toString().padLeft(2, '0'), style: RRType.dataM.copyWith(color: tone.foreground)),
                Text(
                  Fmt.monthShort(race.data.month).toUpperCase(),
                  style: RRType.monoS.copyWith(color: tone.foreground),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  race.nome,
                  style: RRType.labelM.copyWith(color: c.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                RRTag(race.statusLabel, tone: race.statusTone, dot: true),
                const SizedBox(height: 4),
                Text(
                  '${going == 1 ? '1 CONFIRMADO' : '$going CONFIRMADOS'} • ${race.cityLine}'.toUpperCase(),
                  style: RRType.monoS.copyWith(color: c.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          RRIconButton(
            'editar',
            tooltip: 'Editar ${race.nome}',
            size: 20,
            onPressed: () => rrPush(context, RaceFormScreen(race: race)),
          ),

          RRIcon('avancar', size: 18, color: c.textMuted),
        ],
      ),
    );
  }
}
