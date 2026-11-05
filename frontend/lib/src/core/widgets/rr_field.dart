import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../brand/rr_brand.dart';
import '../theme/rr_theme.dart';

/// Campo do design system: rótulo em DM Mono, borda e mensagem indicam o erro.
class RRField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint, helper, icon;
  final bool isPassword;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;

  const RRField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.helper,
    this.icon,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
    this.autofillHints,
    this.inputFormatters,
    this.textInputAction,
  });

  @override
  State<RRField> createState() => _RRFieldState();
}

class _RRFieldState extends State<RRField> {
  late bool _obscure = widget.isPassword;

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label.toUpperCase(), style: RRType.monoS.copyWith(color: c.textSecondary)),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.controller,
          obscureText: _obscure,
          keyboardType: widget.keyboardType,
          validator: widget.validator,
          maxLines: widget.isPassword ? 1 : widget.maxLines,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          autofillHints: widget.autofillHints,
          inputFormatters: widget.inputFormatters,
          textInputAction: widget.textInputAction,
          style: RRType.textL.copyWith(color: c.textPrimary),
          decoration: InputDecoration(
            hintText: widget.hint,
            helperText: widget.helper,
            prefixIcon: widget.icon == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 14, right: 10),
                    child: RRIcon(widget.icon!, size: 20, color: c.textSecondary),
                  ),
            prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 20),
            suffixIcon: widget.isPassword
                ? IconButton(
                    tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
                    icon: Icon(
                      _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: c.textSecondary,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

/// Busca de provas e cidades.
class RRSearch extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final double? width;
  const RRSearch({super.key, required this.onChanged, this.hint = 'Buscar prova ou cidade', this.width});

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    return SizedBox(
      width: width,
      height: 48,
      child: TextField(
        onChanged: onChanged,
        style: RRType.textM.copyWith(color: c.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: RRType.textM.copyWith(color: c.textMuted),
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: RRIcon('buscar', size: 20, color: c.textSecondary),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 20),
        ),
      ),
    );
  }
}
