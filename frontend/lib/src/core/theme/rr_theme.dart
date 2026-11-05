import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Primitivos do design system "Corra a sua rota" (mesmos valores do Figma).
class RRPalette {
  RRPalette._();

  static const cal0 = Color(0xFFFFFFFF);
  static const cal50 = Color(0xFFFAF9F5);
  static const cal100 = Color(0xFFF4F2EC);
  static const cal200 = Color(0xFFE7E4DB);
  static const cal300 = Color(0xFFD2CEC2);
  static const cal400 = Color(0xFFA8A498);
  static const cal500 = Color(0xFF6E6B60);
  static const cal600 = Color(0xFF5C5A51);
  static const cal700 = Color(0xFF3F3E37);
  static const cal800 = Color(0xFF2A2A25);
  static const cal900 = Color(0xFF1A1B18);
  static const cal950 = Color(0xFF111311);

  static const tartan100 = Color(0xFFFFE0D5);
  static const tartan200 = Color(0xFFFFBFA8);
  static const tartan300 = Color(0xFFFF9672);
  static const tartan400 = Color(0xFFFF6F43);
  static const tartan500 = Color(0xFFFF4B1F);
  static const tartan700 = Color(0xFFB8290A);
  static const tartan900 = Color(0xFF5F190A);

  static const mata100 = Color(0xFFDCEBE4);
  static const mata300 = Color(0xFF8FC2AD);
  static const mata700 = Color(0xFF1F4D3F);
  static const mata900 = Color(0xFF0F2A22);

  static const ceu100 = Color(0xFFE3F0F7);
  static const ceu300 = Color(0xFFB9D7E8);
  static const ceu700 = Color(0xFF1F6C93);
  static const ceu900 = Color(0xFF0F3A52);

  static const ambar100 = Color(0xFFFBEFD0);
  static const ambar300 = Color(0xFFF0C968);
  static const ambar700 = Color(0xFF8A5F0A);
  static const ambar900 = Color(0xFF33240A);

  static const carmim100 = Color(0xFFFBE4E8);
  static const carmim300 = Color(0xFFF49AAA);
  static const carmim700 = Color(0xFFA81236);
  static const carmim900 = Color(0xFF3B0A16);
}

/// Tons de etiqueta do design system.
enum RRTone { ceu, mata, tartan, ambar, carmim, neutro }

/// Tokens semânticos, com um valor para cada tema.
@immutable
class RRColors extends ThemeExtension<RRColors> {
  final Color canvas, surface, raised, subtle, inverse;
  final Color border, borderStrong;
  final Color textPrimary, textSecondary, textMuted, textInverse, textLink;
  final Color action, actionHover, onAction;
  final Color accent, accentHover, onAccent, accentText;
  final Color logo, danger, success;
  final Map<RRTone, (Color, Color)> tags;

  const RRColors({
    required this.canvas,
    required this.surface,
    required this.raised,
    required this.subtle,
    required this.inverse,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textInverse,
    required this.textLink,
    required this.action,
    required this.actionHover,
    required this.onAction,
    required this.accent,
    required this.accentHover,
    required this.onAccent,
    required this.accentText,
    required this.logo,
    required this.danger,
    required this.success,
    required this.tags,
  });

  static const light = RRColors(
    canvas: RRPalette.cal50,
    surface: RRPalette.cal0,
    raised: RRPalette.cal0,
    subtle: RRPalette.cal100,
    inverse: RRPalette.cal950,
    border: RRPalette.cal200,
    borderStrong: RRPalette.cal300,
    textPrimary: RRPalette.cal950,
    textSecondary: RRPalette.cal600,
    textMuted: RRPalette.cal500,
    textInverse: RRPalette.cal50,
    textLink: RRPalette.tartan700,
    action: RRPalette.cal950,
    actionHover: RRPalette.cal800,
    onAction: RRPalette.cal50,
    accent: RRPalette.tartan500,
    accentHover: RRPalette.tartan400,
    onAccent: RRPalette.cal950,
    accentText: RRPalette.tartan700,
    logo: RRPalette.cal950,
    danger: RRPalette.carmim700,
    success: RRPalette.mata700,
    tags: {
      RRTone.ceu: (RRPalette.ceu100, RRPalette.ceu700),
      RRTone.mata: (RRPalette.mata100, RRPalette.mata700),
      RRTone.tartan: (RRPalette.tartan100, RRPalette.tartan700),
      RRTone.ambar: (RRPalette.ambar100, RRPalette.ambar700),
      RRTone.carmim: (RRPalette.carmim100, RRPalette.carmim700),
      RRTone.neutro: (RRPalette.cal200, RRPalette.cal700),
    },
  );

  static const dark = RRColors(
    canvas: RRPalette.cal950,
    surface: RRPalette.cal900,
    raised: RRPalette.cal800,
    subtle: RRPalette.cal800,
    inverse: RRPalette.cal50,
    border: RRPalette.cal700,
    borderStrong: RRPalette.cal600,
    textPrimary: RRPalette.cal50,
    textSecondary: RRPalette.cal300,
    textMuted: RRPalette.cal400,
    textInverse: RRPalette.cal950,
    textLink: RRPalette.tartan300,
    action: RRPalette.cal50,
    actionHover: RRPalette.cal200,
    onAction: RRPalette.cal950,
    accent: RRPalette.tartan500,
    accentHover: RRPalette.tartan400,
    onAccent: RRPalette.cal950,
    accentText: RRPalette.tartan300,
    logo: RRPalette.cal50,
    danger: RRPalette.carmim300,
    success: RRPalette.mata300,
    tags: {
      RRTone.ceu: (RRPalette.ceu900, RRPalette.ceu300),
      RRTone.mata: (RRPalette.mata900, RRPalette.mata300),
      RRTone.tartan: (RRPalette.tartan900, RRPalette.tartan200),
      RRTone.ambar: (RRPalette.ambar900, RRPalette.ambar300),
      RRTone.carmim: (RRPalette.carmim900, RRPalette.carmim300),
      RRTone.neutro: (RRPalette.cal700, RRPalette.cal200),
    },
  );

  @override
  RRColors copyWith() => this;

  @override
  RRColors lerp(ThemeExtension<RRColors>? other, double t) {
    if (other is! RRColors) return this;
    Color m(Color a, Color b) => Color.lerp(a, b, t)!;
    return RRColors(
      canvas: m(canvas, other.canvas),
      surface: m(surface, other.surface),
      raised: m(raised, other.raised),
      subtle: m(subtle, other.subtle),
      inverse: m(inverse, other.inverse),
      border: m(border, other.border),
      borderStrong: m(borderStrong, other.borderStrong),
      textPrimary: m(textPrimary, other.textPrimary),
      textSecondary: m(textSecondary, other.textSecondary),
      textMuted: m(textMuted, other.textMuted),
      textInverse: m(textInverse, other.textInverse),
      textLink: m(textLink, other.textLink),
      action: m(action, other.action),
      actionHover: m(actionHover, other.actionHover),
      onAction: m(onAction, other.onAction),
      accent: m(accent, other.accent),
      accentHover: m(accentHover, other.accentHover),
      onAccent: m(onAccent, other.onAccent),
      accentText: m(accentText, other.accentText),
      logo: m(logo, other.logo),
      danger: m(danger, other.danger),
      success: m(success, other.success),
      tags: {
        for (final tone in RRTone.values)
          tone: (m(tags[tone]!.$1, other.tags[tone]!.$1), m(tags[tone]!.$2, other.tags[tone]!.$2)),
      },
    );
  }
}

extension RRContext on BuildContext {
  RRColors get rr => Theme.of(this).extension<RRColors>()!;
}

/// Escala tipográfica do Figma. Os estilos "Display", "Título/L", "Título/M" e
/// "Mono" são exibidos em caixa alta: use `.toUpperCase()` no texto.
class RRType {
  RRType._();

  static TextStyle _d(double s, double lh, FontWeight w) =>
      GoogleFonts.bigShoulders(fontSize: s, height: lh / s, fontWeight: w);
  static TextStyle _b(double s, double lh, FontWeight w) =>
      GoogleFonts.hankenGrotesk(fontSize: s, height: lh / s, fontWeight: w);
  static TextStyle _m(double s, double lh, double ls) =>
      GoogleFonts.dmMono(fontSize: s, height: lh / s, fontWeight: FontWeight.w500, letterSpacing: s * ls);

  static final displayXL = _d(96, 88, FontWeight.w800);
  static final displayL = _d(72, 66, FontWeight.w800);
  static final displayM = _d(56, 52, FontWeight.w800);
  static final displayS = _d(40, 38, FontWeight.w800);
  static final titleL = _d(32, 32, FontWeight.w700);
  static final titleM = _d(24, 26, FontWeight.w700);
  static final titleS = _b(18, 24, FontWeight.w600);
  static final textL = _b(16, 24, FontWeight.w400);
  static final textM = _b(14, 20, FontWeight.w400);
  static final textS = _b(12, 16, FontWeight.w400);
  static final labelL = _b(16, 20, FontWeight.w600);
  static final labelM = _b(14, 18, FontWeight.w600);
  static final labelS = _b(12, 16, FontWeight.w600);
  static final monoM = _m(13, 16, .02);
  static final monoS = _m(11, 14, .06);
  static final dataXL = _d(72, 66, FontWeight.w800);
  static final dataL = _d(40, 38, FontWeight.w800);
  static final dataM = _d(26, 26, FontWeight.w800);
  static final wordmark = GoogleFonts.bigShoulders(fontWeight: FontWeight.w900, height: 1);

  /// Título de impacto (telas de abertura e capas de prova).
  static TextStyle hero(double size, double lineHeight) => _d(size, lineHeight, FontWeight.w800);
}

class RRRadius {
  RRRadius._();
  static const sm = 4.0, md = 8.0, lg = 12.0, xl = 16.0, full = 999.0;
}

class RRShadow {
  RRShadow._();
  static const _c = Color(0xFF121210);
  static List<BoxShadow> get e2 => [
    BoxShadow(color: _c.withValues(alpha: .1), offset: const Offset(0, 8), blurRadius: 24, spreadRadius: -6),
    BoxShadow(color: _c.withValues(alpha: .04), offset: const Offset(0, 1), blurRadius: 2),
  ];
}

/// Pontos de quebra da aplicação.
class RRBreakpoints {
  RRBreakpoints._();
  static const desktop = 900.0;
  static const wide = 1240.0;
  static bool isDesktop(BuildContext c) => MediaQuery.sizeOf(c).width >= desktop;
}

ThemeData buildRRTheme(Brightness brightness) {
  final c = brightness == Brightness.light ? RRColors.light : RRColors.dark;
  final base = ThemeData(brightness: brightness, useMaterial3: true);
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(RRRadius.md),
    borderSide: BorderSide(color: color, width: width),
  );

  return base.copyWith(
    scaffoldBackgroundColor: c.canvas,
    canvasColor: c.canvas,
    dividerColor: c.border,
    extensions: [c],
    textTheme: base.textTheme.apply(
      fontFamily: GoogleFonts.hankenGrotesk().fontFamily,
      bodyColor: c.textPrimary,
      displayColor: c.textPrimary,
    ),
    colorScheme: ColorScheme.fromSeed(seedColor: RRPalette.tartan500, brightness: brightness).copyWith(
      primary: c.action,
      onPrimary: c.onAction,
      secondary: c.accent,
      onSecondary: c.onAccent,
      surface: c.surface,
      onSurface: c.textPrimary,
      surfaceContainerHigh: c.raised,
      error: c.danger,
      outline: c.borderStrong,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.textPrimary,
      selectionColor: c.accent.withValues(alpha: .3),
      selectionHandleColor: c.accent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      hintStyle: RRType.textL.copyWith(color: c.textMuted),
      errorStyle: RRType.textS.copyWith(color: c.danger),
      helperStyle: RRType.textS.copyWith(color: c.textSecondary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      enabledBorder: border(c.borderStrong, 1),
      focusedBorder: border(c.textPrimary, 2),
      errorBorder: border(c.danger, 2),
      focusedErrorBorder: border(c.danger, 2),
      disabledBorder: border(c.border, 1),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.action : Colors.transparent,
      ),
      checkColor: WidgetStateProperty.all(c.onAction),
      side: BorderSide(color: c.borderStrong),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RRRadius.sm)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.onAccent : c.textMuted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.accent : c.subtle),
      trackOutlineColor: WidgetStateProperty.all(c.borderStrong),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.raised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RRRadius.xl)),
    ),
  );
}
