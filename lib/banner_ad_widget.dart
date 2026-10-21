import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:simple_signature/ad_consent.dart';

enum StatusAd { initial, loaded }

enum BannerPlacement { resultPage }

const String testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
const String resultPageBannerAdUnitId =
    'ca-app-pub-2465007971338713/1087521621';

String bannerAdUnitId(BannerPlacement? placement, {bool debug = kDebugMode}) {
  if (debug) return testBannerAdUnitId;

  switch (placement) {
    case BannerPlacement.resultPage:
      return resultPageBannerAdUnitId;
    default:
      return testBannerAdUnitId;
  }
}

class BannerAdWidget extends StatefulWidget {
  final BannerPlacement? placement;
  final EdgeInsetsGeometry? margin;

  /// Gates ad requests on user consent. Defaults to the app-wide manager.
  final ValueListenable<bool>? canRequestAds;

  const BannerAdWidget({
    super.key,
    this.placement,
    this.margin,
    this.canRequestAds,
  });

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? myBanner;
  StatusAd statusAd = StatusAd.initial;

  ValueListenable<bool> get _canRequestAds =>
      widget.canRequestAds ?? AdConsentManager.instance.canRequestAds;

  @override
  void initState() {
    super.initState();
    _canRequestAds.addListener(_maybeLoad);
    _maybeLoad();
  }

  void _maybeLoad() {
    if (!_canRequestAds.value || myBanner != null) return;

    myBanner = BannerAd(
      adUnitId: bannerAdUnitId(widget.placement),
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          if (kDebugMode) debugPrint('Ad Loaded');
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => statusAd = StatusAd.loaded);
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          if (kDebugMode) debugPrint('Ad failed to load: $error');
          ad.dispose();
          if (identical(myBanner, ad)) myBanner = null;
          if (mounted) setState(() => statusAd = StatusAd.initial);
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _canRequestAds.removeListener(_maybeLoad);
    myBanner?.dispose();
    myBanner = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = myBanner;
    if (statusAd != StatusAd.loaded || banner == null) {
      return const SizedBox();
    }
    return Container(
      margin: widget.margin ?? const EdgeInsets.only(left: 15, right: 15),
      alignment: Alignment.center,
      width: banner.size.width.toDouble(),
      height: banner.size.height.toDouble(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AdWidget(ad: banner),
      ),
    );
  }
}
