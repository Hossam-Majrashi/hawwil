import 'package:flutter_test/flutter_test.dart';
import 'package:hawwil/main.dart';
import 'package:hawwil/services/settings_service.dart';
import 'package:hawwil/services/batch_conversion_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('HawwilApp initial load smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final settingsService = SettingsService();
    await settingsService.init();

    final batchService = BatchConversionService();

    await tester.runAsync(() async {
      await tester.pumpWidget(HawwilApp(
        settingsService: settingsService,
        batchService: batchService,
      ));

      await Future.delayed(const Duration(milliseconds: 200));
      await tester.pump();
    });

    expect(find.byType(HawwilApp), findsOneWidget);
  });
}
