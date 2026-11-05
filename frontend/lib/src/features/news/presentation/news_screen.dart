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
import 'news_widgets.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  List<NewsModel> _items = [];
  bool _loading = true;
  String? _error, _category;

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
      final items = await NewsService.list(categoria: _category);
      if (mounted) setState(() => _items = items);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
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

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    final desktop = RRBreakpoints.isDesktop(context);
    final type = context.select<AuthProvider, String?>((a) => a.user?.tipo);
    final canCreate = type == 'organizador' || type == 'admin';

    final Widget body;
    if (_loading && _items.isEmpty) {
      body = const RRSkeleton(count: 3, height: 104);
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
          children: [for (final n in _items) NewsCard(news: n, key: ValueKey(n.id))],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.all(desktop ? 32 : 16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  desktop ? 'NOTÍCIAS E DICAS' : 'NOTÍCIAS\nE DICAS',
                  style: RRType.displayM.copyWith(color: c.textPrimary),
                ),
              ),
              if (canCreate) RRButton('Nova notícia', icon: 'mais', onPressed: _create),
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
        ],
      ),
    );
  }
}
