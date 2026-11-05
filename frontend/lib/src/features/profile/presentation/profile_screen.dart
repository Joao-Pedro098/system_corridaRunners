import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/rr_theme.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/widgets/rr_feedback.dart';
import '../../../core/widgets/rr_labels.dart';
import '../../../core/widgets/rr_layout.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../races/data/race_model.dart';
import '../../races/presentation/my_races_screen.dart';
import '../../races/presentation/race_widgets.dart';
import '../../workouts/presentation/workout_history_screen.dart';
import '../../workouts/presentation/workout_widgets.dart';
import '../../workouts/presentation/workouts_provider.dart';
import 'edit_profile_screen.dart';
import 'profile_widgets.dart';

/// Perfil do atleta logado.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<RaceModel> _saved = [];
  String _savedKey = '';
  late final RacesBus _bus = context.read<RacesBus>();

  @override
  void initState() {
    super.initState();
    _bus.addListener(_reloadSaved);
  }

  @override
  void dispose() {
    _bus.removeListener(_reloadSaved);
    super.dispose();
  }

  /// Uma prova salva pode ter sido editada ou excluída.
  void _reloadSaved() {
    _savedKey = '';
    context.read<AuthProvider>().refreshUser();
    final ids = context.read<AuthProvider>().user?.corridasSalvas;
    if (ids != null) _syncSaved(ids);
  }

  /// Recarrega as provas salvas sempre que a lista de ids mudar.
  void _syncSaved(List<String> ids) {
    final key = ids.join(',');
    if (key == _savedKey) return;
    _savedKey = key;
    if (ids.isEmpty) {
      setState(() => _saved = []);
      return;
    }
    RaceService.saved()
        .then((races) {
          if (mounted) setState(() => _saved = races);
        })
        .catchError((_) {
          // Seção complementar: se falhar, apenas não aparece.
        });
  }

  Future<void> _logout() async {
    final auth = context.read<AuthProvider>();
    final workouts = context.read<WorkoutsProvider>();
    final confirmed = await showRRConfirm(
      context,
      title: 'Sair da conta?',
      text: 'Você precisará entrar novamente para publicar treinos.',
      confirmLabel: 'Sair',
    );
    if (!confirmed) return;
    workouts.clear();
    await auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    final user = context.watch<AuthProvider>().user;
    if (user == null) return const SizedBox.shrink();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncSaved(user.corridasSalvas);
    });
    final mine = context.watch<WorkoutsProvider>().mine;
    final theme = context.watch<ThemeProvider>();
    final desktop = RRBreakpoints.isDesktop(context);

    final settings = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RRSectionHead('Conta'),
        const SizedBox(height: 4),
        if (user.tipo == 'organizador' || user.tipo == 'admin')
          RRInfoLine(
            icon: 'largada',
            title: 'Organização',
            value: 'Minhas provas',
            onTap: () => rrPush(context, const MyRacesScreen()),
          ),
        RRInfoLine(
          icon: 'editar',
          title: 'Dados do perfil',
          value: 'Editar perfil e recordes',
          onTap: () => rrPush(context, const EditProfileScreen()),
        ),
        const SizedBox(height: 16),
        Text('APARÊNCIA', style: RRType.monoS.copyWith(color: c.textSecondary)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final (mode, label) in const [
              (ThemeMode.system, 'Sistema'),
              (ThemeMode.light, 'Claro'),
              (ThemeMode.dark, 'Escuro'),
            ])
              RRChip(label, selected: theme.mode == mode, onTap: () => theme.setMode(mode)),
          ],
        ),
        const SizedBox(height: 8),
        RRInfoLine(icon: 'sair', title: 'Sessão', value: 'Sair da conta', onTap: _logout),
      ],
    );

    final activity = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_saved.isNotEmpty) ...[
          const RRSectionHead('Provas salvas'),
          const SizedBox(height: 12),
          for (final race in _saved) ...[RaceCard(race: race, key: ValueKey(race.id)), const SizedBox(height: 16)],
        ],
        RRSectionHead(
          'Seus treinos',
          action: mine.length > 3 ? 'Ver todos (${mine.length})' : null,
          onAction: () => rrPush(context, const WorkoutHistoryScreen(title: 'Seus treinos')),
        ),
        const SizedBox(height: 12),
        if (mine.isEmpty)
          const RREmptyState(
            title: 'Nenhum treino ainda',
            text: 'Seus treinos publicados aparecem aqui e somam no seu volume total.',
          )
        else
          for (final w in mine.take(3)) ...[WorkoutCard(w, key: ValueKey(w.id)), const SizedBox(height: 16)],
      ],
    );

    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileHeader(user: user),
        if (user.bio != null && user.bio!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(user.bio!, style: RRType.textM.copyWith(color: c.textSecondary)),
        ],
        const SizedBox(height: 16),
        ProfileTotals(user: user),
        const SizedBox(height: 16),
        ProfileRecords(user: user),
      ],
    );

    if (desktop) {
      return ListView(
        padding: const EdgeInsets.all(32),
        children: [
          RRCentered(
            maxWidth: 1100,
            child: LayoutBuilder(
              builder: (context, box) => box.maxWidth >= 860
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [summary, const SizedBox(height: 24), settings],
                          ),
                        ),
                        const SizedBox(width: 32),
                        Expanded(child: activity),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [summary, const SizedBox(height: 24), activity, const SizedBox(height: 8), settings],
                    ),
            ),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [summary, const SizedBox(height: 24), activity, const SizedBox(height: 8), settings],
    );
  }
}
