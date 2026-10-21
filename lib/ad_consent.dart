import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Thin wrapper over the Google Mobile Ads / UMP SDK so the consent flow can
/// be tested without platform channels.
abstract class AdsPlatform {
  /// Refreshes the consent status; completes with an error message on failure.
  Future<String?> requestConsentInfoUpdate();

  /// Shows the consent form when the user still needs to answer it.
  Future<String?> loadAndShowConsentFormIfRequired();

  Future<bool> canRequestAds();

  Future<bool> isPrivacyOptionsRequired();

  Future<String?> showPrivacyOptionsForm();

  Future<void> initializeMobileAds();
}

class GoogleAdsPlatform implements AdsPlatform {
  const GoogleAdsPlatform();

  @override
  Future<String?> requestConsentInfoUpdate() {
    final completer = Completer<String?>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => completer.complete(null),
      (FormError error) => completer.complete(error.message),
    );
    return completer.future;
  }

  @override
  Future<String?> loadAndShowConsentFormIfRequired() {
    final completer = Completer<String?>();
    ConsentForm.loadAndShowConsentFormIfRequired(
      (FormError? error) => completer.complete(error?.message),
    );
    return completer.future;
  }

  @override
  Future<bool> canRequestAds() => ConsentInformation.instance.canRequestAds();

  @override
  Future<bool> isPrivacyOptionsRequired() async {
    final status = await ConsentInformation.instance
        .getPrivacyOptionsRequirementStatus();
    return status == PrivacyOptionsRequirementStatus.required;
  }

  @override
  Future<String?> showPrivacyOptionsForm() {
    final completer = Completer<String?>();
    ConsentForm.showPrivacyOptionsForm(
      (FormError? error) => completer.complete(error?.message),
    );
    return completer.future;
  }

  @override
  Future<void> initializeMobileAds() => MobileAds.instance.initialize();
}

/// Collects user consent (GDPR / UMP) before any ad is requested and
/// initializes the Mobile Ads SDK once consent allows it.
class AdConsentManager {
  AdConsentManager({AdsPlatform? platform})
    : _platform = platform ?? const GoogleAdsPlatform();

  static final AdConsentManager instance = AdConsentManager();

  final AdsPlatform _platform;

  /// True once ads may be requested and the SDK is initialized.
  final ValueNotifier<bool> canRequestAds = ValueNotifier(false);

  /// True when the user must be offered a way to change their consent.
  final ValueNotifier<bool> privacyOptionsRequired = ValueNotifier(false);

  bool _sdkInitialized = false;
  Future<void>? _gathering;

  /// Runs the consent flow. Concurrent calls share the same run.
  Future<void> gatherConsent() => _gathering ??= _gather().whenComplete(() {
    _gathering = null;
  });

  Future<void> _gather() async {
    // Consent from an earlier session can be used straight away.
    await _refreshState();

    final updateError = await _guard(_platform.requestConsentInfoUpdate);
    if (updateError == null) {
      final formError = await _guard(
        _platform.loadAndShowConsentFormIfRequired,
      );
      if (formError != null) _log('Consent form error: $formError');
    } else {
      _log('Consent info update failed: $updateError');
    }

    await _refreshState();
  }

  Future<void> showPrivacyOptions() async {
    final error = await _guard(_platform.showPrivacyOptionsForm);
    if (error != null) _log('Privacy options form error: $error');
    await _refreshState();
  }

  Future<void> _refreshState() async {
    try {
      privacyOptionsRequired.value = await _platform.isPrivacyOptionsRequired();
      final allowed = await _platform.canRequestAds();
      if (allowed && !_sdkInitialized) {
        _sdkInitialized = true;
        await _platform.initializeMobileAds();
      }
      canRequestAds.value = allowed;
    } catch (e) {
      _log('Unable to read consent state: $e');
    }
  }

  Future<String?> _guard(Future<String?> Function() call) async {
    try {
      return await call();
    } catch (e) {
      return e.toString();
    }
  }

  void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }
}
