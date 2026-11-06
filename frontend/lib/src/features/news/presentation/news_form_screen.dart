import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/motion/rr_motion.dart';
import '../../../core/theme/rr_theme.dart';
import '../../../core/widgets/rr_button.dart';
import '../../../core/widgets/rr_feedback.dart';
import '../../../core/widgets/rr_field.dart';
import '../../../core/widgets/rr_labels.dart';
import '../../../core/widgets/rr_layout.dart';
import '../data/news_model.dart';

/// Publicação de notícia, disponível para organizadores e administradores.
/// Com [news], edita a notícia existente.
class NewsFormScreen extends StatefulWidget {
  final NewsModel? news;
  const NewsFormScreen({super.key, this.news});

  @override
  State<NewsFormScreen> createState() => _NewsFormScreenState();
}

class _NewsFormScreenState extends State<NewsFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shakeKey = GlobalKey<RRShakeState>();
  late final _title = TextEditingController(text: widget.news?.titulo);
  late final _subtitle = TextEditingController(text: widget.news?.subtitulo);
  late final _content = TextEditingController(text: widget.news?.conteudo);
  late final _image = TextEditingController(text: widget.news?.imagemUrl);
  late String _category = widget.news?.categoria ?? 'Novidade';
  late bool _featured = widget.news?.destaque ?? false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_title, _subtitle, _content, _image]) {
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
      final body = {
        'titulo': _title.text.trim(),
        'subtitulo': _subtitle.text.trim(),
        'conteudo': _content.text.trim(),
        'categoria': _category,
        'imagemUrl': _image.text.trim(),
        'destaque': _featured,
      };
      final editing = widget.news;
      if (editing != null) {
        await NewsService.update(editing.id, body);
      } else {
        await NewsService.create(body);
      }
      if (!mounted) return;
      showRRToast(context, editing != null ? 'Notícia atualizada!' : 'Notícia publicada!');
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
      title: widget.news != null ? 'Editar notícia' : 'Nova notícia',
      maxWidth: 640,
      bottom: RRButton(
        widget.news != null ? 'Salvar alterações' : 'Publicar notícia',
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
              RRField(controller: _title, label: 'Título', validator: required),
              gap,
              RRField(controller: _subtitle, label: 'Subtítulo — opcional'),
              gap,
              Text('CATEGORIA', style: RRType.monoS.copyWith(color: c.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in NewsModel.categories)
                    RRChip(
                      category,
                      selected: _category == category,
                      onTap: () => setState(() => _category = category),
                    ),
                ],
              ),
              gap,
              RRField(controller: _content, label: 'Conteúdo', maxLines: 10, validator: required),
              gap,
              RRField(
                controller: _image,
                label: 'Link da imagem — opcional',
                hint: 'https://',
                icon: 'link',
                keyboardType: TextInputType.url,
              ),
              gap,
              Row(
                children: [
                  Expanded(
                    child: Text('Colocar em destaque', style: RRType.labelM.copyWith(color: c.textPrimary)),
                  ),
                  Switch(value: _featured, onChanged: (v) => setState(() => _featured = v)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
