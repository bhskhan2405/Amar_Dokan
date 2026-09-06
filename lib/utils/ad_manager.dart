import 'dart:async';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ad_helper.dart';
import 'subscription_utils.dart';

class AdManager {
  static InterstitialAd? _interstitialAd;
  static int _productAddCount = 0;
  static int _posSaleCount = 0;

  // প্রোডাক্ট অ্যাডিং কাউন্ট চেক ও অ্যাড দেখানো
  static Future<void> checkAndShowProductAd(Function onAdDismissed) async {
    if (await SubscriptionUtils.isPremium()) {
      await onAdDismissed();
      return;
    }

    _productAddCount++;
    if (_productAddCount >= 3) {
      final completer = Completer<void>();
      _loadInterstitialAd((ad) async {
        ad.show();
        _productAddCount = 0;
        await onAdDismissed();
        completer.complete();
      }, () async {
        await onAdDismissed();
        completer.complete();
      });
      await completer.future;
    } else {
      await onAdDismissed();
    }
  }

  // POS সেল কাউন্ট চেক ও অ্যাড দেখানো
  static Future<void> checkAndShowSaleAd(Function onAdDismissed) async {
    if (await SubscriptionUtils.isPremium()) {
      await onAdDismissed();
      return;
    }

    _posSaleCount++;
    if (_posSaleCount >= 1) { // আপনি বলেছিলেন প্রতি ১ টা সেল পর পর অ্যাড
      final completer = Completer<void>();
      _loadInterstitialAd((ad) async {
        ad.show();
        _posSaleCount = 0;
        await onAdDismissed();
        completer.complete();
      }, () async {
        await onAdDismissed();
        completer.complete();
      });
      await completer.future;
    } else {
      await onAdDismissed();
    }
  }

  static void _loadInterstitialAd(Function(InterstitialAd) onLoaded, Function onFail) {
    bool isCallbackCalled = false;

    // ৫ সেকেন্ডের মধ্যে অ্যাড লোড না হলে অটোমেটিক ফেইল কল হবে (অফলাইন সাপোর্ট)
    Future.delayed(const Duration(seconds: 5), () {
      if (!isCallbackCalled) {
        isCallbackCalled = true;
        onFail();
      }
    });

    InterstitialAd.load(
      adUnitId: AdHelper.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (!isCallbackCalled) {
            isCallbackCalled = true;
            _interstitialAd = ad;
            onLoaded(ad);
          }
        },
        onAdFailedToLoad: (err) {
          if (!isCallbackCalled) {
            isCallbackCalled = true;
            onFail();
          }
        },
      ),
    );
  }
}
