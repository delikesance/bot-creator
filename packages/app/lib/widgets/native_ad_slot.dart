import 'dart:async';

import 'package:bot_creator/utils/ad_native_service.dart';
import 'package:bot_creator/utils/ads_placement_policy.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class NativeAdSlot extends StatefulWidget {
  const NativeAdSlot({
    super.key,
    required this.placement,
    this.height = 120,
    this.margin = const EdgeInsets.symmetric(vertical: 6),
  });

  final NativeAdPlacement placement;
  final double height;
  final EdgeInsetsGeometry margin;

  @override
  State<NativeAdSlot> createState() => _NativeAdSlotState();
}

class _NativeAdSlotState extends State<NativeAdSlot> {
  NativeAd? _nativeAd;
  bool _loaded = false;
  bool _attempted = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadAd());
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  Future<void> _loadAd() async {
    if (_attempted) {
      return;
    }
    _attempted = true;

    final canLoad = await AdNativeService.canLoadForPlacement(widget.placement);
    if (!canLoad || !mounted) {
      return;
    }

    await AdNativeService.trackRequest(widget.placement);

    final ad = AdNativeService.createNativeAd(
      placement: widget.placement,
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _nativeAd = ad as NativeAd;
            _loaded = true;
          });
          unawaited(AdNativeService.trackLoaded(widget.placement));
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) {
            return;
          }
          setState(() {
            _nativeAd = null;
            _loaded = false;
          });
          unawaited(AdNativeService.trackFailed(widget.placement, error));
        },
        onAdClicked: (ad) {
          unawaited(AdNativeService.trackClicked(widget.placement));
        },
        onAdImpression: (ad) {
          unawaited(AdNativeService.recordImpression(widget.placement));
        },
      ),
    );

    ad.load();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: widget.margin,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: SizedBox(height: widget.height, child: AdWidget(ad: _nativeAd!)),
      ),
    );
  }
}
