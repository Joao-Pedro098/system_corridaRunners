import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/brand/rr_brand.dart';
import '../../../../core/motion/rr_motion.dart';
import '../../../../core/theme/rr_theme.dart';
import '../../../../core/widgets/rr_button.dart';
import '../../../../core/widgets/rr_layout.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  // As raias seguem o ponteiro ou o dedo, com atraso, como quem pega o ritmo.
  final _shift = ValueNotifier<Offset>(Offset.zero);
  late final _ticker = createTicker(_tick);
  Offset _target = Offset.zero;

  void _tick(Duration _) {
    final next = Offset.lerp(_shift.value, _target, .08)!;
    _shift.value = next;
    if ((next - _target).distance < .2) {
      _shift.value = _target;
      _ticker.stop();
    }
  }

  void _follow(Offset position, Size size) {
    if (RRMotion.reduced(context)) return;
    _target = Offset((position.dx / size.width - .5) * -36, (position.dy / size.height - .5) * -36);
    if (!_ticker.isActive) _ticker.start();
  }

  void _settle() {
    _target = Offset.zero;
    if (!RRMotion.reduced(context) && !_ticker.isActive) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _shift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RRPalette.cal950,
      body: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth, h = box.maxHeight;
          // Proporções do quadro de 390 x 844 do Figma.
          final heroSize = math.min(math.min(w * .287, h * .1327), 168.0);
          final scale = (h / 844).clamp(.7, 1.6);
          final hero = RRType.hero(heroSize, heroSize * .875).copyWith(color: RRPalette.cal50);
          Widget heroLine(String text, int i) => RRMaskedLine(
            delay: Duration(milliseconds: 180 + 110 * i),
            child: Text(text, style: hero),
          );
          return MouseRegion(
            onHover: (e) => _follow(e.localPosition, box.biggest),
            onExit: (_) => _settle(),
            child: Listener(
              onPointerMove: (e) => _follow(e.localPosition, box.biggest),
              onPointerUp: (_) => _settle(),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: RRLanes(
                      color: RRPalette.tartan500,
                      fromRight: -10,
                      cy: h * .39,
                      r0: 30 * scale,
                      step: 32 * scale,
                      count: w > 700 ? 12 : 6,
                      strokeWidth: 12 * scale,
                      duration: const Duration(milliseconds: 1400),
                      shift: _shift,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: h * .66,
                    child: const IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x00111311), RRPalette.cal950],
                            stops: [0, .45],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const RRReveal(
                            child: RRLockup(height: 32, symbolColor: RRPalette.tartan500, wordColor: RRPalette.cal50),
                          ),
                          const Spacer(),
                          // O texto completo fica disponível como uma frase só
                          // para leitores de tela.
                          Semantics(
                            label: 'Corra a sua rota.',
                            excludeSemantics: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [heroLine('CORRA', 0), heroLine('A SUA', 1), heroLine('ROTA.', 2)],
                            ),
                          ),
                          const SizedBox(height: 16),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                RRReveal(
                                  index: 6,
                                  child: Text(
                                    'Treinos, provas e gente da sua região no mesmo ritmo.',
                                    style: RRType.textL.copyWith(color: RRPalette.cal300),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                RRReveal(
                                  index: 6,
                                  child: RRButton(
                                    'Criar minha conta',
                                    kind: RRButtonKind.accent,
                                    size: RRButtonSize.l,
                                    expand: true,
                                    onPressed: () => rrPush(context, const RegisterScreen()),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                RRReveal(
                                  index: 6,
                                  child: RRButton(
                                    'Já tenho conta',
                                    kind: RRButtonKind.onDark,
                                    size: RRButtonSize.l,
                                    expand: true,
                                    onPressed: () => rrPush(context, const LoginScreen()),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
