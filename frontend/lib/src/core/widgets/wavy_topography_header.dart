import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Clipper para criar a borda inferior orgânica em onda, igual à imagem de referência
class TopoWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);

    // Curva Bezier criando a onda suave
    final firstControlPoint = Offset(size.width * 0.35, size.height + 25);
    final firstEndPoint = Offset(size.width * 0.65, size.height - 30);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );

    final secondControlPoint = Offset(size.width * 0.85, size.height - 70);
    final secondEndPoint = Offset(size.width, size.height - 15);
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

/// Painter que desenha as curvas de nível topográficas (linhas de elevação/terreno de corrida)
class TopographyLinesPainter extends CustomPainter {
  final Color lineColor;

  TopographyLinesPainter({
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..isAntiAlias = true;

    final centerX = size.width * 0.55;
    final centerY = size.height * 0.40;

    // Desenha anéis topográficos concêntricos com pequenas variações orgânicas
    for (int i = 1; i <= 7; i++) {
      final radiusX = (size.width * 0.16) * i;
      final radiusY = (size.height * 0.13) * i;

      final path = Path();
      const pointsCount = 36;
      for (int p = 0; p <= pointsCount; p++) {
        final angle = (p / pointsCount) * 2 * math.pi;
        // Modulação sinusoidal para dar o formato de contorno de terreno natural
        final wobble = 1.0 + 0.08 * math.sin(angle * 3 + i * 0.8) + 0.05 * math.cos(angle * 2);
        final x = centerX + radiusX * wobble * math.cos(angle);
        final y = centerY + radiusY * wobble * math.sin(angle);

        if (p == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    }

    // Linha de contorno externa secundária no canto superior direito
    final cornerPaint = Paint()
      ..color = lineColor.withValues(alpha: lineColor.a * 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int j = 1; j <= 4; j++) {
      final path2 = Path();
      path2.addOval(
        Rect.fromCircle(
          center: Offset(size.width * 0.9, size.height * 0.15),
          radius: 25.0 * j,
        ),
      );
      canvas.drawPath(path2, cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Widget completo que renderiza o cabeçalho ondulado com textura topográfica azul
class WavyTopographyHeader extends StatelessWidget {
  final double height;
  final Widget? child;

  const WavyTopographyHeader({
    super.key,
    required this.height,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: TopoWaveClipper(),
      child: Container(
        height: height,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2563EB), // Azul Real Vibrante
              Color(0xFF1D4ED8), // Azul Esportivo
              Color(0xFF1E40AF), // Azul Noturno
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Textura topográfica
            Positioned.fill(
              child: CustomPaint(
                painter: TopographyLinesPainter(
                  lineColor: Colors.white.withValues(alpha: 0.14),
                ),
              ),
            ),
            // Brilho sutil radial
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryLight.withValues(alpha: 0.18),
                ),
              ),
            ),
            // Conteúdo opcional (ícone, títulos)
            if (child != null) Positioned.fill(child: child!),
          ],
        ),
      ),
    );
  }
}
