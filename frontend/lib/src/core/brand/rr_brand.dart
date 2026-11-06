import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../motion/rr_motion.dart';
import '../theme/rr_theme.dart';

const _logoSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 116 112"><path d="M0.05 111.00L19.62 0.00L82.62 0.00C104.16 0.00 118.54 17.46 114.75 39.00C110.95 60.54 90.41 78.00 68.87 78.00L70.99 78.00L84.42 111.00L71.68 111.00L53.77 67.00L70.81 67.00C86.27 67.00 101.02 54.46 103.75 39.00C106.47 23.54 96.15 11.00 80.68 11.00L28.68 11.00L11.05 111.00Z"/><path d="M19.05 111.00L35.27 19.00L79.27 19.00C90.32 19.00 97.69 27.95 95.75 39.00C93.80 50.05 83.27 59.00 72.22 59.00L41.26 59.00L62.42 111.00L49.68 111.00L28.31 58.47L30.16 48.00L74.16 48.00C79.13 48.00 83.87 43.97 84.75 39.00C85.62 34.03 82.30 30.00 77.33 30.00L44.33 30.00L30.05 111.00Z"/></svg>';

/// Símbolo oficial: o "R" de duas raias.
class RRSymbol extends StatelessWidget {
  final double height;
  final Color? color;
  const RRSymbol({super.key, required this.height, this.color});

  @override
  Widget build(BuildContext context) => SvgPicture.string(
    _logoSvg,
    height: height,
    width: height * 116 / 112,
    colorFilter: ColorFilter.mode(color ?? context.rr.logo, BlendMode.srcIn),
    semanticsLabel: 'RunnersRun',
  );
}

/// Logo horizontal: símbolo + nome.
class RRLockup extends StatelessWidget {
  final double height;
  final Color? symbolColor, wordColor;
  const RRLockup({super.key, this.height = 24, this.symbolColor, this.wordColor});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      RRSymbol(height: height, color: symbolColor),
      SizedBox(width: (height * .22).roundToDouble()),
      Text(
        'RUNNERSRUN',
        style: RRType.wordmark.copyWith(
          fontSize: (height * 1.16).roundToDouble(),
          letterSpacing: height * .0116,
          color: wordColor ?? symbolColor ?? context.rr.logo,
        ),
      ),
    ],
  );
}

const _icons = <String, String>{
  'comunidade': '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20c0-3.6 2.9-6 6.5-6s6.5 2.4 6.5 6"/><path d="M16 4.8a3.5 3.5 0 0 1 0 6.4"/><path d="M18 14.4c2.1.7 3.5 2.8 3.5 5.6"/>',
  'calendario':
      '<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18"/><path d="M8 3v4"/><path d="M16 3v4"/>',
  'noticias': '<path d="M4 5h13v14a2 2 0 0 0 2 2H6a2 2 0 0 1-2-2z"/><path d="M17 9h3v10a2 2 0 0 1-2 2"/><path d="M8 9h5"/><path d="M8 13h5"/><path d="M8 17h5"/>',
  'perfil': '<circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 3.6-7 8-7s8 3 8 7"/>',
  'mais': '<path d="M12 5v14"/><path d="M5 12h14"/>',
  'desfazer': '<path d="M9 14L4 9l5-5"/><path d="M4 9h10a6 6 0 0 1 0 12h-3"/>',
  'circuito': '<path d="M4 12a8 8 0 0 1 13.700-5.600L20 9"/><path d="M20 4v5h-5"/><path d="M20 12a8 8 0 0 1-13.700 5.600L4 15"/><path d="M4 20v-5h5"/>',
  'baixar': '<path d="M12 4v11"/><path d="M7 11l5 5 5-5"/><path d="M4 20h16"/>',
  'alvo': '<circle cx="12" cy="12" r="7"/><circle cx="12" cy="12" r="2"/><path d="M12 2v3"/><path d="M12 19v3"/><path d="M2 12h3"/><path d="M19 12h3"/>',
  'curtir': '<path d="M12 20.5s-8.5-5-8.5-11A4.8 4.8 0 0 1 12 6.6a4.8 4.8 0 0 1 8.5 2.9c0 6-8.5 11-8.5 11z"/>',
  'comentar': '<path d="M21 12a8.5 8.5 0 0 1-12.6 7.4L3 21l1.6-5.4A8.5 8.5 0 1 1 21 12z"/>',
  'local':
      '<path d="M12 21.5s7.5-6.5 7.5-12a7.5 7.5 0 1 0-15 0c0 5.5 7.5 12 7.5 12z"/><circle cx="12" cy="9.5" r="2.5"/>',
  'tempo': '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3.5 2"/>',
  'altimetria': '<path d="M2.5 20L9 8l4 7 2.5-4 6 9z"/>',
  'pace': '<path d="M4.5 18a9 9 0 1 1 15 0"/><path d="M12 14l4-5"/><circle cx="12" cy="14" r="1"/>',
  'rota': '<circle cx="6" cy="19" r="2.5"/><circle cx="18" cy="5" r="2.5"/><path d="M8.5 19H15a3.5 3.5 0 0 0 0-7H9a3.5 3.5 0 0 1 0-7h6.5"/>',
  'recorde': '<path d="M7 4h10v6a5 5 0 0 1-10 0z"/><path d="M7 6H3.5v2A3.5 3.5 0 0 0 7 11.5"/><path d="M17 6h3.5v2a3.5 3.5 0 0 1-3.5 3.5"/><path d="M12 15v4"/><path d="M8 21h8"/>',
  'buscar': '<circle cx="11" cy="11" r="7"/><path d="M16.2 16.2L21 21"/>',
  'avancar': '<path d="M9 5l7 7-7 7"/>',
  'voltar': '<path d="M20 12H4"/><path d="M10 6l-6 6 6 6"/>',
  'seta': '<path d="M4 12h16"/><path d="M14 6l6 6-6 6"/>',
  'notificacao': '<path d="M6 9a6 6 0 0 1 12 0c0 6 2.5 8 2.5 8h-17S6 15 6 9z"/><path d="M10 20.5a2.2 2.2 0 0 0 4 0"/>',
  'largada': '<path d="M5 22V4"/><path d="M5 4h13l-2.5 4.5L18 13H5"/>',
  'inscricao': '<path d="M3 8a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v2.5a1.5 1.5 0 0 0 0 3V16a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-2.5a1.5 1.5 0 0 0 0-3z"/><path d="M14 6v12"/>',
  'confirmar': '<path d="M4.5 12.5l5 5 10-11"/>',
  'fechar': '<path d="M6 6l12 12"/><path d="M18 6L6 18"/>',
  'sair': '<path d="M10 4H6a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h4"/><path d="M15 8l4 4-4 4"/><path d="M19 12H9"/>',
  'salvar': '<path d="M6 3h12a1 1 0 0 1 1 1v17l-7-4.5L5 21V4a1 1 0 0 1 1-1z"/>',
  'editar': '<path d="M4 20l1-4L16.5 4.5a2.1 2.1 0 0 1 3 3L8 19z"/><path d="M14.5 6.5l3 3"/>',
  'excluir': '<path d="M4 7h16"/><path d="M9 7V4h6v3"/><path d="M6 7l1 14h10l1-14"/>',
  'email': '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3.5 7l8.5 6 8.5-6"/>',
  'senha': '<rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>',
  'telefone': '<path d="M5 3h4l1.5 5-2.2 1.6a12 12 0 0 0 6.1 6.1L16 13.5l5 1.5v4a2 2 0 0 1-2 2C10.700 21 3 13.300 3 5a2 2 0 0 1 2-2z"/>',
  'foto': '<path d="M3 9a2 2 0 0 1 2-2h2.5L9 4.5h6L16.5 7H19a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><circle cx="12" cy="13" r="3.5"/>',
  'link': '<path d="M10 14a4 4 0 0 0 5.700 0l3-3a4 4 0 0 0-5.700-5.700l-1 1"/><path d="M14 10a4 4 0 0 0-5.700 0l-3 3a4 4 0 0 0 5.700 5.700l1-1"/>',
};

/// Ícones do conjunto próprio (traço de 1,75 px).
class RRIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;
  final bool filled;
  const RRIcon(this.name, {super.key, this.size = 24, this.color, this.filled = false});

  @override
  Widget build(BuildContext context) {
    final fill = filled ? '#000' : 'none';
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="$fill" stroke="#000" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round">${_icons[name]}</svg>',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color ?? context.rr.textPrimary, BlendMode.srcIn),
    );
  }
}

/// Raias: pista oval concêntrica, o grafismo principal da marca.
/// A posição é medida a partir da borda direita ([fromRight]) e do topo ([cy]).
class LanesPainter extends CustomPainter {
  final double fromRight, cy, halfStraight, r0, step, strokeWidth;
  final int count;
  final Color color;

  const LanesPainter({
    required this.color,
    this.fromRight = 0,
    required this.cy,
    this.halfStraight = 0,
    required this.r0,
    required this.step,
    required this.count,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final cx = size.width - fromRight;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    for (var i = 0; i < count; i++) {
      final r = r0 + i * step;
      final rect = Rect.fromLTRB(cx - halfStraight - r, cy - r, cx + halfStraight + r, cy + r);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(r)), paint);
    }
  }

  @override
  bool shouldRepaint(LanesPainter old) => old.color != color || old.cy != cy || old.fromRight != fromRight;
}

/// Raias que se desenham, volta por volta, ao aparecer. Com [shift], acompanham
/// o ponteiro ou a rolagem sem refazer o layout.
class RRLanes extends StatefulWidget {
  final Color color;
  final double fromRight, cy, halfStraight, r0, step, strokeWidth;
  final int count;
  final bool drawIn;
  final Duration duration;
  final ValueListenable<Offset>? shift;

  const RRLanes({
    super.key,
    required this.color,
    this.fromRight = 0,
    required this.cy,
    this.halfStraight = 0,
    required this.r0,
    required this.step,
    required this.count,
    required this.strokeWidth,
    this.drawIn = true,
    this.duration = RRMotion.draw,
    this.shift,
  });

  @override
  State<RRLanes> createState() => _RRLanesState();
}

class _RRLanesState extends State<RRLanes> with SingleTickerProviderStateMixin, RevealOnShow {
  late final _controller = AnimationController(vsync: this, duration: widget.duration);

  @override
  void onShown() {
    if (!widget.drawIn || RRMotion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _DrawnLanesPainter(widget, _controller, Listenable.merge([_controller, ?widget.shift])),
    ),
  );
}

class _DrawnLanesPainter extends CustomPainter {
  final RRLanes lanes;
  final Animation<double> progress;
  _DrawnLanesPainter(this.lanes, this.progress, Listenable repaint) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final shift = lanes.shift?.value ?? Offset.zero;
    final cx = size.width - lanes.fromRight + shift.dx;
    final cy = lanes.cy + shift.dy;
    final paint = Paint()
      ..color = lanes.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = lanes.strokeWidth;
    const lag = .1;
    final total = 1 + lag * (lanes.count - 1);
    for (var i = 0; i < lanes.count; i++) {
      final t = RRMotion.enter.transform(((progress.value * total) - lag * i).clamp(0.0, 1.0));
      if (t <= 0) continue;
      final r = lanes.r0 + i * lanes.step;
      final rect = Rect.fromLTRB(cx - lanes.halfStraight - r, cy - r, cx + lanes.halfStraight + r, cy + r);
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(r));
      if (t >= 1) {
        canvas.drawRRect(rrect, paint);
      } else {
        final path = Path()..addRRect(rrect);
        for (final metric in path.computeMetrics()) {
          canvas.drawPath(metric.extractPath(0, metric.length * t), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_DrawnLanesPainter old) => old.lanes != lanes;
}

/// Curvas de nível com o traçado real por cima, sem baixar mapa. Sem [points], só o
/// fundo: nunca desenhamos um trajeto que o atleta não fez.
/// A rota se desenha ao aparecer e corre de novo quando o ponteiro passa.
class RouteArt extends StatefulWidget {
  /// Pontos [longitude, latitude] do traçado.
  final List<List<double>>? points;
  final double height;
  const RouteArt({super.key, this.points, this.height = 136});

  @override
  State<RouteArt> createState() => _RouteArtState();
}

class _RouteArtState extends State<RouteArt> with SingleTickerProviderStateMixin, RevealOnShow {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void onShown() {
    if (RRMotion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  void _replay() {
    if (revealed && !RRMotion.reduced(context) && !_controller.isAnimating) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => _replay(),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(RRRadius.md),
      child: ColoredBox(
        color: RRPalette.cal950,
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const RepaintBoundary(child: CustomPaint(painter: _ContourPainter())),
              if (widget.points != null && widget.points!.length >= 2)
                RepaintBoundary(child: CustomPaint(painter: _RoutePainter(widget.points!, _controller))),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ContourPainter extends CustomPainter {
  const _ContourPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final cx = size.width / 2, y = size.height / 2;
    final contour = Paint()
      ..color = RRPalette.cal50.withValues(alpha: .14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 1; i <= 11; i++) {
      final p = Path();
      for (var k = 0; k <= 72; k++) {
        final a = k / 72 * math.pi * 2;
        final w = 1 + .09 * math.sin(a * 3 + i * .8) + .06 * math.cos(a * 2 + i * .5) + .03 * math.sin(a * 5 + i * 1.3);
        final x = cx + 44 * i * w * math.cos(a), yy = y + 4 + 22 * i * w * math.sin(a);
        k == 0 ? p.moveTo(x, yy) : p.lineTo(x, yy);
      }
      canvas.drawPath(p..close(), contour);
    }
  }

  @override
  bool shouldRepaint(_ContourPainter old) => false;
}

class _RoutePainter extends CustomPainter {
  final List<List<double>> points;
  final Animation<double> progress;
  _RoutePainter(this.points, this.progress) : super(repaint: progress);

  Size? _cachedSize;
  late Path _route;
  late Offset _start, _end;

  void _build(Size size) {
    final lngs = points.map((p) => p[0]), lats = points.map((p) => p[1]);
    final minLng = lngs.reduce(math.min), maxLng = lngs.reduce(math.max);
    final minLat = lats.reduce(math.min), maxLat = lats.reduce(math.max);
    // Longe do equador, um grau de longitude é mais curto: sem isso o traçado sairia deformado.
    final squeeze = math.cos((minLat + maxLat) / 2 * math.pi / 180);
    final spanX = (maxLng - minLng) * squeeze, spanY = maxLat - minLat;

    final margin = size.width < 120 ? 8.0 : 18.0;
    final room = Size(size.width - margin * 2, size.height - margin * 2);
    final scale = math.min(
      spanX > 0 ? room.width / spanX : double.infinity,
      spanY > 0 ? room.height / spanY : double.infinity,
    );
    // Todos os pontos no mesmo lugar: sem escala, ficam no centro.
    final zoom = scale.isFinite ? scale : 0.0;
    final dx = (size.width - spanX * zoom) / 2, dy = (size.height - spanY * zoom) / 2;
    Offset place(List<double> p) =>
        Offset(dx + (p[0] - minLng) * squeeze * zoom, dy + (maxLat - p[1]) * zoom);

    _start = place(points.first);
    _end = place(points.last);
    _route = Path()..moveTo(_start.dx, _start.dy);
    for (final point in points.skip(1)) {
      final at = place(point);
      _route.lineTo(at.dx, at.dy);
    }
    _cachedSize = size;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (_cachedSize != size) _build(size);
    canvas.clipRect(Offset.zero & size);
    final small = size.width < 120;
    final t = RRMotion.enter.transform(progress.value);
    if (t <= 0) return;

    final line = Paint()
      ..color = RRPalette.tartan500
      ..style = PaintingStyle.stroke
      ..strokeWidth = small ? 2 : 3.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final metrics = _route.computeMetrics().iterator;
    if (!metrics.moveNext()) return;
    final metric = metrics.current;
    final drawn = metric.length * t;
    canvas.drawPath(t >= 1 ? _route : metric.extractPath(0, drawn), line);

    final startRadius = small ? 2.5 : 5.0;
    canvas.drawCircle(_start, startRadius, Paint()..color = RRPalette.cal950);
    canvas.drawCircle(
      _start,
      startRadius,
      Paint()
        ..color = RRPalette.cal50
        ..style = PaintingStyle.stroke
        ..strokeWidth = small ? 1.5 : 2.5,
    );
    // O ponto de chegada é a "cabeça" do corredor ao longo da rota.
    final head = t >= 1 ? _end : metric.getTangentForOffset(drawn)?.position ?? _end;
    canvas.drawCircle(head, small ? 3 : 6, Paint()..color = RRPalette.tartan500);
  }

  @override
  bool shouldRepaint(_RoutePainter old) => old.points != points || old.progress != progress;
}
