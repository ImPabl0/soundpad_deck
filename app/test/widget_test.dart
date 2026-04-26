import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:soundpad_deck/app.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Renderiza cabecalho principal', (WidgetTester tester) async {
    await tester.pumpWidget(const SoundpadDeckApp(enableAutoRefresh: false));
    await tester.pump();

    expect(find.text('Soundpad Deck'), findsOneWidget);
    expect(find.textContaining('Reconectar'), findsOneWidget);
  });
}
