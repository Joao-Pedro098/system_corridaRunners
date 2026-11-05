import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/motion/rr_motion.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/rr_button.dart';
import '../../../core/widgets/rr_feedback.dart';
import '../../../core/widgets/rr_field.dart';
import '../../../core/widgets/rr_layout.dart';
import '../../auth/presentation/providers/auth_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shakeKey = GlobalKey<RRShakeState>();
  late final TextEditingController _name, _phone, _city, _state, _bio, _avatar;
  late final Map<String, TextEditingController> _records;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user!;
    _name = TextEditingController(text: user.nome);
    _phone = TextEditingController(text: user.telefone);
    _city = TextEditingController(text: user.cidade);
    _state = TextEditingController(text: user.estado);
    _bio = TextEditingController(text: user.bio);
    _avatar = TextEditingController(text: user.avatarUrl);
    _records = {
      for (final key in const ['rp5k', 'rp10k', 'rp21k', 'rp42k'])
        key: TextEditingController(text: user.recordesPessoais?[key] as String?),
    };
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _city, _state, _bio, _avatar, ..._records.values]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validateTime(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty || RegExp(r'^\d{1,2}:\d{2}(:\d{2})?$').hasMatch(text)) return null;
    return 'Use o formato 48:32 ou 1:52:18';
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
        'avatarUrl': _avatar.text.trim(),
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
              RRField(
                controller: _avatar,
                label: 'Link da foto',
                icon: 'link',
                hint: 'https://',
                keyboardType: TextInputType.url,
              ),
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
            ],
          ),
        ),
      ),
    );
  }
}
