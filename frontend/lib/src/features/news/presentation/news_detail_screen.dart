import 'package:flutter/material.dart';

import '../../../core/theme/rr_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/rr_layout.dart';
import '../data/news_model.dart';
import 'news_widgets.dart';

class NewsDetailScreen extends StatelessWidget {
  final NewsModel news;
  const NewsDetailScreen({super.key, required this.news});

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    return RRSubPage(
      title: news.categoria,
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
            '${news.autor} • ${Fmt.dayMonthYear(news.createdAt)} • ${news.readingMinutes} min'.toUpperCase(),
            style: RRType.monoS.copyWith(color: c.textMuted),
          ),
          const SizedBox(height: 20),
          SelectableText(news.conteudo, style: RRType.textL.copyWith(color: c.textPrimary)),
        ],
      ),
    );
  }
}
