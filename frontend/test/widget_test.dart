import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('sem sessão salva, abre as boas-vindas', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('CORRA'), findsOneWidget);
    expect(find.text('ROTA.'), findsOneWidget);
    expect(find.text('Criar minha conta'), findsOneWidget);
    expect(find.text('Já tenho conta'), findsOneWidget);
  });
}
