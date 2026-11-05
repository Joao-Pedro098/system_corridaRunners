import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/motion/rr_motion.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/rr_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/rr_button.dart';
import '../../../core/widgets/rr_feedback.dart';
import '../../../core/widgets/rr_field.dart';
import '../../../core/widgets/rr_labels.dart';
import '../../../core/widgets/rr_layout.dart';
import '../data/race_model.dart';
import 'race_widgets.dart';

/// Cadastro e edição de prova, para organizadores e administradores.
/// Ao salvar, fecha devolvendo a prova atualizada.
class RaceFormScreen extends StatefulWidget {
  final RaceModel? race;
  const RaceFormScreen({super.key, this.race});

  @override
  State<RaceFormScreen> createState() => _RaceFormScreenState();
}

class _RaceFormScreenState extends State<RaceFormScreen> {
  static const _presetKm = <num>[3, 5, 10, 21, 42];
  static const _maxCoverBytes = 5 * 1024 * 1024;

  final _formKey = GlobalKey<FormState>();
  final _shakeKey = GlobalKey<RRShakeState>();
  final _dateKey = GlobalKey();
  final _distanceKey = GlobalKey();

  late final _name = TextEditingController(text: widget.race?.nome);
  late final _description = TextEditingController(text: widget.race?.descricao);
  late final _city = TextEditingController(text: widget.race?.cidade ?? 'Parauapebas');
  late final _state = TextEditingController(text: widget.race?.estado ?? 'PA');
  late final _address = TextEditingController(text: widget.race?.endereco);
  late final _link = TextEditingController(text: widget.race?.linkInscricao);
  late final _price = TextEditingController(text: widget.race?.preco);
  late final _kitPlace = TextEditingController(text: widget.race?.kitLocal);
  late final _kitDate = TextEditingController(text: widget.race?.kitData);
  late final _kitTime = TextEditingController(text: widget.race?.kitHorario);
  late final _regulation = TextEditingController(text: widget.race?.regulamentoUrl);
  late final _contact = TextEditingController(text: widget.race?.organizadorContato);
  late final _results = TextEditingController(text: widget.race?.resultadosUrl);
  late final _gallery = TextEditingController(text: widget.race?.fotosUrl);
  late final _certificate = TextEditingController(text: widget.race?.certificadoUrl);
  final _customKm = TextEditingController();

  /// Distâncias escolhidas, cada uma com o campo da sua elevação.
  final Map<num, TextEditingController> _distances = {};

  late String _status = widget.race?.status ?? 'inscricoes_abertas';
  late DateTime? _date = widget.race?.data;
  // O backend guarda horário vazio como texto vazio.
  late String? _start = (widget.race?.horarioLargada?.isEmpty ?? true) ? null : widget.race!.horarioLargada;
  late String? _coverPath = widget.race?.bannerPath;
  XFile? _coverFile;
  Uint8List? _coverBytes;

  /// Capa já enviada nesta tela: uma nova tentativa não envia de novo.
  String? _uploadedCover;
  bool _saving = false, _showErrors = false;
  late final String _initialSnapshot;

  bool get _editing => widget.race != null;

  List<TextEditingController> get _textControllers => [
    _name,
    _description,
    _city,
    _state,
    _address,
    _link,
    _price,
    _kitPlace,
    _kitDate,
    _kitTime,
    _regulation,
    _contact,
    _results,
    _gallery,
    _certificate,
    ..._distances.values,
  ];

  @override
  void initState() {
    super.initState();
    for (final d in widget.race?.distancias ?? const <RaceDistance>[]) {
      _distances[d.km] = TextEditingController(text: d.altimetria > 0 ? '${d.altimetria}' : '');
    }
    _initialSnapshot = _snapshot();
  }

  @override
  void dispose() {
    for (final c in _textControllers) {
      c.dispose();
    }
    _customKm.dispose();
    super.dispose();
  }

  String _snapshot() => jsonEncode({..._body(), 'novaCapa': _coverFile?.name});

  bool get _hasResultsSection => _status == 'concluida' || _results.text.isNotEmpty;

  List<num> get _sortedKm => _distances.keys.toList()..sort();

  /// Meio-dia evita que o fuso mude o dia da prova.
  String? get _dateIso =>
      _date == null ? null : DateTime(_date!.year, _date!.month, _date!.day, 12).toUtc().toIso8601String();

  Map<String, dynamic> _body() => {
    'nome': _name.text.trim(),
    'descricao': _description.text.trim(),
    'data': _dateIso,
    'horarioLargada': _start ?? '',
    'local': {
      'cidade': _city.text.trim(),
      'estado': _state.text.trim().toUpperCase(),
      'endereco': _address.text.trim(),
    },
    'distancias': [
      for (final km in _sortedKm)
        {
          'distanciaKm': km,
          'categoria': RaceDistance(km: km).label,
          'altimetria': int.tryParse(_distances[km]!.text) ?? 0,
        },
    ],
    'linkInscricao': _link.text.trim(),
    'preco': _price.text.trim(),
    'retiradaKit': {'local': _kitPlace.text.trim(), 'data': _kitDate.text.trim(), 'horario': _kitTime.text.trim()},
    'regulamentoUrl': _regulation.text.trim(),
    'organizador': {'nome': widget.race?.organizadorNome, 'contato': _contact.text.trim()},
    'posCorrida': {
      'linkResultadosChip': _results.text.trim(),
      'linkGaleriaFotos': _gallery.text.trim(),
      'linkCertificado': _certificate.text.trim(),
    },
    'status': _status,
    'bannerUrl': _coverPath ?? '',
  };

  /// A prévia usa os mesmos dados que serão salvos.
  RaceModel _previewModel() => RaceModel(
    id: 'previa',
    nome: _name.text.trim().isEmpty ? 'Nome da prova' : _name.text.trim(),
    status: _status,
    data: _date ?? DateTime.now(),
    horarioLargada: _start,
    cidade: _city.text.trim(),
    estado: _state.text.trim().toUpperCase(),
    bannerPath: _coverPath,
    distancias: [for (final km in _sortedKm) RaceDistance(km: km)],
    participantes: widget.race?.participantes ?? const [],
  );

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Ao editar, a prova pode já ter acontecido.
    final current = _date;
    final first = current != null && current.isBefore(today) ? current : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? today,
      firstDate: first,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final parts = (_start ?? '06:00').split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (picked != null) {
      setState(() => _start = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _pickCover() async {
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1920, imageQuality: 82);
    } on PlatformException {
      if (mounted) showRRToast(context, 'Permita o acesso às fotos para escolher a capa.', error: true);
      return;
    }
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    if (bytes.length > _maxCoverBytes) {
      showRRToast(context, 'A capa pode ter no máximo 5 MB.', error: true);
      return;
    }
    setState(() {
      _coverFile = file;
      _coverBytes = bytes;
      _uploadedCover = null;
    });
  }

  void _removeCover() => setState(() {
    _coverFile = null;
    _coverBytes = null;
    _coverPath = null;
    _uploadedCover = null;
  });

  void _toggleKm(num km) => setState(() {
    final removed = _distances.remove(km);
    if (removed != null) {
      removed.dispose();
    } else {
      _distances[km] = TextEditingController();
    }
  });

  void _addCustomKm() {
    final km = Fmt.decimal(_customKm.text);
    if (km == null || km <= 0 || km > 500) {
      showRRToast(context, 'Informe uma distância entre 0,1 e 500 km.', error: true);
      return;
    }
    final value = km == km.roundToDouble() ? km.toInt() : km;
    setState(() {
      _distances.putIfAbsent(value, TextEditingController.new);
      _customKm.clear();
    });
  }

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Campo obrigatório' : null;

  String? _url(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    final valid = uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
    return valid ? null : 'Use um link completo, com https://';
  }

  void _focusError(BuildContext? target) {
    if (target == null) return;
    Scrollable.ensureVisible(target, alignment: .1, duration: RRMotion.of(context, RRMotion.slow));
  }

  Future<void> _submit() async {
    setState(() => _showErrors = true);
    final invalid = _formKey.currentState!.validateGranularly();
    final missingDate = _date == null;
    final missingDistance = _distances.isEmpty;
    if (invalid.isNotEmpty || missingDate || missingDistance) {
      _shakeKey.currentState?.shake();
      showRRToast(context, 'Confira os campos destacados.', error: true);
      _focusError(
        invalid.isNotEmpty
            ? invalid.first.context
            : missingDate
            ? _dateKey.currentContext
            : _distanceKey.currentContext,
      );
      return;
    }

    setState(() => _saving = true);
    final bus = context.read<RacesBus>();
    try {
      if (_coverFile != null) {
        _uploadedCover ??= await RaceService.uploadCover(_coverFile!);
        _coverPath = _uploadedCover;
      }
      final race = _editing ? await RaceService.update(widget.race!.id, _body()) : await RaceService.create(_body());
      bus.changed();
      if (!mounted) return;
      showRRToast(context, _editing ? 'Prova atualizada!' : 'Prova cadastrada! Já está no calendário.');
      Navigator.pop(context, race);
    } on ApiException catch (e) {
      if (mounted) showRRToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _leave() async {
    if (_snapshot() == _initialSnapshot) {
      Navigator.pop(context);
      return;
    }
    final discard = await showRRConfirm(
      context,
      title: 'Descartar alterações?',
      text: 'O que você preencheu nesta tela será perdido.',
      confirmLabel: 'Descartar',
    );
    if (discard && mounted) Navigator.pop(context);
  }

  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [RRSectionHead(title), const SizedBox(height: 16), ...children],
    ),
  );

  Widget _inlineError(String text) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(text, style: RRType.textS.copyWith(color: context.rr.danger)),
  );

  Widget _coverPicker(RRColors c) {
    final hasCover = _coverBytes != null || _coverPath != null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(RRRadius.lg),
      child: SizedBox(
        height: 168,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RaceCoverBackground(race: _previewModel(), localCover: _coverBytes),
            Positioned(
              right: 8,
              bottom: 8,
              child: Row(
                children: [
                  if (hasCover) ...[
                    RRButton(
                      'Remover',
                      kind: RRButtonKind.onDark,
                      size: RRButtonSize.s,
                      onPressed: _saving ? null : _removeCover,
                    ),
                    const SizedBox(width: 8),
                  ],
                  RRButton(
                    hasCover ? 'Trocar capa' : 'Adicionar capa',
                    size: RRButtonSize.s,
                    icon: 'foto',
                    onPressed: _saving ? null : _pickCover,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    const gap = SizedBox(height: 16);
    final statusKeys = _editing
        ? RaceModel.statuses.keys.toList()
        : const ['agendada', 'inscricoes_abertas', 'inscricoes_encerradas'];
    final presets = {..._presetKm, ..._distances.keys}.toList()..sort();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) _leave();
      },
      child: RRSubPage(
        title: _editing ? 'Editar prova' : 'Nova prova',
        maxWidth: 640,
        bottom: RRButton(
          _editing ? 'Salvar alterações' : 'Publicar no calendário',
          kind: _editing ? RRButtonKind.primary : RRButtonKind.accent,
          size: RRButtonSize.l,
          expand: true,
          loading: _saving,
          onPressed: _submit,
        ),
        child: Form(
          key: _formKey,
          autovalidateMode: _showErrors ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
          child: RRShake(
            key: _shakeKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _section('A prova', [
                  RRField(
                    controller: _name,
                    label: 'Nome da prova',
                    hint: 'Corrida da Serra 2026',
                    onChanged: (_) => setState(() {}),
                    validator: (v) => (v?.trim().length ?? 0) < 3 ? 'Informe o nome, com pelo menos 3 letras' : null,
                  ),
                  gap,
                  _coverPicker(c),
                  const SizedBox(height: 8),
                  Text(
                    'Imagem horizontal em JPG, PNG ou WebP, até 5 MB. Sem capa, usamos a arte da marca.',
                    style: RRType.textS.copyWith(color: c.textSecondary),
                  ),
                  gap,
                  RRField(
                    controller: _description,
                    label: 'Sobre a prova — opcional',
                    hint: 'Percurso, kit, premiação…',
                    maxLines: 4,
                  ),
                ]),
                _section('Data e local', [
                  Row(
                    key: _dateKey,
                    children: [
                      Expanded(
                        child: RRInfoLine(
                          icon: 'calendario',
                          title: 'Data',
                          value: _date == null ? 'Escolher' : Fmt.dayMonthYear(_date!),
                          onTap: _pickDate,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: RRInfoLine(
                          icon: 'tempo',
                          title: 'Largada',
                          value: _start ?? 'Escolher',
                          onTap: _pickTime,
                        ),
                      ),
                    ],
                  ),
                  if (_showErrors && _date == null) _inlineError('Escolha a data da prova'),
                  gap,
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: RRField(
                          controller: _city,
                          label: 'Cidade',
                          onChanged: (_) => setState(() {}),
                          validator: _required,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: RRField(
                          controller: _state,
                          label: 'UF',
                          onChanged: (_) => setState(() {}),
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(2),
                            FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
                          ],
                          validator: (v) => RegExp(r'^[a-zA-Z]{2}$').hasMatch(v?.trim() ?? '') ? null : '2 letras',
                        ),
                      ),
                    ],
                  ),
                  gap,
                  RRField(
                    controller: _address,
                    label: 'Endereço da largada — opcional',
                    hint: 'Praça Central',
                    icon: 'local',
                  ),
                ]),
                Padding(
                  key: _distanceKey,
                  padding: EdgeInsets.zero,
                  child: _section('Distâncias', [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final km in presets)
                          RRChip(
                            RaceDistance(km: km).label,
                            selected: _distances.containsKey(km),
                            onTap: () => _toggleKm(km),
                          ),
                      ],
                    ),
                    if (_showErrors && _distances.isEmpty) _inlineError('Escolha ao menos uma distância'),
                    gap,
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: RRField(
                            controller: _customKm,
                            label: 'Outra distância (km)',
                            hint: '7,5',
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onSubmitted: (_) => _addCustomKm(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: RRButton('Adicionar', kind: RRButtonKind.secondary, onPressed: _addCustomKm),
                        ),
                      ],
                    ),
                    for (final km in _sortedKm) ...[
                      gap,
                      RRField(
                        key: ValueKey('elevacao-$km'),
                        controller: _distances[km]!,
                        label: 'Elevação dos ${RaceDistance(km: km).label} (m) — opcional',
                        hint: '184',
                        icon: 'altimetria',
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ],
                  ]),
                ),
                _section('Inscrições', [
                  Text('STATUS', style: RRType.monoS.copyWith(color: c.textSecondary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final key in statusKeys)
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
                    label: 'Link de inscrição — opcional',
                    hint: 'https://',
                    icon: 'link',
                    keyboardType: TextInputType.url,
                    validator: _url,
                  ),
                  gap,
                  RRField(controller: _price, label: 'Valor da inscrição — opcional', hint: 'R\$ 80,00'),
                  gap,
                  RRField(
                    controller: _regulation,
                    label: 'Link do regulamento — opcional',
                    hint: 'https://',
                    icon: 'noticias',
                    keyboardType: TextInputType.url,
                    validator: _url,
                  ),
                  gap,
                  RRField(
                    controller: _contact,
                    label: 'Contato da organização — opcional',
                    hint: '(94) 99999-9999',
                    icon: 'telefone',
                  ),
                ]),
                _section('Retirada de kit', [
                  RRField(controller: _kitPlace, label: 'Local — opcional', hint: 'Ginásio Municipal', icon: 'local'),
                  gap,
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: RRField(controller: _kitDate, label: 'Data — opcional', hint: '14 de novembro'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: RRField(controller: _kitTime, label: 'Horário — opcional', hint: '9h às 18h'),
                      ),
                    ],
                  ),
                ]),
                // Resultados só fazem sentido depois da prova.
                AnimatedSize(
                  duration: RRMotion.of(context, RRMotion.base),
                  curve: RRMotion.enter,
                  alignment: Alignment.topCenter,
                  child: _hasResultsSection
                      ? _section('Depois da prova', [
                          RRField(
                            controller: _results,
                            label: 'Resultados — opcional',
                            hint: 'https://',
                            icon: 'tempo',
                            keyboardType: TextInputType.url,
                            validator: _url,
                          ),
                          gap,
                          RRField(
                            controller: _gallery,
                            label: 'Galeria de fotos — opcional',
                            hint: 'https://',
                            icon: 'foto',
                            keyboardType: TextInputType.url,
                            validator: _url,
                          ),
                          gap,
                          RRField(
                            controller: _certificate,
                            label: 'Certificado — opcional',
                            hint: 'https://',
                            icon: 'recorde',
                            keyboardType: TextInputType.url,
                            validator: _url,
                          ),
                        ])
                      : const SizedBox(width: double.infinity),
                ),
                const RRSectionHead('Como vai aparecer'),
                const SizedBox(height: 12),
                IgnorePointer(
                  child: ExcludeSemantics(
                    child: RaceCard(race: _previewModel(), localCover: _coverBytes, previewOnly: true),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
