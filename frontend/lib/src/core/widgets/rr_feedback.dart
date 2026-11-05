import 'package:flutter/material.dart';

import '../brand/rr_brand.dart';
import '../motion/rr_motion.dart';
import '../theme/rr_theme.dart';
import 'rr_button.dart';

class RRLoading extends StatelessWidget {
  const RRLoading({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(48),
    child: Center(child: CircularProgressIndicator(strokeWidth: 3)),
  );
}

/// Esqueleto de carregamento: mostra a forma do conteúdo que está chegando.
class RRSkeleton extends StatefulWidget {
  final int count;
  final int columns;
  final double height;
  const RRSkeleton({super.key, this.count = 3, this.columns = 1, this.height = 280});

  @override
  State<RRSkeleton> createState() => _RRSkeletonState();
}

class _RRSkeletonState extends State<RRSkeleton> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (RRMotion.reduced(context)) {
      _controller.stop();
      _controller.value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    Widget bar(double? width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: c.subtle, borderRadius: BorderRadius.circular(RRRadius.sm)),
    );
    Widget card() => Container(
      height: widget.height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(RRRadius.lg),
        border: Border.all(color: c.border),
      ),
      child: FadeTransition(
        opacity: Tween(begin: .45, end: 1.0).animate(_controller),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bar(140, 14),
            const SizedBox(height: 12),
            bar(220, 18),
            const SizedBox(height: 12),
            Expanded(child: bar(double.infinity, double.infinity)),
            const SizedBox(height: 12),
            bar(180, 22),
          ],
        ),
      ),
    );
    return Semantics(
      label: 'Carregando',
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (var i = 0; i < widget.count; i++)
            LayoutBuilder(
              builder: (_, box) =>
                  SizedBox(width: (box.maxWidth - 16 * (widget.columns - 1)) / widget.columns, child: card()),
            ),
        ],
      ),
    );
  }
}

class RREmptyState extends StatelessWidget {
  final String title, text;
  final String? actionLabel;
  final VoidCallback? onAction;
  const RREmptyState({super.key, required this.title, required this.text, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(RRRadius.lg),
        border: Border.all(color: c.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: RRMotion.reduced(context) ? 1 : .6, end: 1),
            duration: RRMotion.of(context, RRMotion.slow),
            curve: RRMotion.pop,
            builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
            child: RRSymbol(height: 40, color: c.accent),
          ),
          const SizedBox(height: 14),
          Text(
            title.toUpperCase(),
            textAlign: TextAlign.center,
            style: RRType.titleL.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: RRType.textM.copyWith(color: c.textSecondary),
          ),
          if (actionLabel != null) ...[const SizedBox(height: 16), RRButton(actionLabel!, onPressed: onAction)],
        ],
      ),
    );
  }
}

class RRErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const RRErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) =>
      RREmptyState(title: 'Saímos da rota', text: message, actionLabel: 'Tentar de novo', onAction: onRetry);
}

/// Aviso flutuante.
void showRRToast(BuildContext context, String message, {bool error = false, String? icon}) {
  final c = context.rr;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? c.danger : c.inverse,
        width: MediaQuery.sizeOf(context).width >= 500 ? 420 : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RRRadius.md)),
        content: Row(
          children: [
            RRIcon(icon ?? (error ? 'fechar' : 'confirmar'), size: 22, color: error ? c.canvas : c.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: RRType.labelM.copyWith(color: error ? c.canvas : c.textInverse)),
            ),
          ],
        ),
      ),
    );
}

/// Diálogo de confirmação. Retorna true se a pessoa confirmou.
Future<bool> showRRConfirm(
  BuildContext context, {
  required String title,
  required String text,
  required String confirmLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final c = ctx.rr;
      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(), style: RRType.displayS.copyWith(color: c.textPrimary)),
                const SizedBox(height: 10),
                Text(text, style: RRType.textM.copyWith(color: c.textSecondary)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    RRButton('Cancelar', kind: RRButtonKind.ghost, onPressed: () => Navigator.pop(ctx, false)),
                    const SizedBox(width: 8),
                    RRButton(confirmLabel, onPressed: () => Navigator.pop(ctx, true)),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return result ?? false;
}
