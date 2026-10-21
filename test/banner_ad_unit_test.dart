import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:simple_signature/banner_ad_widget.dart';

void main() {
  group('bannerAdUnitId', () {
    test('always uses the Google test unit in debug builds', () {
      expect(
        bannerAdUnitId(BannerPlacement.resultPage, debug: true),
        testBannerAdUnitId,
      );
      expect(bannerAdUnitId(null, debug: true), testBannerAdUnitId);
    });

    test('uses the production unit for the result page in release', () {
      expect(
        bannerAdUnitId(BannerPlacement.resultPage, debug: false),
        resultPageBannerAdUnitId,
      );
    });

    test('falls back to the test unit when no placement is given', () {
      expect(bannerAdUnitId(null, debug: false), testBannerAdUnitId);
    });

    test('production unit belongs to the app publisher', () {
      expect(
        resultPageBannerAdUnitId,
        startsWith('ca-app-pub-2465007971338713/'),
      );
      expect(resultPageBannerAdUnitId, isNot(testBannerAdUnitId));
    });
  });

  testWidgets('BannerAdWidget requests nothing without consent', (
    tester,
  ) async {
    final consent = ValueNotifier(false);
    addTearDown(consent.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: BannerAdWidget(
          placement: BannerPlacement.resultPage,
          canRequestAds: consent,
        ),
      ),
    );

    // No platform channel is mocked, so any ad request would throw here.
    expect(tester.takeException(), isNull);
    expect(find.byType(SizedBox), findsWidgets);

    // Removing the widget must also detach its consent listener.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(() => consent.value = true, returnsNormally);
  });
}
