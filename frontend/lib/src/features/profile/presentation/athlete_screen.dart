import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/rr_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/rr_feedback.dart';
import '../../../core/widgets/rr_layout.dart';
import '../../auth/data/models/user_model.dart';
import '../../workouts/data/workout_model.dart';
import '../../workouts/presentation/workout_history_screen.dart';
import '../../workouts/presentation/workout_widgets.dart';
import '../../workouts/presentation/workouts_provider.dart';
import 'profile_widgets.dart';

/// Perfil público de outro atleta.
class AthleteScreen extends StatefulWidget {
  final String userId;
  const AthleteScreen({super.key, required this.userId});

  @override
  State<AthleteScreen> createState() => _AthleteScreenState();
}

class _AthleteScreenState extends State<AthleteScreen> {
  UserModel? _user;
  List<WorkoutModel> _workouts = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final results = await Future.wait([
        ApiClient.get('${ApiConstants.profile}/${widget.userId}'),
        WorkoutsProvider.byUser(widget.userId),
      ]);
      if (!mounted) return;
      setState(() {
        _user = UserModel.fromJson((results[0] as Map<String, dynamic>)['dados'] as Map<String, dynamic>);
        _workouts = results[1] as List<WorkoutModel>;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    final user = _user;
    final provider = context.watch<WorkoutsProvider>();
    final workouts = _workouts.where((w) => !provider.isDeleted(w.id)).toList();
    return RRSubPage(
      title: 'Atleta',
      child: _error != null
          ? RRErrorState(message: _error!, onRetry: _load)
          : user == null
          ? const RRLoading()
          : Column(
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
                const SizedBox(height: 24),
                RRSectionHead(
                  'Treinos',
                  action: workouts.length > 3 ? 'Ver todos (${workouts.length})' : null,
                  onAction: () => rrPush(
                    context,
                    WorkoutHistoryScreen(title: 'Treinos de ${Fmt.firstName(user.nome)}', workouts: workouts),
                  ),
                ),
                const SizedBox(height: 12),
                if (workouts.isEmpty)
                  Text('Nenhum treino publicado.', style: RRType.textM.copyWith(color: c.textSecondary)),
                for (final w in workouts.take(3)) ...[WorkoutCard(w, key: ValueKey(w.id)), const SizedBox(height: 16)],
              ],
            ),
    );
  }
}
