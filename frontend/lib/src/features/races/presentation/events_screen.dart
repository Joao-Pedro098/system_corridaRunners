import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/rr_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/rr_button.dart';
import '../../../core/widgets/rr_feedback.dart';
import '../../../core/widgets/rr_field.dart';
import '../../../core/widgets/rr_labels.dart';
import '../../../core/widgets/rr_layout.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../data/race_model.dart';
import 'race_form_screen.dart';
import 'race_widgets.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  List<RaceModel> _races = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  DateTime? _month;
  int? _distance;
  Timer? _debounce;

  /// Mês atual e os dois seguintes.
  late final List<DateTime> _months = () {
    final now = DateTime.now();
    return [for (var i = 0; i < 3; i++) DateTime(now.year, now.month + i)];
  }();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final races = await RaceService.list(busca: _query, distancia: _distance, mes: _month?.month, ano: _month?.year);
      if (mounted) setState(() => _races = races);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearch(String value) {
    _query = value.trim();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _load);
  }

  Future<void> _newRace() async {
    final created = await rrPush<bool>(context, const RaceFormScreen());
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    final desktop = RRBreakpoints.isDesktop(context);
    final type = context.select<AuthProvider, String?>((a) => a.user?.tipo);
    final canCreate = type == 'organizador' || type == 'admin';

    final chips = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          RRChip(
            'Todos os meses',
            selected: _month == null,
            onTap: () {
              setState(() => _month = null);
              _load();
            },
          ),
          for (final m in _months) ...[
            const SizedBox(width: 8),
            RRChip(
              Fmt.months[m.month - 1],
              selected: _month == m,
              onTap: () {
                setState(() => _month = _month == m ? null : m);
                _load();
              },
            ),
          ],
          const SizedBox(width: 16),
          for (final km in const [5, 10, 21, 42]) ...[
            RRChip(
              '${km}K',
              selected: _distance == km,
              onTap: () {
                setState(() => _distance = _distance == km ? null : km);
                _load();
              },
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );

    final Widget body;
    if (_loading && _races.isEmpty) {
      body = LayoutBuilder(
        builder: (_, box) {
          final columns = box.maxWidth >= 960 ? 3 : (box.maxWidth >= 620 ? 2 : 1);
          return RRSkeleton(columns: columns, count: columns * 2, height: 340);
        },
      );
    } else if (_error != null) {
      body = RRErrorState(message: _error!, onRetry: _load);
    } else if (_races.isEmpty) {
      body = const RREmptyState(
        title: 'Nenhuma prova nesta rota',
        text: 'Tente outra busca, outro mês ou outra distância.',
      );
    } else {
      body = LayoutBuilder(
        builder: (context, box) => RRGrid(
          columns: box.maxWidth >= 960 ? 3 : (box.maxWidth >= 620 ? 2 : 1),
          gap: desktop ? 20 : 16,
          children: [for (final r in _races) RaceCard(race: r, key: ValueKey(r.id))],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.all(desktop ? 32 : 16),
        children: [
          if (desktop)
            Row(
              children: [
                Expanded(
                  child: Text('CALENDÁRIO DE CORRIDAS', style: RRType.displayM.copyWith(color: c.textPrimary)),
                ),
                if (canCreate) ...[
                  RRButton('Nova prova', icon: 'mais', onPressed: _newRace),
                  const SizedBox(width: 12),
                ],
                RRSearch(onChanged: _onSearch, width: 320),
              ],
            )
          else ...[
            Text('CALENDÁRIO\nDE CORRIDAS', style: RRType.displayM.copyWith(color: c.textPrimary)),
            const SizedBox(height: 16),
            RRSearch(onChanged: _onSearch),
            if (canCreate) ...[
              const SizedBox(height: 12),
              RRButton('Nova prova', icon: 'mais', expand: true, onPressed: _newRace),
            ],
          ],
          const SizedBox(height: 16),
          chips,
          const SizedBox(height: 16),
          body,
        ],
      ),
    );
  }
}
