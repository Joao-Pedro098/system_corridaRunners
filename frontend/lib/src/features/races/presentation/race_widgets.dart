import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../data/race_model.dart';
import 'race_detail_screen.dart';

/// Lógica de confirmar presença, usada no cartão e no detalhe da prova.
Future<void> toggleRacePresence(BuildContext context, RaceModel race) async {
  final userId = context.read<AuthProvider>().user?.id;
  if (userId == null) return;
  HapticFeedback.mediumImpact();
  final confirmed = await RaceService.togglePresence(race.id);
  confirmed ? race.participantes.add(userId) : race.participantes.remove(userId);
  if (context.mounted) {
    showRRToast(context, confirmed ? 'Presença confirmada. Boa prova!' : 'Presença cancelada.');
  }
}

class RaceCard extends StatefulWidget {
  final RaceModel race;
  final ValueChanged<RaceModel>? onChanged;
  const RaceCard({super.key, required this.race, this.onChanged});

  @override
  State<RaceCard> createState() => _RaceCardState();
}

class _RaceCardState extends State<RaceCard> {
  bool _busy = false;
  // Identidade única: a mesma prova pode aparecer em mais de uma lista.
  final _heroTag = Object();
  final _lanesShift = ValueNotifier<Offset>(Offset.zero);

  @override
  void dispose() {
    _lanesShift.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    await rrPush(context, RaceDetailScreen(race: widget.race, heroTag: _heroTag));
    if (mounted) setState(() {});
    widget.onChanged?.call(widget.race);
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    try {
      await toggleRacePresence(context, widget.race);
      widget.onChanged?.call(widget.race);
    } on ApiException catch (e) {
      if (mounted) showRRToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    final race = widget.race;
    final tone = race.tone;
    final userId = context.select<AuthProvider, String?>((a) => a.user?.id);
    final going = race.participantes.contains(userId);

    final Widget cta;
    if (race.canConfirm) {
      cta = RRButton(
        going ? 'Confirmado' : 'Eu vou!',
        kind: going ? RRButtonKind.secondary : RRButtonKind.accent,
        icon: going ? 'confirmar' : null,
        loading: _busy,
        onPressed: _confirm,
      );
    } else {
      cta = RRButton(race.isOver ? 'Ver resultados' : 'Ver prova', kind: RRButtonKind.secondary, onPressed: _open);
    }

    return MouseRegion(
      // No hover as raias avançam um pouco, como se a pista corresse.
      onEnter: (_) => _lanesShift.value = RRMotion.reduced(context) ? Offset.zero : const Offset(-10, -6),
      onExit: (_) => _lanesShift.value = Offset.zero,
      child: RRCard(
        padding: EdgeInsets.zero,
        onTap: _open,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 168,
              child: Stack(
                children: [
                  // A capa colorida continua o movimento até o detalhe da prova.
                  Positioned.fill(
                    child: Hero(
                      tag: _heroTag,
                      child: ColoredBox(
                        color: tone.background,
                        child: ValueListenableBuilder<Offset>(
                          valueListenable: _lanesShift,
                          builder: (_, shift, child) => TweenAnimationBuilder<Offset>(
                            tween: Tween(end: shift),
                            duration: RRMotion.of(context, RRMotion.slow),
                            curve: RRMotion.enter,
                            builder: (_, value, child) => Transform.translate(offset: value, child: child),
                            child: child,
                          ),
                          child: RRLanes(
                            color: tone.lanes,
                            fromRight: 30,
                            cy: 190,
                            halfStraight: 40,
                            r0: 40,
                            step: 22,
                            count: 7,
                            strokeWidth: 8,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              race.data.day.toString().padLeft(2, '0'),
                              style: RRType.dataXL.copyWith(color: tone.foreground),
                            ),
                            Text(
                              Fmt.monthShort(race.data.month).toUpperCase(),
                              style: RRType.monoM.copyWith(color: tone.foreground),
                            ),
                          ],
                        ),
                        Flexible(child: RRTag(race.statusLabel, tone: race.statusTone, dot: true)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(race.nome.toUpperCase(), style: RRType.titleL.copyWith(color: c.textPrimary)),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: RRIcon('local', size: 16, color: c.textSecondary),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(race.locationLine, style: RRType.textM.copyWith(color: c.textSecondary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(spacing: 4, runSpacing: 4, children: [for (final d in race.distancias) RRDistance(d.label)]),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RRCountUp(
                            value: race.participantes.length.toDouble(),
                            builder: (_, v) =>
                                Text(Fmt.thousands(v), style: RRType.dataM.copyWith(color: c.textPrimary)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            (race.isOver ? 'correram' : 'vão correr').toUpperCase(),
                            style: RRType.monoS.copyWith(color: c.textMuted),
                          ),
                        ],
                      ),
                      Flexible(child: cta),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
