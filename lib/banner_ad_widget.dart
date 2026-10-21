import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

enum StatusAd { initial, loaded }

enum BannerPlacement { resultPage }

class BannerAdWidget extends StatefulWidget {
  final BannerPlacement? placement;
  final EdgeInsetsGeometry? margin;
  const BannerAdWidget({super.key, this.placement, this.margin});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? myBanner;
  StatusAd statusAd = StatusAd.initial;

  BannerAdListener listener() {
    return BannerAdListener(
      onAdLoaded: (Ad ad) {
        if (kDebugMode) print('Ad Loaded');
        setState(() {
          statusAd = StatusAd.loaded;
        });
      },
    );
  }

  Future<void> initBanner() async {
    myBanner = BannerAd(
      adUnitId: getAddUnitId(),
      size: AdSize.banner,
      request: const AdRequest(),
      listener: listener(),
    );
    myBanner!.load();
  }

  @override
  void initState() {
    initBanner();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return statusAd == StatusAd.loaded
        ? Container(
            margin: widget.margin ?? const EdgeInsets.only(left: 15, right: 15),
            alignment: Alignment.center,
            width: myBanner!.size.width.toDouble(),
            height: myBanner!.size.height.toDouble(),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AdWidget(ad: myBanner!)),
          )
        : const SizedBox();
  }

  String getAddUnitId() {
    String debugUnitID = 'ca-app-pub-3940256099942544/6300978111';
    if (kDebugMode) return debugUnitID;

    switch (widget.placement) {
      case BannerPlacement.resultPage:
        return 'ca-app-pub-2465007971338713/1087521621';
      default:
        return debugUnitID;
    }
  }
}
