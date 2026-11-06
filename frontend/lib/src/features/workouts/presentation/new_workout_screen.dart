import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/brand/rr_brand.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/motion/rr_motion.dart';
import '../../../core/theme/rr_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/rr_button.dart';
import '../../../core/widgets/rr_feedback.dart';
import '../../../core/widgets/rr_field.dart';
import '../../../core/widgets/rr_labels.dart';
import '../../../core/widgets/rr_layout.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../data/workout_model.dart';
import 'workouts_provider.dart';

/// Formulário de treino: publica um novo ou, com [workout], edita o existente.
class NewWorkoutScreen extends StatefulWidget {
  final WorkoutModel? workout;
  const NewWorkoutScreen({super.key, this.workout});

  @override
  State<NewWorkoutScreen> createState() => _NewWorkoutScreenState();
}

class _NewWorkoutScreenState extends State<NewWorkoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shakeKey = GlobalKey<RRShakeState>();
  final _title = TextEditingController();
  final _distance = TextEditingController();
  final _hours = TextEditingController();
  final _minutes = TextEditingController();
  final _seconds = TextEditingController();
  final _elevation = TextEditingController();
  final _description = TextEditingController();
  String _type = 'rodagem';
  int _effort = 3;
  DateTime _date = DateTime.now();
  bool _saving = false;

  static const _maxPhotos = 4;
  static const _maxPhotoBytes = 5 * 1024 * 1024;
  final List<_PickedPhoto> _photos = [];

  /// Fotos que o treino já tinha e continuam nele.
  final List<String> _existing = [];

  /// Caminhos já enviados: se publicar falhar, a nova tentativa não reenvia.
  List<String>? _uploaded;

  int get _photoCount => _existing.length + _photos.length;

  @override
  void initState() {
    super.initState();
    final w = widget.workout;
    if (w == null) return;
    String pad(int value) => value.toString().padLeft(2, '0');
    final km = w.distanciaKm;
    _title.text = w.titulo;
    _distance.text = (km == km.roundToDouble() ? km.toInt() : km).toString().replaceAll('.', ',');
    _hours.text = pad(w.duracaoSegundos ~/ 3600);
    _minutes.text = pad(w.duracaoSegundos % 3600 ~/ 60);
    _seconds.text = pad(w.duracaoSegundos % 60);
    if (w.altimetria > 0) _elevation.text = '${w.altimetria}';
    _description.text = w.descricao;
    _type = w.tipoTreino;
    _effort = w.effortLevel;
    _date = w.dataTreino.toLocal();
    _existing.addAll(w.fotos);
  }

  @override
  void dispose() {
    for (final c in [_title, _distance, _hours, _minutes, _seconds, _elevation, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _totalSeconds {
    int v(TextEditingController c) => int.tryParse(c.text) ?? 0;
    return v(_hours) * 3600 + v(_minutes) * 60 + v(_seconds);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final oldest = DateTime(now.year - 5);
    // Um treino já salvo pode estar fora desse intervalo, e o calendário exige que a data caiba nele.
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: _date.isBefore(oldest) ? _date : oldest,
      lastDate: _date.isAfter(now) ? _date : now,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickPhotos() async {
    final remaining = _maxPhotos - _photoCount;
    final List<XFile> picked;
    try {
      picked = await ImagePicker().pickMultiImage(
        limit: remaining > 1 ? remaining : null,
        maxWidth: 1600,
        imageQuality: 80,
      );
    } on PlatformException {
      if (mounted) {
        showRRToast(context, 'Permita o acesso às fotos para adicionar imagens.', error: true);
      }
      return;
    }
    if (picked.isEmpty) return;

    final added = <_PickedPhoto>[];
    var tooBig = false;
    for (final file in picked.take(remaining)) {
      final bytes = await file.readAsBytes();
      if (bytes.length > _maxPhotoBytes) {
        tooBig = true;
      } else {
        added.add(_PickedPhoto(file, bytes));
      }
    }
    if (!mounted) return;
    setState(() {
      _photos.addAll(added);
      _uploaded = null;
    });
    if (tooBig) {
      showRRToast(context, 'Cada foto pode ter no máximo 5 MB.', error: true);
    } else if (picked.length > remaining) {
      showRRToast(context, 'Cada treino pode ter até $_maxPhotos fotos.', icon: 'foto');
    }
  }

  void _removePhoto(int index) => setState(() {
    _photos.removeAt(index);
    _uploaded = null;
  });

  Widget _photoTile({required Key key, required Widget image, required int number, required VoidCallback onRemove}) {
    return TweenAnimationBuilder<double>(
      key: key,
      tween: Tween(begin: RRMotion.reduced(context) ? 1 : .7, end: 1),
      duration: RRMotion.of(context, RRMotion.base),
      curve: RRMotion.pop,
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: SizedBox(
        width: _photoSize,
        height: _photoSize,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(RRRadius.md), child: image),
            Align(
              alignment: Alignment.topRight,
              // Círculo discreto, mas com área de toque de 44 px.
              child: Tooltip(
                message: 'Remover foto $number',
                child: Semantics(
                  button: true,
                  label: 'Remover foto $number',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _saving ? null : onRemove,
                    child: SizedBox.square(
                      dimension: 44,
                      child: Align(
                        alignment: Alignment.topRight,
                        child: Container(
                          width: 24,
                          height: 24,
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: RRPalette.cal950.withValues(alpha: .82),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(child: RRIcon('fechar', size: 14, color: RRPalette.cal50)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _photoSize = 96.0;

  Widget _photoPicker(RRColors c) {
    const size = _photoSize;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('FOTOS — OPCIONAL', style: RRType.monoS.copyWith(color: c.textSecondary)),
            Text('$_photoCount DE $_maxPhotos', style: RRType.monoS.copyWith(color: c.textMuted)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (i, path) in _existing.indexed)
              _photoTile(
                key: ValueKey(path),
                image: Image.network(
                  ApiConstants.mediaUrl(path),
                  fit: BoxFit.cover,
                  semanticLabel: 'Foto ${i + 1}',
                  errorBuilder: (_, _, _) => ColoredBox(color: c.border),
                ),
                number: i + 1,
                onRemove: () => setState(() => _existing.removeAt(i)),
              ),
            for (var i = 0; i < _photos.length; i++)
              _photoTile(
                key: ObjectKey(_photos[i]),
                image: Image.memory(
                  _photos[i].bytes,
                  fit: BoxFit.cover,
                  semanticLabel: 'Foto ${_existing.length + i + 1}',
                ),
                number: _existing.length + i + 1,
                onRemove: () => _removePhoto(i),
              ),
            if (_photoCount < _maxPhotos)
              Semantics(
                button: true,
                label: 'Adicionar fotos',
                child: Material(
                  color: c.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(RRRadius.md),
                    side: BorderSide(color: c.borderStrong),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _saving ? null : _pickPhotos,
                    child: SizedBox(
                      width: size,
                      height: size,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          RRIcon('foto', color: c.textSecondary),
                          const SizedBox(height: 6),
                          Text('Adicionar', style: RRType.labelS.copyWith(color: c.textPrimary)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text('JPG, PNG ou WebP, até 5 MB cada.', style: RRType.textS.copyWith(color: c.textSecondary)),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      _shakeKey.currentState?.shake();
      return;
    }
    if (_totalSeconds <= 0) {
      _shakeKey.currentState?.shake();
      showRRToast(context, 'Informe o tempo do treino.', error: true);
      return;
    }
    setState(() => _saving = true);
    final workouts = context.read<WorkoutsProvider>();
    final auth = context.read<AuthProvider>();
    try {
      if (_photos.isNotEmpty) {
        _uploaded ??= await workouts.uploadPhotos(_photos.map((p) => p.file).toList());
      }
      final body = <String, dynamic>{
        'titulo': _title.text.trim(),
        'descricao': _description.text.trim(),
        'tipoTreino': _type,
        'distanciaKm': Fmt.decimal(_distance.text),
        'duracaoSegundos': _totalSeconds,
        'altimetria': int.tryParse(_elevation.text) ?? 0,
        'sensacaoEsforco': WorkoutModel.efforts[_effort - 1],
        'dataTreino': _date.toIso8601String(),
        'fotos': [..._existing, ...?_uploaded],
      };
      final editing = widget.workout;
      if (editing != null) {
        await workouts.update(editing, body);
      } else {
        await workouts.publish(body);
      }
      await auth.refreshUser();
      if (!mounted) return;
      showRRToast(context, editing != null ? 'Treino atualizado!' : 'Treino publicado!');
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) showRRToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _timeField(TextEditingController controller, String label) => Expanded(
    child: RRField(
      controller: controller,
      label: label,
      hint: '00',
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
      onChanged: (_) => setState(() {}),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    final km = Fmt.decimal(_distance.text) ?? 0;
    return RRSubPage(
      title: widget.workout != null ? 'Editar treino' : 'Publicar treino',
      maxWidth: 640,
      bottom: RRButton(
        widget.workout != null ? 'Salvar alterações' : 'Publicar treino',
        kind: RRButtonKind.primary,
        size: RRButtonSize.l,
        expand: true,
        loading: _saving,
        onPressed: _submit,
      ),
      child: Form(
        key: _formKey,
        child: RRShake(
          key: _shakeKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RRField(
                controller: _title,
                label: 'Título',
                hint: 'Longão de domingo na orla',
                validator: (v) => v == null || v.trim().isEmpty ? 'Dê um título ao treino' : null,
              ),
              const SizedBox(height: 20),
              _photoPicker(c),
              const SizedBox(height: 20),
              Text('TIPO DE TREINO', style: RRType.monoS.copyWith(color: c.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in WorkoutModel.types.entries)
                    RRChip(
                      entry.value.$1,
                      selected: _type == entry.key,
                      onTap: () => setState(() => _type = entry.key),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              RRField(
                controller: _distance,
                label: 'Distância (km)',
                hint: '10,5',
                helper: 'Use vírgula para os decimais',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final value = Fmt.decimal(v ?? '');
                  return value == null || value < .1 ? 'Informe uma distância válida' : null;
                },
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _timeField(_hours, 'Horas'),
                  const SizedBox(width: 12),
                  _timeField(_minutes, 'Minutos'),
                  const SizedBox(width: 12),
                  _timeField(_seconds, 'Segundos'),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  RRIcon('pace', size: 20, color: c.accentText),
                  const SizedBox(width: 8),
                  // O pace responde enquanto a pessoa digita.
                  AnimatedSwitcher(
                    duration: RRMotion.of(context, RRMotion.fast),
                    child: Text(
                      'PACE MÉDIO ${Fmt.paceFrom(km, _totalSeconds)} /KM',
                      key: ValueKey(Fmt.paceFrom(km, _totalSeconds)),
                      style: RRType.monoM.copyWith(color: c.textSecondary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              RRField(
                controller: _elevation,
                label: 'Elevação (m) — opcional',
                hint: '0',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('ESFORÇO PERCEBIDO', style: RRType.monoS.copyWith(color: c.textSecondary)),
                  RREffort(_effort, showLabel: false),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 1; i <= 5; i++)
                    RRChip(RREffort.labels[i - 1], selected: _effort == i, onTap: () => setState(() => _effort = i)),
                ],
              ),
              const SizedBox(height: 20),
              RRInfoLine(icon: 'calendario', title: 'Data do treino', value: Fmt.dayMonthYear(_date), onTap: _pickDate),
              const SizedBox(height: 20),
              RRField(
                controller: _description,
                label: 'Como foi? — opcional',
                hint: 'Conte como foi o treino',
                maxLines: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickedPhoto {
  final XFile file;
  final Uint8List bytes;
  const _PickedPhoto(this.file, this.bytes);
}
