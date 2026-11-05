import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/network/api_client.dart';
import '../../../core/motion/rr_motion.dart';
import '../../../core/theme/rr_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/rr_button.dart';
import '../../../core/widgets/rr_feedback.dart';
import '../../../core/widgets/rr_field.dart';
import '../../../core/widgets/rr_labels.dart';
import '../../../core/widgets/rr_layout.dart';
import '../data/race_model.dart';

/// Cadastro de prova, disponível para organizadores e administradores.
class RaceFormScreen extends StatefulWidget {
  const RaceFormScreen({super.key});

  @override
  State<RaceFormScreen> createState() => _RaceFormScreenState();
}

class _RaceFormScreenState extends State<RaceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shakeKey = GlobalKey<RRShakeState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _start = TextEditingController();
  final _city = TextEditingController(text: 'Parauapebas');
  final _state = TextEditingController(text: 'PA');
  final _address = TextEditingController();
  final _elevation = TextEditingController();
  final _link = TextEditingController();
  final _price = TextEditingController();
  final _kitPlace = TextEditingController();
  final _kitDate = TextEditingController();
  final _kitTime = TextEditingController();
  final Set<int> _distances = {};
  String _status = 'inscricoes_abertas';
  DateTime? _date;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _name,
      _description,
      _start,
      _city,
      _state,
      _address,
      _elevation,
      _link,
      _price,
      _kitPlace,
      _kitDate,
      _kitTime,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      _shakeKey.currentState?.shake();
      return;
    }
    if (_date == null) {
      showRRToast(context, 'Escolha a data da prova.', error: true);
      return;
    }
    if (_distances.isEmpty) {
      showRRToast(context, 'Escolha ao menos uma distância.', error: true);
      return;
    }
    setState(() => _saving = true);
    final elevation = int.tryParse(_elevation.text) ?? 0;
    try {
      await RaceService.create({
        'nome': _name.text.trim(),
        'descricao': _description.text.trim(),
        'data': _date!.toIso8601String(),
        'horarioLargada': _start.text.trim(),
        'local': {
          'cidade': _city.text.trim(),
          'estado': _state.text.trim().toUpperCase(),
          'endereco': _address.text.trim(),
        },
        'distancias': [
          for (final km in _distances.toList()..sort())
            {'distanciaKm': km, 'categoria': '${km}K', 'altimetria': elevation},
        ],
        'linkInscricao': _link.text.trim(),
        'preco': _price.text.trim(),
        'retiradaKit': {'local': _kitPlace.text.trim(), 'data': _kitDate.text.trim(), 'horario': _kitTime.text.trim()},
        'status': _status,
      });
      if (!mounted) return;
      showRRToast(context, 'Prova cadastrada!');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) showRRToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    const gap = SizedBox(height: 20);
    String? required(String? v) => v == null || v.trim().isEmpty ? 'Campo obrigatório' : null;
    return RRSubPage(
      title: 'Nova prova',
      maxWidth: 640,
      bottom: RRButton('Cadastrar prova', size: RRButtonSize.l, expand: true, loading: _saving, onPressed: _submit),
      child: Form(
        key: _formKey,
        child: RRShake(
          key: _shakeKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RRField(controller: _name, label: 'Nome da prova', hint: 'Corrida da Serra 2026', validator: required),
              gap,
              RRInfoLine(
                icon: 'calendario',
                title: 'Data da prova',
                value: _date == null ? 'Escolher data' : Fmt.dayMonthYear(_date!),
                onTap: _pickDate,
              ),
              gap,
              RRField(controller: _start, label: 'Horário da largada', hint: '06:00'),
              gap,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: RRField(controller: _city, label: 'Cidade', validator: required),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RRField(controller: _state, label: 'UF', validator: required),
                  ),
                ],
              ),
              gap,
              RRField(controller: _address, label: 'Endereço da largada', hint: 'Praça Central'),
              gap,
              Text('DISTÂNCIAS', style: RRType.monoS.copyWith(color: c.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final km in const [3, 5, 10, 21, 42])
                    RRChip(
                      '${km}K',
                      selected: _distances.contains(km),
                      onTap: () => setState(() => _distances.contains(km) ? _distances.remove(km) : _distances.add(km)),
                    ),
                ],
              ),
              gap,
              RRField(
                controller: _elevation,
                label: 'Elevação (m)',
                hint: '184',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              gap,
              Text('STATUS', style: RRType.monoS.copyWith(color: c.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final key in const ['agendada', 'inscricoes_abertas', 'inscricoes_encerradas'])
                    RRChip(
                      RaceModel.statuses[key]!.$1,
                      selected: _status == key,
                      onTap: () => setState(() => _status = key),
                    ),
                ],
              ),
              gap,
              RRField(
                controller: _link,
                label: 'Link de inscrição',
                hint: 'https://',
                icon: 'link',
                keyboardType: TextInputType.url,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final uri = Uri.tryParse(v.trim());
                  return uri == null || !uri.hasScheme ? 'Use um link completo, com https://' : null;
                },
              ),
              gap,
              RRField(controller: _price, label: 'Valor da inscrição', hint: 'R\$ 80,00'),
              gap,
              RRField(controller: _kitPlace, label: 'Retirada de kit: local', hint: 'Ginásio Municipal'),
              gap,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: RRField(controller: _kitDate, label: 'Retirada: data', hint: '14 de novembro'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RRField(controller: _kitTime, label: 'Retirada: horário', hint: '9h às 18h'),
                  ),
                ],
              ),
              gap,
              RRField(controller: _description, label: 'Sobre a prova', maxLines: 4),
            ],
          ),
        ),
      ),
    );
  }
}
