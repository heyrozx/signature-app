import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:simple_signature/app_strings.dart';
import 'package:simple_signature/pen_options.dart';

void main() {
  const en = AppStrings('en');
  const id = AppStrings('id');

  List<String Function(AppStrings)> getters() => [
    (s) => s.appTitle,
    (s) => s.resultTitle,
    (s) => s.signHere,
    (s) => s.emptySignature,
    (s) => s.exportFailed,
    (s) => s.shareFailed,
    (s) => s.shareText,
    (s) => s.saved,
    (s) => s.saveCancelled,
    (s) => s.saveFailed,
    (s) => s.save,
    (s) => s.share,
    (s) => s.next,
    (s) => s.undo,
    (s) => s.redo,
    (s) => s.clear,
    (s) => s.penColor,
    (s) => s.penTip,
    (s) => s.penSize,
    (s) => s.privacySettings,
    (s) => s.transparent,
    (s) => s.white,
  ];

  test('every string has an English and an Indonesian text', () {
    for (final get in getters()) {
      expect(get(en), isNotEmpty);
      expect(get(id), isNotEmpty);
    }
  });

  test('every pen color and stroke cap has a translation', () {
    final names = [
      ...penColorOptions.map((o) => o.name),
      ...strokeCapOptions.map((o) => o.name),
    ];
    for (final name in names) {
      expect(en.option(name), name);
      expect(id.option(name), isNot(name));
    }
  });

  test('supports English and Indonesian', () {
    expect(AppStrings.supportedLocales.map((l) => l.languageCode), [
      'en',
      'id',
    ]);
  });

  testWidgets('falls back to English for other languages', (tester) async {
    late AppStrings strings;
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('fr'),
        delegates: const [DefaultWidgetsLocalizations.delegate],
        child: Builder(
          builder: (context) {
            strings = AppStrings.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(strings.languageCode, 'en');
    expect(strings.save, 'Save');
  });

  testWidgets('picks Indonesian from the locale', (tester) async {
    late AppStrings strings;
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('id', 'ID'),
        delegates: const [DefaultWidgetsLocalizations.delegate],
        child: Builder(
          builder: (context) {
            strings = AppStrings.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(strings.save, 'Simpan');
  });
}
