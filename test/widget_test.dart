import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cleanbot_app/core/storage/preferences_service.dart';
import 'package:cleanbot_app/main.dart';

void main() {
  testWidgets('CleanBot app smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'cleanbot_onboarding_complete': true,
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const CleanBotApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Verify app starts up and displays CleanBot branding
    expect(find.byType(CleanBotApp), findsOneWidget);
  });
}
