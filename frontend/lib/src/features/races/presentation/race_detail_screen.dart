import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/brand/rr_brand.dart';
import '../../../core/network/api_client.dart';
import '../../../core/motion/rr_motion.dart';
import '../../../core/theme/rr_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/rr_button.dart';
import '../../../core/widgets/rr_feedback.dart';
import '../../../core/widgets/rr_labels.dart';
import '../../../core/widgets/rr_layout.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../data/race_model.dart';
import 'race_form_screen.dart';
import 'race_widgets.dart';

class RaceDetailScreen extends StatefulWidget {
  final RaceModel race;
  final Object? heroTag;
  const RaceDetailScreen({super.key, required this.race, this.heroTag});

  @override
  State<RaceDetailScreen> createState() => _RaceDetailScreenState();
}

class _RaceDetailScreenState extends State<RaceDetailScreen> {
  late RaceModel _race = widget.race;
  bool _busy = false;
  // As raias da capa se afastam em ritmo diferente do texto ao rolar.
  final _scroll = ScrollController();
  final _lanesShift = ValueNotifier<Offset>(Offset.zero);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (!RRMotion.reduced(context)) _lanesShift.value = Offset(0, _scroll.offset * .45);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _lanesShift.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    try {
      await toggleRacePresence(context, _race);
    } on ApiException catch (e) {
      if (mounted) showRRToast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final auth = context.read<AuthProvider>();
    try {
      final saved = await RaceService.toggleSave(_race.id);
      await auth.refreshUser();
      if (mounted) showRRToast(context, saved ? 'Prova salva no seu perfil.' : 'Prova removida das salvas.');
    } on ApiException catch (e) {
      if (mounted) showRRToast(context, e.message, error: true);
    }
  }

  Future<void> _edit() async {
    final updated = await rrPush<RaceModel>(context, RaceFormScreen(race: _race));
    if (updated != null && mounted) setState(() => _race = updated);
  }

  Future<void> _delete() async {
    final bus = context.read<RacesBus>();
    final going = _race.participantes.length;
    final confirmed = await showRRConfirm(
      context,
      title: 'Excluir prova?',
      text: going > 0
          ? '$going ${going == 1 ? 'pessoa confirmou' : 'pessoas confirmaram'} presença e não ${going == 1 ? 'será avisada' : 'serão avisadas'}. '
                'Se a prova não vai acontecer, considere marcar como cancelada. Essa ação não pode ser desfeita.'
          : 'Ela sai do calendário e das provas salvas. Essa ação não pode ser desfeita.',
      confirmLabel: 'Excluir',
    );
    if (!confirmed) return;
    try {
      await RaceService.delete(_race.id);
      bus.changed();
      if (!mounted) return;
      showRRToast(context, 'Prova excluída.');
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) showRRToast(context, e.message, error: true);
    }
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    final ok = uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) showRRToast(context, 'Não foi possível abrir o link.', error: true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    final race = _race;
    final user = context.watch<AuthProvider>().user;
    final canManage = user != null && (user.tipo == 'admin' || race.criadoPor == user.id);
    final going = race.participantes.contains(user?.id);
    final saved = user?.corridasSalvas.contains(race.id) ?? false;
    final desktop = RRBreakpoints.isDesktop(context);
    final today = DateTime.now();
    final days = DateTime(
      race.data.year,
      race.data.month,
      race.data.day,
    ).difference(DateTime(today.year, today.month, today.day)).inDays;

    String? join(List<String?> parts) {
      final values = parts.where((p) => p != null && p.isNotEmpty).toList();
      return values.isEmpty ? null : values.join(' • ');
    }

    final place = join([race.endereco, race.cityLine]);
    final kit = join([race.kitData, race.kitHorario, race.kitLocal]);
    final organizer = join([race.organizadorNome, race.organizadorContato]);
    final hasRegistration = race.linkInscricao != null && race.linkInscricao!.isNotEmpty;

    Widget count(String value, String label, [double? number]) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Só o texto com dígitos conta; "—" aparece direto.
          number == null
              ? Text(value, style: RRType.dataL.copyWith(color: c.textPrimary))
              : RRCountUp(
                  value: number,
                  builder: (_, v) => Text(Fmt.thousands(v), style: RRType.dataL.copyWith(color: c.textPrimary)),
                ),
          const SizedBox(height: 2),
          Text(label.toUpperCase(), style: RRType.monoS.copyWith(color: c.textMuted)),
        ],
      ),
    );

    Widget link(String? url, String title, String value, String icon) {
      if (url == null || url.isEmpty) return const SizedBox.shrink();
      return RRInfoLine(icon: icon, title: title, value: value, onTap: () => _open(url));
    }

    return Scaffold(
      backgroundColor: c.canvas,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _RaceCover(
                    race: race,
                    saved: saved,
                    onSave: _save,
                    heroTag: widget.heroTag,
                    lanesShift: _lanesShift,
                    onEdit: canManage ? _edit : null,
                    onDelete: canManage ? _delete : null,
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: desktop ? 32 : 16, vertical: 20),
                    child: RRCentered(
                      maxWidth: 820,
                      child: RRReveal(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                RRTag(race.statusLabel, tone: race.statusTone, dot: true),
                                for (final d in race.distancias) RRDistance(d.label),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                count(
                                  days >= 0 ? '$days' : '—',
                                  days == 1 ? 'dia' : 'dias',
                                  days >= 0 ? days.toDouble() : null,
                                ),
                                count(
                                  '',
                                  race.isOver ? 'correram' : 'vão correr',
                                  race.participantes.length.toDouble(),
                                ),
                                count('—', 'm de elevação', race.elevation > 0 ? race.elevation.toDouble() : null),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (place != null) RRInfoLine(icon: 'local', title: 'Local', value: place),
                            if (kit != null) RRInfoLine(icon: 'inscricao', title: 'Retirada de kit', value: kit),
                            if (race.preco != null && race.preco!.isNotEmpty)
                              RRInfoLine(icon: 'recorde', title: 'Inscrição', value: race.preco!),
                            if (organizer != null) RRInfoLine(icon: 'perfil', title: 'Organização', value: organizer),
                            link(race.regulamentoUrl, 'Regulamento', 'Abrir regulamento', 'noticias'),
                            link(race.resultadosUrl, 'Resultados', 'Ver resultados do chip', 'tempo'),
                            link(race.fotosUrl, 'Galeria', 'Ver fotos da prova', 'link'),
                            link(race.certificadoUrl, 'Certificado', 'Baixar certificado', 'recorde'),
                            if (race.descricao != null && race.descricao!.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              const RRSectionHead('Sobre a prova'),
                              const SizedBox(height: 8),
                              Text(race.descricao!, style: RRType.textL.copyWith(color: c.textPrimary)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (race.canConfirm)
            Container(
              color: c.surface,
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.paddingOf(context).bottom),
              child: RRCentered(
                maxWidth: 820,
                child: Row(
                  children: [
                    if (hasRegistration) ...[
                      Expanded(
                        child: RRButton(
                          'Inscrever-se',
                          kind: RRButtonKind.secondary,
                          size: RRButtonSize.l,
                          expand: true,
                          onPressed: () => _open(race.linkInscricao!),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: RRButton(
                        going ? 'Confirmado' : 'Eu vou!',
                        kind: going ? RRButtonKind.secondary : RRButtonKind.accent,
                        size: RRButtonSize.l,
                        icon: going ? 'confirmar' : null,
                        expand: true,
                        loading: _busy,
                        onPressed: _confirm,
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
}

class _RaceCover extends StatelessWidget {
  final RaceModel race;
  final bool saved;
  final VoidCallback onSave;
  final Object? heroTag;
  final ValueListenable<Offset> lanesShift;
  final VoidCallback? onEdit, onDelete;
  const _RaceCover({
    this.onEdit,
    this.onDelete,
    required this.race,
    required this.saved,
    required this.onSave,
    required this.heroTag,
    required this.lanesShift,
  });

  @override
  Widget build(BuildContext context) {
    final tone = race.tone;
    final foreground = RaceCoverBackground.foreground(race);
    final top = MediaQuery.paddingOf(context).top;
    final desktop = RRBreakpoints.isDesktop(context);
    // Nomes longos usam um corpo menor para não tomar a tela.
    final long = race.nome.length > 24;
    final size = desktop ? (long ? 72.0 : 96.0) : (long ? 56.0 : 84.0);
    final time = race.horarioLargada == null || race.horarioLargada!.isEmpty ? '' : ' • ${race.horarioLargada}';
    final date =
        '${race.data.day.toString().padLeft(2, '0')} ${Fmt.monthShort(race.data.month)} ${race.data.year}$time';

    final background = RaceCoverBackground(
      race: race,
      lanes: RRLanes(
        color: tone.lanes,
        fromRight: -10,
        cy: -10,
        r0: 26,
        step: 24,
        count: 6,
        strokeWidth: 9,
        shift: lanesShift,
        // Vindo do cartão, as raias já chegam prontas no voo da capa.
        drawIn: heroTag == null,
      ),
    );

    return Container(
      constraints: const BoxConstraints(minHeight: 320),
      child: Stack(
        children: [
          Positioned.fill(
            child: heroTag == null ? background : Hero(tag: heroTag!, child: background),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(desktop ? 24 : 8, top + 8, desktop ? 32 : 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    RRIconButton(
                      'voltar',
                      tooltip: 'Voltar',
                      color: foreground,
                      onPressed: () => Navigator.maybePop(context),
                    ),
                    RRIconButton(
                      'salvar',
                      tooltip: saved ? 'Remover das salvas' : 'Salvar prova',
                      color: foreground,
                      filled: saved,
                      onPressed: onSave,
                    ),
                    const Spacer(),
                    if (onEdit != null)
                      RRIconButton('editar', tooltip: 'Editar prova', color: foreground, onPressed: onEdit),
                    if (onDelete != null)
                      RRIconButton('excluir', tooltip: 'Excluir prova', color: foreground, onPressed: onDelete),
                  ],
                ),
                const SizedBox(height: 36),
                Padding(
                  padding: EdgeInsets.only(left: desktop ? 8 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(date.toUpperCase(), style: RRType.monoM.copyWith(color: foreground)),
                      const SizedBox(height: 12),
                      RRMaskedLine(
                        delay: const Duration(milliseconds: 120),
                        child: Text(
                          race.nome.toUpperCase(),
                          style: RRType.hero(size, size * .88).copyWith(color: foreground),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Mantém o símbolo discreto fora da faixa de texto em telas largas.
          if (desktop) Positioned(right: 32, bottom: 24, child: RRSymbol(height: 40, color: foreground)),
        ],
      ),
    );
  }
}
