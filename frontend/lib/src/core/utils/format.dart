/// Formatação em português do Brasil usada nas telas.
class Fmt {
  Fmt._();

  static const months = [
    'Janeiro',
    'Fevereiro',
    'Março',
    'Abril',
    'Maio',
    'Junho',
    'Julho',
    'Agosto',
    'Setembro',
    'Outubro',
    'Novembro',
    'Dezembro',
  ];

  static String monthShort(int m) => months[m - 1].substring(0, 3);

  static String _two(int n) => n.toString().padLeft(2, '0');

  /// 18.2 -> "18,2"
  static String km(num value) => value.toStringAsFixed(1).replaceAll('.', ',');

  /// 1284 -> "1.284"
  static String thousands(num value) {
    final s = value.round().toString();
    return s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => '.');
  }

  /// "00:52:30" -> "52:30" e "01:38:04" -> "1:38:04"
  static String time(String value) {
    final parts = value.split(':');
    if (parts.length == 3 && parts[0] == '00') return parts.sublist(1).join(':');
    return value.replaceFirst(RegExp(r'^0(?=\d)'), '');
  }

  /// "05:15 min/km" -> "5:15"
  static String pace(String value) => value.split(' ').first.replaceFirst(RegExp(r'^0(?=\d)'), '');

  /// "Hoje, 06:12", "Ontem, 18:40" ou "12 Nov, 06:30"
  static String relative(DateTime date, [DateTime? now]) {
    final d = date.toLocal();
    final n = now ?? DateTime.now();
    final days = DateTime(n.year, n.month, n.day).difference(DateTime(d.year, d.month, d.day)).inDays;
    final hour = '${_two(d.hour)}:${_two(d.minute)}';
    if (days == 0) return 'Hoje, $hour';
    if (days == 1) return 'Ontem, $hour';
    return '${_two(d.day)} ${monthShort(d.month)}, $hour';
  }

  static String dayMonthYear(DateTime date) {
    final d = date.toLocal();
    return '${d.day} de ${months[d.month - 1].toLowerCase()} de ${d.year}';
  }

  /// "10,5" ou "10.5" -> 10.5
  static double? decimal(String value) => double.tryParse(value.trim().replaceAll(',', '.'));

  /// Segundos e distância -> "5:23"
  static String paceFrom(double km, int seconds) {
    if (km <= 0 || seconds <= 0) return '--:--';
    final perKm = (seconds / km).round();
    return '${perKm ~/ 60}:${_two(perKm % 60)}';
  }

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final last = parts.length > 1 ? parts.last[0] : '';
    return (parts.first[0] + last).toUpperCase();
  }

  static String firstName(String name) => name.trim().split(RegExp(r'\s+')).first;

  static String greeting([DateTime? now]) {
    final h = (now ?? DateTime.now()).hour;
    if (h < 12) return 'Bom dia';
    if (h < 18) return 'Boa tarde';
    return 'Boa noite';
  }
}
