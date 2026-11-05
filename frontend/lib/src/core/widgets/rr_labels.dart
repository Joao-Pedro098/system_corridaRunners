import 'package:flutter/material.dart';

import '../motion/rr_motion.dart';
import '../theme/rr_theme.dart';
import '../utils/format.dart';

/// Etiqueta colorida (tipo de treino, status de prova).
class RRTag extends StatelessWidget {
  final String label;
  final RRTone tone;
  final bool dot;
  const RRTag(this.label, {super.key, required this.tone, this.dot = false});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = context.rr.tags[tone]!;
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(RRRadius.sm)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(label, style: RRType.labelS.copyWith(color: fg)),
        ],
      ),
    );
  }
}

/// Selo de distância: 5K, 10K, 21K.
class RRDistance extends StatelessWidget {
  final String km;
  const RRDistance(this.km, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: c.borderStrong),
        borderRadius: BorderRadius.circular(RRRadius.sm),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(km.toUpperCase(), style: RRType.monoS.copyWith(color: c.textPrimary)),
      ),
    );
  }
}

/// Esforço percebido: cinco barras ascendentes com rótulo.
class RREffort extends StatelessWidget {
  static const labels = ['Muito fácil', 'Fácil', 'Moderado', 'Difícil', 'Exaustivo'];
  final int level;
  final bool showLabel;
  const RREffort(this.level, {super.key, this.showLabel = true});

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    final on = level >= 4 ? c.accent : c.textPrimary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 1; i <= 5; i++)
          AnimatedContainer(
            duration: RRMotion.of(context, RRMotion.base),
            curve: RRMotion.enter,
            width: 4,
            height: 4.0 + i * 2,
            margin: const EdgeInsets.only(right: 2),
            color: i <= level ? on : c.borderStrong,
          ),
        if (showLabel) ...[
          const SizedBox(width: 6),
          Text(labels[level - 1].toUpperCase(), style: RRType.monoS.copyWith(color: c.textSecondary)),
        ],
      ],
    );
  }
}

class RRChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const RRChip(this.label, {super.key, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    final duration = RRMotion.of(context, RRMotion.base);
    return Semantics(
      selected: selected,
      button: true,
      child: RRPressable(
        pressedScale: .94,
        child: AnimatedContainer(
          duration: duration,
          curve: RRMotion.enter,
          decoration: ShapeDecoration(
            color: selected ? c.action : c.action.withValues(alpha: 0),
            shape: StadiumBorder(side: BorderSide(color: selected ? c.action : c.borderStrong)),
          ),
          child: Material(
            type: MaterialType.transparency,
            shape: const StadiumBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Center(
                  widthFactor: 1,
                  child: AnimatedDefaultTextStyle(
                    duration: duration,
                    style: RRType.labelS.copyWith(color: selected ? c.onAction : c.textPrimary),
                    child: Text(label),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Foto do atleta ou, sem foto, iniciais sobre Asfalto.
class RRAvatar extends StatelessWidget {
  final String name;
  final String? url;
  final double size;
  const RRAvatar(this.name, {super.key, this.url, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    final style = size >= 64
        ? RRType.dataL
        : size >= 48
        ? RRType.titleM
        : size >= 40
        ? RRType.labelM
        : RRType.labelS;
    final fallback = Center(
      child: Text(Fmt.initials(name), style: style.copyWith(color: c.textInverse)),
    );
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: c.inverse, shape: BoxShape.circle),
      child: url == null || url!.isEmpty
          ? fallback
          : Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
    );
  }
}
