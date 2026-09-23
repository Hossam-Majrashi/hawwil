import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hawwil/l10n/app_localizations.dart';
import 'package:hawwil/services/settings_service.dart';
import 'package:hawwil/widgets/developer_section.dart';
import 'package:hawwil/screens/mobile/mobile_settings_screen.dart';
import 'package:hawwil/screens/desktop/desktop_settings_screen.dart';
import 'package:hawwil/screens/web/web_settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestWidget({
    required Widget child,
    Locale locale = const Locale('ar'),
  }) {
    return MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    );
  }

  testWidgets('DeveloperSection renders Arabic developer details', (WidgetTester tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        child: const DeveloperSection(),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('المطور'), findsOneWidget);
    expect(find.text('حسام حسن مجرشي'), findsOneWidget);
    expect(find.text('البريد الإلكتروني'), findsOneWidget);
    expect(find.text('Hossam.Majrashi@gmail.com'), findsOneWidget);
    expect(find.text('الموقع الإلكتروني'), findsOneWidget);
    expect(find.text('hossam-majrashi.github.io/Works/'), findsOneWidget);
  });

  testWidgets('DeveloperSection renders English developer details', (WidgetTester tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        child: const DeveloperSection(),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Developer'), findsOneWidget);
    expect(find.text('حسام حسن مجرشي'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Hossam.Majrashi@gmail.com'), findsOneWidget);
    expect(find.text('Website'), findsOneWidget);
    expect(find.text('hossam-majrashi.github.io/Works/'), findsOneWidget);
  });

  testWidgets('MobileSettingsScreen contains DeveloperSection at the end', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final settingsService = SettingsService();
    await settingsService.init();

    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      buildTestWidget(
        child: MobileSettingsScreen(
          settingsService: settingsService,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DeveloperSection), findsOneWidget);
  });

  testWidgets('DesktopSettingsScreen contains DeveloperSection at the end', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final settingsService = SettingsService();
    await settingsService.init();

    tester.view.physicalSize = const Size(1200, 2500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      buildTestWidget(
        child: DesktopSettingsScreen(
          settingsService: settingsService,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DeveloperSection), findsOneWidget);
  });

  testWidgets('WebSettingsScreen contains DeveloperSection at the end', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final settingsService = SettingsService();
    await settingsService.init();

    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      buildTestWidget(
        child: WebSettingsScreen(
          settingsService: settingsService,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DeveloperSection), findsOneWidget);
  });
}
