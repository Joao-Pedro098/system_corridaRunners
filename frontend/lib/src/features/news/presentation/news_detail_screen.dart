import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/rr_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/rr_button.dart';
import '../../../core/widgets/rr_feedback.dart';
import '../../../core/widgets/rr_layout.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../data/news_model.dart';
import 'news_widgets.dart';

class NewsDetailScreen extends StatelessWidget {
  final NewsModel news;
  const NewsDetailScreen({super.key, required this.news});

  Future<void> _openSource(BuildContext context) async {
    final uri = Uri.tryParse(news.linkOriginal ?? '');
    final ok =
        uri != null && uri.scheme.startsWith('http') && await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) showRRToast(context, 'Não foi possível abrir o link.', error: true);
  }

  Future<void> _hide(BuildContext context) async {
    final confirmed = await showRRConfirm(
      context,
      title: 'Ocultar matéria?',
      text: 'Ela sai do app para todos. Você pode mostrá-la de novo em Fontes de notícias.',
      confirmLabel: 'Ocultar',
    );
    if (!confirmed || !context.mounted) return;
    try {
      await NewsService.setHidden(news.id, true);
      if (!context.mounted) return;
      showRRToast(context, 'Matéria ocultada.');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (context.mounted) showRRToast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    final isAdmin = context.select<AuthProvider, bool>((a) => a.user?.tipo == 'admin');
    final external = news.isExternal;
    final source = news.fonteNome ?? news.autor;
    return RRSubPage(
      title: news.categoria,
      actions: [
        if (isAdmin && external) RRIconButton('excluir', tooltip: 'Ocultar matéria', onPressed: () => _hide(context)),
      ],
      bottom: external
          ? RRButton(
              'Ler matéria completa no $source',
              icon: 'link',
              size: RRButtonSize.l,
              expand: true,
              onPressed: () => _openSource(context),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(RRRadius.lg),
            child: NewsCover(news, width: double.infinity, height: 220, r0: 34, step: 30, strokeWidth: 11),
          ),
          const SizedBox(height: 20),
          Text(news.titulo.toUpperCase(), style: RRType.displayS.copyWith(color: c.textPrimary)),
          if (news.subtitulo != null && news.subtitulo!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(news.subtitulo!, style: RRType.titleS.copyWith(color: c.textSecondary)),
          ],
          const SizedBox(height: 12),
          Text(
            (external
                    ? '${news.credit} • ${Fmt.dayMonthYear(news.date)}'
                    : '${news.autor} • ${Fmt.dayMonthYear(news.date)} • ${news.readingMinutes} min')
                .toUpperCase(),
            style: RRType.monoS.copyWith(color: c.textMuted),
          ),
          const SizedBox(height: 20),
          SelectableText(news.conteudo, style: RRType.textL.copyWith(color: c.textPrimary)),
          if (external) ...[
            const SizedBox(height: 16),
            Text(
              'Trecho publicado por $source. A matéria completa e a imagem pertencem ao site original.',
              style: RRType.textS.copyWith(color: c.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
