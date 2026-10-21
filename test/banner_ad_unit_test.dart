import 'package:flutter_test/flutter_test.dart';
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
}
