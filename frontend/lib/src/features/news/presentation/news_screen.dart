import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/rr_theme.dart';
import '../../../core/widgets/rr_button.dart';
import '../../../core/widgets/rr_feedback.dart';
import '../../../core/widgets/rr_labels.dart';
import '../../../core/widgets/rr_layout.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../data/news_model.dart';
import 'news_form_screen.dart';
import 'news_sources_screen.dart';
import 'news_widgets.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  List<NewsModel> _items = [];
  bool _loading = true, _loadingMore = false, _hasMore = false;
  int _page = 1;

  /// Identifica o pedido atual: a resposta de um filtro antigo é descartada.
  int _request = 0;
  String? _error, _category;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
    });
    try {
      final result = await NewsService.page(categoria: _category);
      if (!mounted || request != _request) return;
      setState(() {
        _items = result.items;
        _hasMore = result.hasMore;
        _page = 1;
      });
    } on ApiException catch (e) {
      if (mounted && request == _request) setState(() => _error = e.message);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore) return;
    final request = _request;
    setState(() => _loadingMore = true);
    try {
      final result = await NewsService.page(categoria: _category, page: _page + 1);
      if (!mounted || request != _request) return;
      // Uma matéria nova desloca a lista: o que já está na tela não entra duas vezes.
      final known = _items.map((n) => n.id).toSet();
      setState(() {
        _items = [..._items, ...result.items.where((n) => !known.contains(n.id))];
        _hasMore = result.hasMore;
        _page += 1;
      });
    } on ApiException catch (e) {
      if (mounted && request == _request) showRRToast(context, e.message, error: true);
    } finally {
      if (mounted && request == _request) setState(() => _loadingMore = false);
    }
  }

  void _select(String? category) {
    setState(() => _category = category);
    _load();
  }

  Future<void> _create() async {
    final created = await rrPush<bool>(context, const NewsFormScreen());
    if (created == true) _load();
  }

  Future<void> _openSources() async {
    final changed = await rrPush<bool>(context, const NewsSourcesScreen());
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    final desktop = RRBreakpoints.isDesktop(context);
    final type = context.select<AuthProvider, String?>((a) => a.user?.tipo);
    final canCreate = type == 'organizador' || type == 'admin';

    final Widget body;
    if (_loading && _items.isEmpty) {
      body = const RRSkeleton(count: 3, height: 124);
    } else if (_error != null) {
      body = RRErrorState(message: _error!, onRetry: _load);
    } else if (_items.isEmpty) {
      body = const RREmptyState(
        title: 'Nada publicado por aqui',
        text: 'Dicas de treino, nutrição e avisos das provas da região aparecem nesta página.',
      );
    } else {
      body = LayoutBuilder(
        builder: (context, box) => RRGrid(
          columns: box.maxWidth >= 1000 ? 3 : (box.maxWidth >= 640 ? 2 : 1),
          gap: 16,
          children: [for (final n in _items) NewsCard(news: n, key: ValueKey(n.id), onHidden: _load)],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.all(desktop ? 32 : 16),
        children: [
          // No celular as ações ficam abaixo do título, para ele não quebrar no meio da palavra.
          Flex(
            direction: desktop ? Axis.horizontal : Axis.vertical,
            crossAxisAlignment: desktop ? CrossAxisAlignment.end : CrossAxisAlignment.stretch,
            children: [
              if (desktop)
                Expanded(
                  child: Text('NOTÍCIAS E DICAS', style: RRType.displayM.copyWith(color: c.textPrimary)),
                )
              else
                Text('NOTÍCIAS\nE DICAS', style: RRType.displayM.copyWith(color: c.textPrimary)),
              if (canCreate) ...[
                if (!desktop) const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RRButton('Nova notícia', icon: 'mais', onPressed: _create),
                    if (type == 'admin') ...[
                      const SizedBox(width: 8),
                      RRButton('Fontes', icon: 'link', kind: RRButtonKind.secondary, onPressed: _openSources),
                    ],
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                RRChip('Todas', selected: _category == null, onTap: () => _select(null)),
                for (final category in NewsModel.categories) ...[
                  const SizedBox(width: 8),
                  RRChip(category, selected: _category == category, onTap: () => _select(category)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          body,
          if (_hasMore && _error == null && _items.isNotEmpty) ...[
            const SizedBox(height: 16),
            Center(
              child: RRButton(
                'Carregar mais',
                kind: RRButtonKind.secondary,
                loading: _loadingMore,
                onPressed: _loadMore,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
