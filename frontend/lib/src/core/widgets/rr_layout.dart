import 'package:flutter/material.dart';

import '../brand/rr_brand.dart';
import '../motion/rr_motion.dart';
import '../theme/rr_theme.dart';
import 'rr_button.dart';

Future<T?> rrPush<T>(BuildContext context, Widget page) =>
    Navigator.of(context).push<T>(RRPageRoute(builder: (_) => page, instant: RRMotion.reduced(context)));

/// Superfície base dos cartões.
class RRCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  const RRCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});

  @override
  State<RRCard> createState() => _RRCardState();
}

class _RRCardState extends State<RRCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    final interactive = widget.onTap != null;
    final raised = _hovered && interactive;
    return RRPressable(
      enabled: interactive,
      pressedScale: .985,
      hoverLift: 3,
      onHover: (value) => setState(() => _hovered = value),
      child: AnimatedContainer(
        duration: RRMotion.of(context, RRMotion.base),
        curve: RRMotion.enter,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(RRRadius.lg),
          boxShadow: raised ? RRShadow.e2 : const [],
        ),
        child: Material(
          color: c.surface,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RRRadius.lg),
            side: BorderSide(color: raised ? c.borderStrong : c.border),
          ),
          // Sem ação, o cartão não finge ser clicável nem escurece no hover.
          child: InkWell(
            onTap: widget.onTap,
            hoverColor: Colors.transparent,
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// Título de seção com ação opcional em DM Mono.
class RRSectionHead extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const RRSectionHead(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(title.toUpperCase(), style: RRType.titleL.copyWith(color: c.textPrimary)),
        ),
        if (action != null)
          InkWell(
            onTap: onAction,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text(action!.toUpperCase(), style: RRType.monoS.copyWith(color: c.textLink)),
            ),
          ),
      ],
    );
  }
}

class RRStat extends StatelessWidget {
  final String label;
  final double value;
  final String Function(double value) format;
  final String? unit;
  const RRStat({super.key, required this.label, required this.value, required this.format, this.unit});

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(RRRadius.lg),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: RRType.monoS.copyWith(color: c.textSecondary)),
          const SizedBox(height: 8),
          RRCountUp(
            value: value,
            builder: (_, v) => Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: format(v),
                    style: RRType.dataL.copyWith(color: c.textPrimary),
                  ),
                  if (unit != null)
                    TextSpan(
                      text: ' ${unit!.toUpperCase()}',
                      style: RRType.monoS.copyWith(color: c.textSecondary),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RRInfoLine extends StatelessWidget {
  final String icon, title, value;
  final VoidCallback? onTap;
  const RRInfoLine({super.key, required this.icon, required this.title, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.border)),
        ),
        child: Row(
          children: [
            RRIcon(icon, size: 20, color: c.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.toUpperCase(), style: RRType.monoS.copyWith(color: c.textMuted)),
                  const SizedBox(height: 2),
                  Text(value, style: RRType.labelM.copyWith(color: c.textPrimary)),
                ],
              ),
            ),
            if (onTap != null) RRIcon('avancar', size: 18, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Coluna central com largura máxima: mantém a leitura boa em telas largas.
class RRCentered extends StatelessWidget {
  final double maxWidth;
  final Widget child;
  const RRCentered({super.key, this.maxWidth = 720, required this.child});

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// Grade com colunas iguais e linhas da mesma altura.
class RRGrid extends StatelessWidget {
  final int columns;
  final double gap;
  final List<Widget> children;

  /// Faz os itens entrarem em sequência, linha a linha.
  final bool reveal;
  const RRGrid({super.key, required this.columns, this.gap = 20, required this.children, this.reveal = true});

  Widget _item(int index, int position) =>
      reveal ? RRReveal(index: position, key: children[index].key, child: children[index]) : children[index];

  @override
  Widget build(BuildContext context) {
    if (columns <= 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) SizedBox(height: gap), _item(i, 0)],
        ],
      );
    }
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      if (i > 0) rows.add(SizedBox(height: gap));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var k = 0; k < columns; k++) ...[
                if (k > 0) SizedBox(width: gap),
                Expanded(child: i + k < children.length ? _item(i + k, k) : const SizedBox()),
              ],
            ],
          ),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}

/// Tela interna: seta de voltar, título e conteúdo rolável.
class RRSubPage extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Widget? bottom;
  final double maxWidth;
  const RRSubPage({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.bottom,
    this.maxWidth = 720,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    return Scaffold(
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
                      title.toUpperCase(),
                      style: RRType.titleM.copyWith(color: c.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ...?actions,
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: RRCentered(maxWidth: maxWidth, child: child),
              ),
            ),
            if (bottom != null)
              Container(
                color: c.surface,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: RRCentered(maxWidth: maxWidth, child: bottom!),
              ),
          ],
        ),
      ),
    );
  }
}
