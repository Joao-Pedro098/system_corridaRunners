import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/motion/rr_motion.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/rr_theme.dart';
import '../../../../core/widgets/rr_button.dart';
import '../../../../core/widgets/rr_feedback.dart';
import '../../../../core/widgets/rr_field.dart';
import '../../../../core/widgets/rr_layout.dart';
import '../providers/auth_provider.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shakeKey = GlobalKey<RRShakeState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_current, _next, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      _shakeKey.currentState?.shake();
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<AuthProvider>().changePassword(_current.text, _next.text);
      if (!mounted) return;
      showRRToast(context, 'Senha alterada.');
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
    return RRSubPage(
      title: 'Alterar senha',
      maxWidth: 640,
      bottom: RRButton('Alterar senha', size: RRButtonSize.l, expand: true, loading: _saving, onPressed: _submit),
      child: Form(
        key: _formKey,
        child: RRShake(
          key: _shakeKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RRField(
                controller: _current,
                label: 'Senha atual',
                icon: 'senha',
                isPassword: true,
                autofillHints: const [AutofillHints.password],
                validator: (v) => v == null || v.isEmpty ? 'Informe sua senha atual' : null,
              ),
              gap,
              RRField(
                controller: _next,
                label: 'Nova senha',
                icon: 'senha',
                isPassword: true,
                autofillHints: const [AutofillHints.newPassword],
                validator: (v) {
                  if (v == null || v.length < 6) return 'A senha deve ter no mínimo 6 caracteres';
                  return v == _current.text ? 'A nova senha precisa ser diferente da atual' : null;
                },
              ),
              gap,
              RRField(
                controller: _confirm,
                label: 'Confirme a nova senha',
                icon: 'senha',
                isPassword: true,
                autofillHints: const [AutofillHints.newPassword],
                onSubmitted: (_) => _submit(),
                validator: (v) => v != _next.text ? 'As senhas não são iguais' : null,
              ),
              const SizedBox(height: 12),
              Text(
                'Os outros aparelhos conectados à sua conta precisarão entrar de novo.',
                style: RRType.textS.copyWith(color: context.rr.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
