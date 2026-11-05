import 'package:flutter/material.dart';

import '../brand/rr_brand.dart';
import '../motion/rr_motion.dart';
import '../theme/rr_theme.dart';

enum RRButtonKind { primary, accent, secondary, ghost, onDark }

enum RRButtonSize { l, m, s }

/// Botão do design system. "accent" é a ação de prova (Tartan).
class RRButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final RRButtonKind kind;
  final RRButtonSize size;
  final bool expand, loading;
  final String? icon;

  const RRButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.kind = RRButtonKind.primary,
    this.size = RRButtonSize.m,
    this.expand = false,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    final (height, pad, textStyle, iconSize) = switch (size) {
      RRButtonSize.l => (56.0, 28.0, RRType.labelL, 20.0),
      RRButtonSize.m => (44.0, 20.0, RRType.labelM, 18.0),
      RRButtonSize.s => (36.0, 16.0, RRType.labelM, 16.0),
    };
    final (Color? bg, Color hover, Color? line, Color fg) = switch (kind) {
      RRButtonKind.primary => (c.action, c.actionHover, null, c.onAction),
      RRButtonKind.accent => (c.accent, c.accentHover, null, c.onAccent),
      RRButtonKind.secondary => (null, c.subtle, c.textPrimary, c.textPrimary),
      RRButtonKind.ghost => (null, c.subtle, null, c.textPrimary),
      RRButtonKind.onDark => (null, RRPalette.cal800, RRPalette.cal50, RRPalette.cal50),
    };
    final disabled = onPressed == null || loading;
    final disabledFg = kind == RRButtonKind.onDark ? RRPalette.cal500 : c.textMuted;
    final effectiveFg = disabled && !loading ? disabledFg : fg;

    final button = RRPressable(
      enabled: !disabled,
      child: TextButton(
        onPressed: disabled ? null : onPressed,
        style: ButtonStyle(
          animationDuration: RRMotion.of(context, RRMotion.fast),
          minimumSize: WidgetStatePropertyAll(Size(0, height)),
          padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: pad)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: WidgetStateProperty.resolveWith((states) {
            final off = states.contains(WidgetState.disabled);
            final color = line == null
                ? null
                : off && !loading
                ? (kind == RRButtonKind.onDark ? RRPalette.cal700 : c.border)
                : line;
            return RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RRRadius.md),
              side: color == null ? BorderSide.none : BorderSide(color: color),
            );
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              if (loading) return bg;
              return bg == null ? null : c.subtle;
            }
            if (states.contains(WidgetState.hovered)) return hover;
            return bg;
          }),
          overlayColor: WidgetStatePropertyAll(fg.withValues(alpha: .08)),
          foregroundColor: WidgetStatePropertyAll(effectiveFg),
        ),
        // Rótulo, ícone e carregamento se trocam sem o botão saltar de tamanho.
        child: AnimatedSize(
          duration: RRMotion.of(context, RRMotion.base),
          curve: RRMotion.enter,
          child: AnimatedSwitcher(
            duration: RRMotion.of(context, RRMotion.fast),
            child: loading
                ? SizedBox(
                    key: const ValueKey('loading'),
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
                  )
                : Row(
                    key: ValueKey('$label$icon'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          style: textStyle.copyWith(color: effectiveFg),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (icon != null) ...[
                        const SizedBox(width: 8),
                        RRIcon(icon!, size: iconSize, color: effectiveFg),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Ação de ícone com área de toque de 44 px.
class RRIconButton extends StatelessWidget {
  final String icon, tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final bool filled;
  final double size;

  const RRIconButton(
    this.icon, {
    super.key,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.filled = false,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) => RRPressable(
    pressedScale: .88,
    enabled: onPressed != null,
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      padding: EdgeInsets.zero,
      icon: AnimatedSwitcher(
        duration: RRMotion.of(context, RRMotion.fast),
        child: RRIcon(icon, key: ValueKey('$icon$filled'), size: size, color: color, filled: filled),
      ),
    ),
  );
}
