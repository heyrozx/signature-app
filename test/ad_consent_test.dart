import 'package:flutter_test/flutter_test.dart';
import 'package:simple_signature/ad_consent.dart';

class FakeAdsPlatform implements AdsPlatform {
  bool canRequest;
  bool privacyRequired;
  String? updateError;
  String? formError;
  bool throwOnUpdate = false;

  /// Value of [canRequest] after the consent form is answered.
  bool? canRequestAfterForm;

  int updateCalls = 0;
  int formCalls = 0;
  int initializeCalls = 0;
  int privacyFormCalls = 0;

  FakeAdsPlatform({this.canRequest = false, this.privacyRequired = false});

  @override
  Future<String?> requestConsentInfoUpdate() async {
    updateCalls++;
    if (throwOnUpdate) throw Exception('no network');
    return updateError;
  }

  @override
  Future<String?> loadAndShowConsentFormIfRequired() async {
    formCalls++;
    if (canRequestAfterForm != null) canRequest = canRequestAfterForm!;
    return formError;
  }

  @override
  Future<bool> canRequestAds() async => canRequest;

  @override
  Future<bool> isPrivacyOptionsRequired() async => privacyRequired;

  @override
  Future<String?> showPrivacyOptionsForm() async {
    privacyFormCalls++;
    return null;
  }

  @override
  Future<void> initializeMobileAds() async => initializeCalls++;
}

void main() {
  group('AdConsentManager', () {
    test('does not initialize ads before consent allows it', () {
      final manager = AdConsentManager(platform: FakeAdsPlatform());
      expect(manager.canRequestAds.value, isFalse);
      expect(manager.privacyOptionsRequired.value, isFalse);
    });

    test('shows the form and initializes ads once consent is given', () async {
      final platform = FakeAdsPlatform()..canRequestAfterForm = true;
      final manager = AdConsentManager(platform: platform);

      await manager.gatherConsent();

      expect(platform.updateCalls, 1);
      expect(platform.formCalls, 1);
      expect(platform.initializeCalls, 1);
      expect(manager.canRequestAds.value, isTrue);
    });

    test('keeps ads disabled when consent is refused', () async {
      final platform = FakeAdsPlatform()..canRequestAfterForm = false;
      final manager = AdConsentManager(platform: platform);

      await manager.gatherConsent();

      expect(platform.initializeCalls, 0);
      expect(manager.canRequestAds.value, isFalse);
    });

    test('uses consent from a previous session if the update fails', () async {
      final platform = FakeAdsPlatform(canRequest: true)
        ..updateError = 'offline';
      final manager = AdConsentManager(platform: platform);

      await manager.gatherConsent();

      expect(platform.formCalls, 0);
      expect(platform.initializeCalls, 1);
      expect(manager.canRequestAds.value, isTrue);
    });

    test('survives a thrown exception from the SDK', () async {
      final platform = FakeAdsPlatform()..throwOnUpdate = true;
      final manager = AdConsentManager(platform: platform);

      await expectLater(manager.gatherConsent(), completes);
      expect(manager.canRequestAds.value, isFalse);
    });

    test('initializes the SDK only once across runs', () async {
      final platform = FakeAdsPlatform(canRequest: true);
      final manager = AdConsentManager(platform: platform);

      await manager.gatherConsent();
      await manager.gatherConsent();

      expect(platform.initializeCalls, 1);
    });

    test('concurrent calls share a single consent flow', () async {
      final platform = FakeAdsPlatform(canRequest: true);
      final manager = AdConsentManager(platform: platform);

      await Future.wait([manager.gatherConsent(), manager.gatherConsent()]);

      expect(platform.updateCalls, 1);
    });

    test('exposes whether privacy options must be offered', () async {
      final platform = FakeAdsPlatform(privacyRequired: true);
      final manager = AdConsentManager(platform: platform);

      await manager.gatherConsent();

      expect(manager.privacyOptionsRequired.value, isTrue);
    });

    test('privacy options form refreshes consent state', () async {
      final platform = FakeAdsPlatform(canRequest: true);
      final manager = AdConsentManager(platform: platform);
      await manager.gatherConsent();

      platform.canRequest = false;
      await manager.showPrivacyOptions();

      expect(platform.privacyFormCalls, 1);
      expect(manager.canRequestAds.value, isFalse);
    });
  });
}
