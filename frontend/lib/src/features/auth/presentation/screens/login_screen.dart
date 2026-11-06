import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/motion/rr_motion.dart';
import '../../../../core/theme/rr_theme.dart';
import '../../../../core/widgets/rr_button.dart';
import '../../../../core/widgets/rr_feedback.dart';
import '../../../../core/widgets/rr_field.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_frame.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shakeKey = GlobalKey<RRShakeState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      _shakeKey.currentState?.shake();
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(_emailController.text, _passwordController.text, remember: _rememberMe);

    if (!mounted) return;

    if (success) {
      // O AuthWrapper, na raiz, passa a mostrar a área logada.
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      _shakeKey.currentState?.shake();
      showRRToast(context, authProvider.errorMessage ?? 'Não foi possível realizar o login.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    final authProvider = context.watch<AuthProvider>();

    return AuthFrame(
      title: 'Entrar',
      subtitle: 'Acesse sua conta para ver treinos e novidades.',
      child: Form(
        key: _formKey,
        child: RRShake(
          key: _shakeKey,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RRField(
                  controller: _emailController,
                  label: 'E-mail',
                  hint: 'exemplo@corredor.com',
                  icon: 'email',
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Informe seu e-mail';
                    if (!value.contains('@') || !value.contains('.')) return 'Informe um e-mail válido';
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                RRField(
                  controller: _passwordController,
                  label: 'Senha',
                  hint: 'Digite sua senha',
                  icon: 'senha',
                  isPassword: true,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _handleLogin(),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Informe sua senha';
                    if (value.length < 6) return 'A senha deve ter no mínimo 6 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Checkbox(value: _rememberMe, onChanged: (val) => setState(() => _rememberMe = val ?? true)),
                    Text('Lembrar de mim', style: RRType.textM.copyWith(color: c.textSecondary)),
                  ],
                ),
                const SizedBox(height: 16),
                RRButton(
                  'Entrar',
                  size: RRButtonSize.l,
                  expand: true,
                  loading: authProvider.isLoading,
                  onPressed: _handleLogin,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Não tem uma conta?', style: RRType.textM.copyWith(color: c.textSecondary)),
                    TextButton(
                      onPressed: () => Navigator.of(context).pushReplacement(
                        RRPageRoute(builder: (_) => const RegisterScreen(), instant: RRMotion.reduced(context)),
                      ),
                      child: Text('Cadastre-se', style: RRType.labelM.copyWith(color: c.textLink)),
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
