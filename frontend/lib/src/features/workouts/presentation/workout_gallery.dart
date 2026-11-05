import 'package:flutter/material.dart';

import '../../../core/brand/rr_brand.dart';
import '../../../core/theme/rr_theme.dart';
import '../../../core/widgets/rr_button.dart';
import '../../../core/widgets/rr_layout.dart';

/// Selo sobre as fotos: sempre Asfalto, para ler bem em qualquer imagem.
class PhotoBadge extends StatelessWidget {
  final String? icon;
  final String label;
  const PhotoBadge({super.key, this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    height: 24,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: RRPalette.cal950.withValues(alpha: .82),
      borderRadius: BorderRadius.circular(RRRadius.sm),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[RRIcon(icon!, size: 14, color: RRPalette.cal50), const SizedBox(width: 4)],
        Text(label, style: RRType.monoS.copyWith(color: RRPalette.cal50)),
      ],
    ),
  );
}

/// Galeria do detalhe do treino: desliza entre as fotos e amplia ao tocar.
class WorkoutGallery extends StatefulWidget {
  final List<String> photos;
  final double height;
  final Object? heroTag;
  const WorkoutGallery({super.key, required this.photos, this.height = 300, this.heroTag});

  @override
  State<WorkoutGallery> createState() => _WorkoutGalleryState();
}

class _WorkoutGalleryState extends State<WorkoutGallery> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// A primeira foto continua o movimento vindo do cartão do feed.
  Widget _heroFor(int index, Widget child) =>
      index == 0 && widget.heroTag != null ? Hero(tag: widget.heroTag!, child: child) : child;

  void _go(int delta) => _controller.animateToPage(
    _index + delta,
    duration: const Duration(milliseconds: 240),
    curve: Curves.easeOutCubic,
  );

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    // No computador não há gesto de deslizar: as setas fazem esse papel.
    Widget arrow(String icon, String tooltip, int delta, Alignment alignment) => Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Material(
          color: RRPalette.cal950.withValues(alpha: .82),
          shape: const CircleBorder(),
          child: RRIconButton(icon, tooltip: tooltip, color: RRPalette.cal50, size: 20, onPressed: () => _go(delta)),
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(RRRadius.lg),
      child: SizedBox(
        height: widget.height,
        child: ColoredBox(
          color: RRPalette.cal950,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: photos.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => Semantics(
                  button: true,
                  label: 'Foto ${i + 1} de ${photos.length}. Toque para ampliar.',
                  child: GestureDetector(
                    onTap: () => rrPush(context, _PhotoViewer(photos: photos, initial: i)),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.zoomIn,
                      child: _heroFor(
                        i,
                        Image.network(
                          photos[i],
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Center(child: RRIcon('foto', size: 32, color: RRPalette.cal500)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (photos.length > 1) ...[
                if (_index > 0) arrow('voltar', 'Foto anterior', -1, Alignment.centerLeft),
                if (_index < photos.length - 1) arrow('seta', 'Próxima foto', 1, Alignment.centerRight),
                Positioned(right: 8, bottom: 8, child: PhotoBadge(label: '${_index + 1} / ${photos.length}')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Foto em tela cheia, com zoom.
class _PhotoViewer extends StatefulWidget {
  final List<String> photos;
  final int initial;
  const _PhotoViewer({required this.photos, required this.initial});

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final _controller = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: RRPalette.cal950,
    body: Stack(
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: widget.photos.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) => InteractiveViewer(
            maxScale: 4,
            child: Center(child: Image.network(widget.photos[i], fit: BoxFit.contain)),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                RRIconButton(
                  'fechar',
                  tooltip: 'Fechar',
                  color: RRPalette.cal50,
                  onPressed: () => Navigator.maybePop(context),
                ),
                const Spacer(),
                if (widget.photos.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      '${_index + 1} / ${widget.photos.length}',
                      style: RRType.monoM.copyWith(color: RRPalette.cal50),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
