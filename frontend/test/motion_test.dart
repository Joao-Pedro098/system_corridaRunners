import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/src/core/motion/rr_motion.dart';
import 'package:frontend/src/core/theme/rr_theme.dart';
import 'package:frontend/src/core/utils/format.dart';
import 'package:frontend/src/core/widgets/rr_button.dart';

Widget _app(Widget child, {bool reduced = false}) => MaterialApp(
  theme: buildRRTheme(Brightness.light),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Scaffold(body: child),
  ),
);

double _opacity(WidgetTester tester, Finder finder) => tester
    .widget<Opacity>(find.ancestor(of: finder, matching: find.byType(Opacity, skipOffstage: false)).first)
    .opacity;

void main() {
  group('RRReveal', () {
    testWidgets('com movimento reduzido, o conteúdo aparece já no primeiro quadro', (tester) async {
      await tester.pumpWidget(_app(const RRReveal(child: Text('oi')), reduced: true));
      await tester.pump();
      expect(_opacity(tester, find.text('oi')), 1);
    });

    testWidgets('com movimento, começa oculto e termina visível', (tester) async {
      await tester.pumpWidget(_app(const RRReveal(child: Text('oi'))));
      expect(_opacity(tester, find.text('oi')), 0);
      await tester.pumpAndSettle();
      expect(_opacity(tester, find.text('oi')), 1);
    });

    testWidgets('fora da área visível, espera a rolagem chegar até ele', (tester) async {
      await tester.pumpWidget(
        _app(
          ListView(
            children: const [
              SizedBox(height: 2000),
              RRReveal(child: Text('abaixo')),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Um ListView nem constrói o item distante: rola até ele existir.
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(_opacity(tester, find.text('abaixo')), 1);
    });

    testWidgets('em aba oculta, só anima quando a aba é mostrada', (tester) async {
      Widget stack(int index) => _app(
        IndexedStack(
          index: index,
          children: const [
            Text('visível'),
            RRReveal(child: Text('oculto')),
          ],
        ),
      );
      await tester.pumpWidget(stack(0));
      await tester.pump(const Duration(seconds: 2));
      expect(_opacity(tester, find.text('oculto', skipOffstage: false)), 0);

      await tester.pumpWidget(stack(1));
      await tester.pumpAndSettle();
      expect(_opacity(tester, find.text('oculto')), 1);
    });
  });

  group('RRCountUp', () {
    Widget counter(double value, {bool reduced = false}) => _app(
      RRCountUp(value: value, builder: (_, v) => Text(Fmt.thousands(v))),
      reduced: reduced,
    );

    testWidgets('conta até o valor final', (tester) async {
      await tester.pumpWidget(counter(1284));
      await tester.pumpAndSettle();
      expect(find.text('1.284'), findsOneWidget);
    });

    testWidgets('transita quando o valor muda', (tester) async {
      await tester.pumpWidget(counter(10));
      await tester.pumpAndSettle();
      await tester.pumpWidget(counter(20));
      await tester.pumpAndSettle();
      expect(find.text('20'), findsOneWidget);
    });

    testWidgets('com movimento reduzido, mostra o valor sem contar', (tester) async {
      await tester.pumpWidget(counter(212, reduced: true));
      await tester.pump();
      expect(find.text('212'), findsOneWidget);
    });
  });

  group('RRButton', () {
    testWidgets('toques rápidos seguidos chamam a ação sem travar', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_app(RRButton('Eu vou!', onPressed: () => taps++)));
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Eu vou!'));
        await tester.pump(const Duration(milliseconds: 40));
      }
      await tester.pumpAndSettle();
      expect(taps, 3);
    });

    testWidgets('carregando não aceita toque', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_app(RRButton('Salvar', loading: true, onPressed: () => taps++)));
      await tester.tap(find.byType(TextButton), warnIfMissed: false);
      await tester.pump(const Duration(seconds: 1));
      expect(taps, 0);
    });
  });

  testWidgets('RRMaskedLine não recorta o texto depois da entrada, para não cortar acentos', (tester) async {
    await tester.pumpWidget(_app(const RRMaskedLine(child: Text('RÚSTICA'))));
    await tester.pumpAndSettle();
    final clip = tester.widget<ClipRect>(
      find.ancestor(of: find.text('RÚSTICA'), matching: find.byType(ClipRect)).first,
    );
    expect(clip.clipBehavior, Clip.none);
  });

  testWidgets('RRShake volta ao lugar depois de tremer', (tester) async {
    final key = GlobalKey<RRShakeState>();
    await tester.pumpWidget(_app(RRShake(key: key, child: const Text('form'))));
    final before = tester.getTopLeft(find.text('form'));
    key.currentState!.shake();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('form')), before);
  });
}
