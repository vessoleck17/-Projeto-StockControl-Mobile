import 'package:flutter_test/flutter_test.dart';
import 'package:stockcontrol_mobile/app.dart';

void main() {
  testWidgets('StockControl exibe a tela de login', (tester) async {
    await tester.pumpWidget(const StockControlApp());

    expect(find.text('StockControl'), findsOneWidget);
    expect(find.text('Bem-vindo de volta!'), findsOneWidget);
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
