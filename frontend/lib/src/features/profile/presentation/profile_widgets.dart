import 'package:flutter/material.dart';

import '../../../core/motion/rr_motion.dart';
import '../../../core/theme/rr_theme.dart';
import '../../../core/utils/format.dart';
import '../../../core/widgets/rr_labels.dart';
import '../../../core/widgets/rr_layout.dart';
import '../../auth/data/models/user_model.dart';

class ProfileHeader extends StatelessWidget {
  final UserModel user;
  const ProfileHeader({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    final place = [user.cidade, user.estado].where((v) => v != null && v.isNotEmpty).join(', ');
    return Row(
      children: [
        RRAvatar(user.nome, url: user.avatarUrl, size: 88),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.nome.toUpperCase(), style: RRType.displayS.copyWith(color: c.textPrimary)),
              if (place.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(place, style: RRType.textM.copyWith(color: c.textSecondary)),
              ],
              if (user.seguidores != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  children: [
                    Text(
                      '${user.seguidores} ${user.seguidores == 1 ? 'SEGUIDOR' : 'SEGUIDORES'}',
                      style: RRType.monoS.copyWith(color: c.textMuted),
                    ),
                    Text('${user.seguindo ?? 0} SEGUINDO', style: RRType.monoS.copyWith(color: c.textMuted)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class ProfileTotals extends StatelessWidget {
  final UserModel user;
  const ProfileTotals({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final totalKm = (user.estatisticas?['totalKm'] as num? ?? 0);
    final workouts = (user.estatisticas?['totalTreinos'] as num? ?? 0);
    return Row(
      children: [
        Expanded(
          child: RRStat(label: 'Volume total', value: totalKm.toDouble(), format: Fmt.thousands, unit: 'km'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: RRStat(label: 'Treinos', value: workouts.toDouble(), format: Fmt.thousands),
        ),
      ],
    );
  }
}

class ProfileRecords extends StatelessWidget {
  final UserModel user;
  const ProfileRecords({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final c = context.rr;
    final records = user.recordesPessoais ?? const {};

    Widget line(String distance, String key, int index) {
      final time = (records[key] as String? ?? '').trim();
      return RRReveal(
        index: index,
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.border)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                child: Text(distance, style: RRType.dataM.copyWith(color: c.accentText)),
              ),
              Expanded(
                child: Text(time.isEmpty ? '—' : time, style: RRType.dataL.copyWith(color: c.textPrimary)),
              ),
              if (time.isEmpty) Text('PRÓXIMA META', style: RRType.monoS.copyWith(color: c.textMuted)),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const RRSectionHead('Recordes pessoais'),
        const SizedBox(height: 4),
        line('5K', 'rp5k', 0),
        line('10K', 'rp10k', 1),
        line('21K', 'rp21k', 2),
        line('42K', 'rp42k', 3),
      ],
    );
  }
}
