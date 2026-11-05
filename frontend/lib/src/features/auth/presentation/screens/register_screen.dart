import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/brand/rr_brand.dart';
import '../../../../core/motion/rr_motion.dart';
import '../../../../core/theme/rr_theme.dart';
import '../../../../core/widgets/rr_button.dart';
import '../../../../core/widgets/rr_feedback.dart';
import '../../../../core/widgets/rr_field.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_frame.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shakeKey = GlobalKey<RRShakeState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController(text: 'Parauapebas');
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _tipoSelecionado = 'atleta';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      _shakeKey.currentState?.shake();
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.register(
      nome: _nameController.text,
      email: _emailController.text,
      senha: _passwordController.text,
      tipo: _tipoSelecionado,
      telefone: _phoneController.text,
      cidade: _cityController.text,
      estado: 'PA',
    );

    if (!mounted) return;

    if (success) {
      // O AuthWrapper, na raiz, passa a mostrar a área logada.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      _shakeKey.currentState?.shake();
      showRRToast(context, authProvider.errorMessage ?? 'Não foi possível criar a conta.', error: true);
    }
  }

  Widget _typeOption(String value, String label, String icon) {
    final c = context.rr;
    final selected = _tipoSelecionado == value;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: RRPressable(
          child: AnimatedContainer(
            duration: RRMotion.of(context, RRMotion.base),
            curve: RRMotion.enter,
            decoration: BoxDecoration(
              color: selected ? c.action : c.action.withValues(alpha: 0),
              borderRadius: BorderRadius.circular(RRRadius.md),
              border: Border.all(color: selected ? c.action : c.borderStrong),
            ),
            child: Material(
              type: MaterialType.transparency,
              borderRadius: BorderRadius.circular(RRRadius.md),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => setState(() => _tipoSelecionado = value),
                child: SizedBox(
                  height: 50,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      RRIcon(icon, size: 18, color: selected ? c.onAction : c.textSecondary),
                      const SizedBox(width: 8),
                      Text(label, style: RRType.labelM.copyWith(color: selected ? c.onAction : c.textPrimary)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    final authProvider = context.watch<AuthProvider>();
    const gap = SizedBox(height: 16);

    return AuthFrame(
      title: 'Criar conta',
      subtitle: 'Junte-se à comunidade de corrida da sua região.',
      child: Form(
        key: _formKey,
        child: RRShake(
          key: _shakeKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _typeOption('atleta', 'Sou corredor', 'rota'),
                    const SizedBox(width: 12),
                    _typeOption('organizador', 'Organizador', 'largada'),
                  ],
                ),
                const SizedBox(height: 20),
                RRField(
                  controller: _nameController,
                  label: 'Nome completo',
                  hint: 'Como quer ser chamado',
                  icon: 'perfil',
                  autofillHints: const [AutofillHints.name],
                  validator: (value) => value == null || value.trim().isEmpty ? 'Informe seu nome' : null,
                ),
                gap,
                RRField(
                  controller: _emailController,
                  label: 'E-mail',
                  hint: 'seuemail@exemplo.com',
                  icon: 'email',
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Informe seu e-mail';
                    if (!value.contains('@') || !value.contains('.')) return 'E-mail inválido';
                    return null;
                  },
                ),
                gap,
                RRField(
                  controller: _phoneController,
                  label: 'WhatsApp / Telefone',
                  hint: '(94) 99999-9999',
                  icon: 'telefone',
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                ),
                gap,
                RRField(controller: _cityController, label: 'Cidade', hint: 'Ex: Parauapebas', icon: 'local'),
                gap,
                RRField(
                  controller: _passwordController,
                  label: 'Senha',
                  hint: 'Mínimo de 6 caracteres',
                  icon: 'senha',
                  isPassword: true,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Informe uma senha';
                    if (value.length < 6) return 'Mínimo de 6 caracteres';
                    return null;
                  },
                ),
                gap,
                RRField(
                  controller: _confirmPasswordController,
                  label: 'Confirmar senha',
                  hint: 'Repita sua senha',
                  icon: 'senha',
                  isPassword: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Confirme sua senha';
                    if (value != _passwordController.text) return 'As senhas não coincidem';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                RRButton(
                  'Criar conta',
                  kind: RRButtonKind.accent,
                  size: RRButtonSize.l,
                  expand: true,
                  loading: authProvider.isLoading,
                  onPressed: _handleRegister,
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Já tem uma conta?', style: RRType.textM.copyWith(color: c.textSecondary)),
                    TextButton(
                      onPressed: () => Navigator.of(context).pushReplacement(
                        RRPageRoute(builder: (_) => const LoginScreen(), instant: RRMotion.reduced(context)),
                      ),
                      child: Text('Entrar', style: RRType.labelM.copyWith(color: c.textLink)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
