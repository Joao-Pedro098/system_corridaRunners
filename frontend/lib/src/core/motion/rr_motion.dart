import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Linguagem de movimento do RunnersRun: entradas rápidas que desaceleram,
/// como um corredor chegando, e sempre sem atrasar a ação de quem usa o app.
class RRMotion {
  RRMotion._();

  static const fast = Duration(milliseconds: 140);
  static const base = Duration(milliseconds: 240);
  static const slow = Duration(milliseconds: 420);
  static const draw = Duration(milliseconds: 1000);

  static const enter = Cubic(.2, 0, 0, 1);
  static const pop = Cubic(.34, 1.56, .64, 1);

  /// Preferência de movimento reduzido do sistema ou do navegador.
  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static Duration of(BuildContext context, Duration duration) => reduced(context) ? Duration.zero : duration;
}

/// Dispara [onShown] uma única vez, quando o widget está na aba ativa e entrou
/// na área visível da rolagem. Evita animar o que ninguém está vendo.
mixin RevealOnShow<T extends StatefulWidget> on State<T> {
  bool _revealed = false;
  bool _tickerOn = false;
  bool _checkScheduled = false;
  ScrollPosition? _position;
  BuildContext? _viewport;

  void onShown();

  bool get revealed => _revealed;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerOn = TickerMode.valuesOf(context).enabled;
    if (_revealed) return;
    final scrollable = Scrollable.maybeOf(context, axis: Axis.vertical);
    if (scrollable?.position != _position) {
      _position?.removeListener(_onScroll);
      _position = scrollable?.position;
      _position?.addListener(_onScroll);
    }
    _viewport = scrollable?.context;
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  /// A posição só muda na tela no próximo quadro: medir antes disso deixaria
  /// invisível o que uma rolagem rápida acabou de trazer.
  void _onScroll() {
    if (_checkScheduled) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      _check();
    });
  }

  void _check() {
    if (_revealed || !mounted || !_tickerOn) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final viewportBox = _viewport?.findRenderObject();
    if (viewportBox is RenderBox && viewportBox.attached && viewportBox.hasSize) {
      final top = box.localToGlobal(Offset.zero).dy;
      final limit = viewportBox.localToGlobal(Offset.zero).dy + viewportBox.size.height;
      if (top > limit - 16) return;
    }
    _revealed = true;
    _position?.removeListener(_onScroll);
    onShown();
  }

  @override
  void dispose() {
    _position?.removeListener(_onScroll);
    super.dispose();
  }
}

/// Entrada padrão: sobe e aparece quando fica visível.
class RRReveal extends StatefulWidget {
  final Widget child;
  final int index;
  final double offset;
  const RRReveal({super.key, required this.child, this.index = 0, this.offset = 18});

  @override
  State<RRReveal> createState() => _RRRevealState();
}

class _RRRevealState extends State<RRReveal> with SingleTickerProviderStateMixin, RevealOnShow {
  late final _controller = AnimationController(vsync: this, duration: RRMotion.slow);

  @override
  void onShown() {
    if (RRMotion.reduced(context)) {
      _controller.value = 1;
      return;
    }
    // Atraso limitado: listas longas não ficam esperando a vez.
    final wait = Duration(milliseconds: 45 * widget.index.clamp(0, 6));
    Future.delayed(wait, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (_, child) {
      final t = RRMotion.enter.transform(_controller.value);
      return Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, widget.offset * (1 - t)), child: child),
      );
    },
  );
}

/// Linha de texto que sobe de trás de uma máscara.
class RRMaskedLine extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const RRMaskedLine({super.key, required this.child, this.delay = Duration.zero});

  @override
  State<RRMaskedLine> createState() => _RRMaskedLineState();
}

class _RRMaskedLineState extends State<RRMaskedLine> with SingleTickerProviderStateMixin, RevealOnShow {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 640));

  @override
  void onShown() {
    if (RRMotion.reduced(context)) {
      _controller.value = 1;
      return;
    }
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (_, child) {
      final t = _controller.value;
      // A máscara só existe durante a entrada: parado, nada corta os acentos.
      return ClipRect(
        clipper: const _HeadroomClipper(),
        clipBehavior: t >= 1 ? Clip.none : Clip.hardEdge,
        child: FractionalTranslation(translation: Offset(0, 1.05 * (1 - RRMotion.enter.transform(t))), child: child),
      );
    },
  );
}

/// Recorte com folga no topo, para letras acentuadas que passam da linha.
class _HeadroomClipper extends CustomClipper<Rect> {
  const _HeadroomClipper();

  @override
  Rect getClip(Size size) => Rect.fromLTRB(0, -size.height * .3, size.width, size.height);

  @override
  bool shouldReclip(_HeadroomClipper old) => false;
}

/// Número que conta até o valor quando aparece e transita quando muda.
class RRCountUp extends StatefulWidget {
  final double value;
  final Widget Function(BuildContext context, double value) builder;
  const RRCountUp({super.key, required this.value, required this.builder});

  @override
  State<RRCountUp> createState() => _RRCountUpState();
}

class _RRCountUpState extends State<RRCountUp> with SingleTickerProviderStateMixin, RevealOnShow {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  double _from = 0;
  late double _to = widget.value;

  @override
  void onShown() {
    if (RRMotion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(RRCountUp old) {
    super.didUpdateWidget(old);
    if (old.value == widget.value) return;
    _from = _current;
    _to = widget.value;
    if (RRMotion.reduced(context)) {
      _controller.value = 1;
    } else if (revealed) {
      _controller.forward(from: 0);
    }
  }

  double get _current => _from + (_to - _from) * RRMotion.enter.transform(_controller.value);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      AnimatedBuilder(animation: _controller, builder: (context, _) => widget.builder(context, _current));
}

/// Resposta ao toque e ao ponteiro: afunda ao pressionar e sobe no hover.
class RRPressable extends StatefulWidget {
  final Widget child;
  final double pressedScale;
  final double hoverLift;
  final bool enabled;
  final ValueChanged<bool>? onHover;
  const RRPressable({
    super.key,
    required this.child,
    this.pressedScale = .97,
    this.hoverLift = 0,
    this.enabled = true,
    this.onHover,
  });

  @override
  State<RRPressable> createState() => _RRPressableState();
}

class _RRPressableState extends State<RRPressable> {
  bool _pressed = false, _hovered = false;

  void _setPressed(bool value) {
    if (widget.enabled && _pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final duration = RRMotion.of(context, RRMotion.fast);
    final lift = _hovered && widget.enabled ? -widget.hoverLift : 0.0;
    return MouseRegion(
      onEnter: (_) {
        setState(() => _hovered = true);
        widget.onHover?.call(true);
      },
      onExit: (_) {
        setState(() {
          _hovered = false;
          _pressed = false;
        });
        widget.onHover?.call(false);
      },
      child: Listener(
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: lift),
          duration: duration,
          curve: RRMotion.enter,
          builder: (_, value, child) => Transform.translate(offset: Offset(0, value), child: child),
          child: AnimatedScale(
            scale: _pressed ? widget.pressedScale : 1,
            duration: duration,
            curve: RRMotion.enter,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Tremida curta para indicar que um formulário tem erros.
class RRShake extends StatefulWidget {
  final Widget child;
  const RRShake({super.key, required this.child});

  @override
  RRShakeState createState() => RRShakeState();
}

class RRShakeState extends State<RRShake> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 360));

  void shake() {
    if (!RRMotion.reduced(context)) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (_, child) {
      final t = _controller.value;
      final dx = 6 * (1 - t) * math.sin(t * math.pi * 6);
      return Transform.translate(offset: Offset(dx, 0), child: child);
    },
  );
}

/// Transição de tela: em iOS mantém o gesto nativo de voltar; nas demais
/// plataformas a nova tela sobe e aparece.
class RRPageRoute<T> extends MaterialPageRoute<T> {
  final bool instant;
  RRPageRoute({required super.builder, this.instant = false});

  @override
  Duration get transitionDuration => instant ? Duration.zero : const Duration(milliseconds: 340);

  @override
  Duration get reverseTransitionDuration => instant ? Duration.zero : const Duration(milliseconds: 240);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (instant) return child;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return super.buildTransitions(context, animation, secondaryAnimation, child);
    }
    final curved = CurvedAnimation(parent: animation, curve: RRMotion.enter, reverseCurve: Curves.easeIn);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, .03), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}
