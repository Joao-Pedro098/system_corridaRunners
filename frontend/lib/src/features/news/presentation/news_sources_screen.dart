import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/rr_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/rr_button.dart';
import '../../../core/widgets/rr_feedback.dart';
import '../../../core/widgets/rr_layout.dart';
import '../data/news_model.dart';

/// Controle do admin sobre as matérias vindas de outros sites.
class NewsSourcesScreen extends StatefulWidget {
  const NewsSourcesScreen({super.key});

  @override
  State<NewsSourcesScreen> createState() => _NewsSourcesScreenState();
}

class _NewsSourcesScreenState extends State<NewsSourcesScreen> {
  List<NewsSourceModel> _sources = [];
  List<NewsModel> _hidden = [];
  bool _loading = true, _syncing = false, _changed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([NewsService.sources(), NewsService.hidden()]);
      if (!mounted) return;
      setState(() {
        _sources = results[0] as List<NewsSourceModel>;
        _hidden = results[1] as List<NewsModel>;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(NewsSourceModel source, bool active) async {
    try {
      final sources = await NewsService.setSourceActive(source.id, active);
      if (!mounted) return;
      setState(() {
        _sources = sources;
        _changed = true;
      });
    } on ApiException catch (e) {
      if (mounted) showRRToast(context, e.message, error: true);
    }
  }

  Future<void> _sync() async {
    setState(() => _syncing = true);
    try {
      final result = await NewsService.syncNow();
      if (!mounted) return;
      setState(() {
        _sources = result.sources;
        _changed = true;
      });
      final failed = result.sources.where((s) => s.ativa && s.ultimoErro != null).length;
      showRRToast(
        context,
        failed > 0
            ? 'Não foi possível ler ${failed == 1 ? '1 fonte' : '$failed fontes'}.'
            : switch (result.novas) {
                0 => 'Nenhuma matéria nova.',
                1 => '1 matéria nova.',
                final n => '$n matérias novas.',
              },
        error: failed > 0,
      );
    } on ApiException catch (e) {
      if (mounted) showRRToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _restore(NewsModel news) async {
    try {
      await NewsService.setHidden(news.id, false);
      if (!mounted) return;
      setState(() {
        _hidden = _hidden.where((n) => n.id != news.id).toList();
        _changed = true;
      });
      showRRToast(context, 'A matéria voltou para o app.');
    } on ApiException catch (e) {
      if (mounted) showRRToast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rr;

    final Widget body;
    if (_loading && _sources.isEmpty) {
      body = const RRSkeleton(count: 3, height: 124);
    } else if (_error != null) {
      body = RRErrorState(message: _error!, onRetry: _load);
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'O app mostra título, resumo, link para o site original e a capa, quando o site permite. As fontes são lidas a cada 6 horas. '
            'Ao desligar uma fonte, as matérias dela saem do app na hora.',
            style: RRType.textS.copyWith(color: c.textSecondary),
          ),
          const SizedBox(height: 16),
          for (final source in _sources)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SourceRow(source: source, onChanged: (active) => _toggle(source, active)),
            ),
          if (_hidden.isNotEmpty) ...[
            const SizedBox(height: 20),
            RRSectionHead('Matérias ocultas (${_hidden.length})'),
            const SizedBox(height: 12),
            for (final news in _hidden)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RRCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              news.titulo,
                              style: RRType.labelM.copyWith(color: c.textPrimary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(news.fonteNome ?? news.autor, style: RRType.textS.copyWith(color: c.textSecondary)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      RRButton(
                        'Mostrar',
                        kind: RRButtonKind.secondary,
                        size: RRButtonSize.s,
                        onPressed: () => _restore(news),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: RRSubPage(
        title: 'Fontes de notícias',
        maxWidth: 640,
        bottom: _sources.isEmpty
            ? null
            : RRButton('Buscar agora', size: RRButtonSize.l, expand: true, loading: _syncing, onPressed: _sync),
        child: body,
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  final NewsSourceModel source;
  final ValueChanged<bool> onChanged;
  const _SourceRow({required this.source, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    final total = source.totalMaterias;
    final count = total == 1 ? '1 matéria' : '$total matérias';
    final last = source.ultimaBusca;
    final status = !source.ativa
        ? 'Desligada • $count fora do app'
        : last == null
        ? 'Ainda não foi lida'
        : '$count • lida ${Fmt.relative(last).toLowerCase()}';
    return RRCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(source.nome, style: RRType.labelM.copyWith(color: c.textPrimary)),
                const SizedBox(height: 4),
                Text(status, style: RRType.textS.copyWith(color: c.textSecondary)),
                if (source.ativa && source.ultimoErro != null) ...[
                  const SizedBox(height: 4),
                  Text('Falha na última leitura: ${source.ultimoErro}', style: RRType.textS.copyWith(color: c.danger)),
                ],
              ],
            ),
          ),
          Semantics(
            label: 'Mostrar matérias de ${source.nome}',
            child: Switch(value: source.ativa, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}
