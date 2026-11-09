import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:it_pdf/app/app.dart';
import 'package:it_pdf/core/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('IT PDF app launches and renders home screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const ItPdfApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('IT PDF'), findsOneWidget);
    expect(find.text('No Documents Yet'), findsOneWidget);
  });
}
