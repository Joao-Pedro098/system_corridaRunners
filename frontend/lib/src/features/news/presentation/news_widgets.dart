import 'package:flutter/material.dart';

import '../../../core/brand/rr_brand.dart';
import '../../../core/theme/rr_theme.dart';
import '../../../core/widgets/rr_layout.dart';
import '../data/news_model.dart';
import 'news_detail_screen.dart';

/// Imagem da notícia ou, sem imagem, raias sobre Tartan.
class NewsCover extends StatelessWidget {
  final NewsModel news;
  final double? width, height;
  final double r0, step, strokeWidth;
  const NewsCover(this.news, {super.key, this.width, this.height, this.r0 = 14, this.step = 14, this.strokeWidth = 5});

  @override
  Widget build(BuildContext context) {
    final art = Container(
      width: width,
      height: height,
      color: RRPalette.tartan500,
      child: CustomPaint(
        painter: LanesPainter(
          color: RRPalette.cal950,
          cy: height ?? 80,
          r0: r0,
          step: step,
          count: 5,
          strokeWidth: strokeWidth,
        ),
      ),
    );
    final url = news.imagemUrl;
    if (url == null || url.isEmpty) return art;
    return Image.network(url, width: width, height: height, fit: BoxFit.cover, errorBuilder: (_, _, _) => art);
  }
}

class NewsCard extends StatelessWidget {
  final NewsModel news;
  const NewsCard({super.key, required this.news});

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    return RRCard(
      padding: const EdgeInsets.all(12),
      onTap: () => rrPush(context, NewsDetailScreen(news: news)),
      child: Row(
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(RRRadius.md), child: NewsCover(news, width: 80, height: 80)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(news.categoria.toUpperCase(), style: RRType.monoS.copyWith(color: c.accentText)),
                const SizedBox(height: 4),
                Text(
                  news.titulo,
                  style: RRType.labelM.copyWith(color: c.textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text('${news.readingMinutes} min de leitura', style: RRType.textS.copyWith(color: c.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
