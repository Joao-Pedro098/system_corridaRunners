import 'package:flutter/material.dart';

import '../../../../core/brand/rr_brand.dart';
import '../../../../core/motion/rr_motion.dart';
import '../../../../core/theme/rr_theme.dart';
import '../../../../core/widgets/rr_button.dart';

/// Moldura de Entrar e Criar conta: faixa em Asfalto com raias e o formulário.
class AuthFrame extends StatelessWidget {
  final String title, subtitle;
  final Widget child;
  const AuthFrame({super.key, required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    final desktop = RRBreakpoints.isDesktop(context);
    final top = MediaQuery.paddingOf(context).top;
    final back = RRIconButton(
      'voltar',
      tooltip: 'Voltar',
      color: RRPalette.cal50,
      onPressed: () => Navigator.maybePop(context),
    );

    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RRReveal(
          child: Text(subtitle, style: RRType.textL.copyWith(color: c.textSecondary)),
        ),
        const SizedBox(height: 24),
        RRReveal(index: 2, child: child),
      ],
    );

    if (desktop) {
      return Scaffold(
        backgroundColor: c.canvas,
        body: Row(
          children: [
            Expanded(
              child: ColoredBox(
                color: RRPalette.cal950,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: RRLanes(
                        color: RRPalette.tartan500,
                        fromRight: -10,
                        cy: 280,
                        r0: 60,
                        step: 46,
                        count: 7,
                        strokeWidth: 16,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              back,
                              const SizedBox(width: 8),
                              const RRLockup(height: 28, symbolColor: RRPalette.tartan500, wordColor: RRPalette.cal50),
                            ],
                          ),
                          const Spacer(),
                          RRMaskedLine(
                            child: Text(
                              'CORRA\nA SUA\nROTA.',
                              style: RRType.hero(112, 98).copyWith(color: RRPalette.cal50),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 560,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RRMaskedLine(
                        child: Text(title.toUpperCase(), style: RRType.displayM.copyWith(color: c.textPrimary)),
                      ),
                      const SizedBox(height: 8),
                      form,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.canvas,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: RRPalette.cal950,
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: RRLanes(
                      color: RRPalette.tartan500,
                      fromRight: -10,
                      cy: 40,
                      r0: 26,
                      step: 28,
                      count: 6,
                      strokeWidth: 10,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(8, top + 8, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        back,
                        const SizedBox(height: 56),
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: RRMaskedLine(
                            child: Text(title.toUpperCase(), style: RRType.displayL.copyWith(color: RRPalette.cal50)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(24, 24, 24, 32), child: form),
          ],
        ),
      ),
    );
  }
}
