import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/motion/rr_motion.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/rr_button.dart';
import '../../../core/widgets/rr_feedback.dart';
import '../../../core/widgets/rr_field.dart';
import '../../../core/widgets/rr_labels.dart';
import '../../../core/widgets/rr_layout.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../auth/presentation/screens/change_password_screen.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shakeKey = GlobalKey<RRShakeState>();
  late final TextEditingController _name, _phone, _city, _state, _bio;
  late final Map<String, TextEditingController> _records;
  bool _saving = false, _savingPhoto = false;

  static const _maxPhotoBytes = 5 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user!;
    _name = TextEditingController(text: user.nome);
    _phone = TextEditingController(text: user.telefone);
    _city = TextEditingController(text: user.cidade);
    _state = TextEditingController(text: user.estado);
    _bio = TextEditingController(text: user.bio);
    _records = {
      for (final key in const ['rp5k', 'rp10k', 'rp21k', 'rp42k'])
        key: TextEditingController(text: user.recordesPessoais?[key] as String?),
    };
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _city, _state, _bio, ..._records.values]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validateTime(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty || RegExp(r'^\d{1,2}:\d{2}(:\d{2})?$').hasMatch(text)) return null;
    return 'Use o formato 48:32 ou 1:52:18';
  }

  // A foto vale na hora: não depende de salvar o restante do formulário.
  Future<void> _changePhoto(Future<void> Function() action, String done) async {
    setState(() => _savingPhoto = true);
    try {
      await action();
      if (mounted) showRRToast(context, done);
    } on ApiException catch (e) {
      if (mounted) showRRToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _savingPhoto = false);
    }
  }

  Future<void> _pickPhoto() async {
    final auth = context.read<AuthProvider>();
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    } on PlatformException {
      if (mounted) showRRToast(context, 'Permita o acesso às fotos para escolher uma imagem.', error: true);
      return;
    }
    if (file == null) return;
    if (await file.length() > _maxPhotoBytes) {
      if (mounted) showRRToast(context, 'A foto pode ter no máximo 5 MB.', error: true);
      return;
    }
    if (mounted) await _changePhoto(() => auth.uploadAvatar(file!), 'Foto atualizada.');
  }

  Future<void> _removePhoto() async {
    final auth = context.read<AuthProvider>();
    final confirmed = await showRRConfirm(
      context,
      title: 'Remover foto?',
      text: 'Seu perfil volta a mostrar as iniciais do seu nome.',
      confirmLabel: 'Remover',
    );
    if (confirmed && mounted) await _changePhoto(auth.removeAvatar, 'Foto removida.');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      _shakeKey.currentState?.shake();
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<AuthProvider>().updateProfile({
        'nome': _name.text.trim(),
        'telefone': _phone.text.trim(),
        'cidade': _city.text.trim(),
        'estado': _state.text.trim(),
        'bio': _bio.text.trim(),
        'recordesPessoais': {for (final e in _records.entries) e.key: e.value.text.trim()},
      });
      if (!mounted) return;
      showRRToast(context, 'Perfil atualizado.');
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) showRRToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 20);
    final user = context.watch<AuthProvider>().user;
    final hasPhoto = user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty;
    Widget record(String label, String key) => Expanded(
      child: RRField(controller: _records[key]!, label: label, hint: '--:--', validator: _validateTime),
    );
    return RRSubPage(
      title: 'Editar perfil',
      maxWidth: 640,
      bottom: RRButton('Salvar alterações', size: RRButtonSize.l, expand: true, loading: _saving, onPressed: _submit),
      child: Form(
        key: _formKey,
        child: RRShake(
          key: _shakeKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  RRAvatar(user?.nome ?? '', url: user?.avatarUrl, size: 72),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        RRButton(
                          hasPhoto ? 'Trocar foto' : 'Adicionar foto',
                          icon: 'foto',
                          kind: RRButtonKind.secondary,
                          loading: _savingPhoto,
                          onPressed: _pickPhoto,
                        ),
                        if (hasPhoto)
                          RRButton(
                            'Remover foto',
                            kind: RRButtonKind.ghost,
                            onPressed: _savingPhoto ? null : _removePhoto,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              gap,
              RRField(
                controller: _name,
                label: 'Nome',
                icon: 'perfil',
                validator: (v) => v == null || v.trim().isEmpty ? 'Informe seu nome' : null,
              ),
              gap,
              RRField(
                controller: _phone,
                label: 'WhatsApp / Telefone',
                icon: 'telefone',
                keyboardType: TextInputType.phone,
              ),
              gap,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: RRField(controller: _city, label: 'Cidade', icon: 'local'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RRField(controller: _state, label: 'UF'),
                  ),
                ],
              ),
              gap,
              RRField(controller: _bio, label: 'Bio', maxLines: 3, hint: 'Conte um pouco sobre sua corrida'),
              gap,
              const RRSectionHead('Recordes pessoais'),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [record('5K', 'rp5k'), const SizedBox(width: 12), record('10K', 'rp10k')],
              ),
              gap,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [record('21K', 'rp21k'), const SizedBox(width: 12), record('42K', 'rp42k')],
              ),
              gap,
              const RRSectionHead('Segurança'),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: RRButton(
                  'Alterar senha',
                  icon: 'senha',
                  kind: RRButtonKind.secondary,
                  onPressed: () => rrPush(context, const ChangePasswordScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
