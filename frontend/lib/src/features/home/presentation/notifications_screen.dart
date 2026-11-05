import 'package:flutter/material.dart';

import '../../../core/widgets/rr_feedback.dart';
import '../../../core/widgets/rr_layout.dart';

/// O backend ainda não tem notificações: a tela mostra o estado vazio.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) => const RRSubPage(
    title: 'Notificações',
    child: RREmptyState(title: 'Tudo em dia', text: 'Curtidas, comentários e avisos de prova vão aparecer aqui.'),
  );
}
